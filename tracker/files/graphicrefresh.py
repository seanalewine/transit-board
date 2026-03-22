import os
import json
import requests
import sys
import re
import time
import pandas as pd
from collections import defaultdict

token = os.environ.get("SUPERVISOR_TOKEN")
boardname = os.environ.get("LIGHT_BOARD_BASE")
refresh_interval = int(os.environ.get("DATA_REFRESH_INTERVAL_SEC", 60))

STATION_COLORS = {}
csv_path = os.environ.get("CTA_STATION_LIST", "/data/ctastationlist.csv")
try:
    df = pd.read_csv(csv_path)
    for _, row in df.iterrows():
        STATION_COLORS[int(row['unifiedId'])] = row['line']
except Exception as e:
    print(f"WARNING: Could not load station color map: {e}", file=sys.stderr)

# Function Definitions
def get_global_brightness():
    brightness_entity = f"number.{boardname}global_brightness"
    try:
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        response = requests.get(
            f"http://supervisor/core/api/states/{brightness_entity}",
            headers=headers,
            timeout=3
        )
        if response.status_code == 200:
            return int(float(response.json().get("state", 100)))
    except Exception as e:
        print(f"WARNING: Could not fetch brightness from {brightness_entity}: {e}", file=sys.stderr)
    return 100

def get_on_lights():
    print("Fetching current state of all light entities...")
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    response = requests.get(f"http://supervisor/core/api/states", headers=headers)
    states_json = response.json()
    
    # Filter entities and extract just the numerical IDs
    on_ids = []
    for entity in states_json:
        if entity.get("entity_id", "").startswith(f"light.{boardname}"):
            if entity.get("state") == "on":
                # Extract numerical ID using regex
                match = re.search(r'_(\d+)$', entity.get("entity_id", ""))
                if match:
                    on_ids.append(int(match.group(1)))
    
    return on_ids

def set_light_color(sta_id, color_rgb):    
    if isinstance(color_rgb, str):
        color_rgb = [int(val.strip()) for val in color_rgb.split(',')]
    data = {
        "entity_id": f"light.{boardname}{sta_id}",
        "rgb_color": color_rgb,
        "brightness_pct": get_global_brightness()
    }
    
    # Send POST request
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.post(
            "http://supervisor/core/api/services/light/turn_on",
            headers=headers,
            json=data
        )
        
        # Check if request was successful
        if response.status_code != 200:
            print(f"ERROR: Failed to set light color. Status code: {response.status_code}")
            print(f"ERROR: Response details - {response.text}")
            
    except Exception as e:
        print(f"ERROR: Exception occurred - {str(e)}")
        print(f"ERROR: Exception type - {type(e).__name__}")

def turn_off_light(sta_id):
    # Prepare the request
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    data = {"entity_id": f"light.{boardname}{sta_id}"}
    
    try:
        response = requests.post(
            "http://supervisor/core/api/services/light/turn_off",
            headers=headers,
            json=data,
        )
        
        # Check if request was successful
        if response.status_code != 200:
            print(f"ERROR: Failed to execute request for station ID: {sta_id}")
            print(f"Response status: {response.status_code}")
            return False
        
        # Check for specific error conditions
        response_text = response.text.lower()
        if "400" in response_text or "bad request" in response_text:
            print("ERROR: Bad Request returned from Home Assistant - likely invalid entity ID or malformed request", file=sys.stderr)
            print(f"DEBUG: Response was: {response.text}")
            return False
        
        # Check if response contains error information
        if "error" in response_text:
            print(f"WARNING: Response may contain errors: {response.text}")
        
        return True
        
    except requests.exceptions.RequestException as e:
        print(f"ERROR: Failed to execute curl request for station ID: {sta_id}")
        print(f"Exception: {str(e)}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"ERROR: Unexpected error occurred: {str(e)}")
        return False

def intake_trains():
    result_dict = {}
    try:
        data = json.load(sys.stdin)
        
        for item in data:
            unified_id = item.get('unifiedId', -1)
            if 0 <= unified_id <= 319:
                result_dict[unified_id] = {
                    'rgb': item.get('rgb', '255,255,255'),
                    'color': item.get('color', 'unknown')
                }
            else:
                print(f"Warning: Invalid unifiedId: {unified_id}. Skipping.", file=sys.stderr)

    except json.JSONDecodeError as e:
        print(f"Error parsing JSON from stdin: {e}", file=sys.stderr)
    except Exception as e:
        print(f"Error processing train data: {e}", file=sys.stderr)
        
    return result_dict

def actual_off(old, new):
    # Create a set of dictionary keys for faster lookup
    dict_keys = set(new.keys())
    # Filter out any values that are keys in the dictionary
    return [item for item in old if item not in dict_keys]

def actual_on(old, new):
    result = new.copy()
    
    # Remove each key that exists in the list
    for key in old:
        result.pop(key, None)  # pop with default None prevents KeyError
    
    return result

def board_refresh(off, on, refresh_interval):
    # Group by color for pairing
    off_by_color = defaultdict(list)
    for sid in off:
        color = STATION_COLORS.get(sid, 'unknown')
        off_by_color[color].append(sid)
    
    on_by_color = defaultdict(list)
    for sid in on:
        color = on[sid].get('color', STATION_COLORS.get(sid, 'unknown'))
        on_by_color[color].append(sid)
    
    all_colors = set(off_by_color.keys()) | set(on_by_color.keys())
    
    pairs = []
    singles = {'off': [], 'on': []}
    for color in all_colors:
        offs = off_by_color.get(color, [])
        ons = on_by_color.get(color, [])
        min_len = min(len(offs), len(ons))
        for i in range(min_len):
            pairs.append((offs[i], ons[i]))
        singles['off'].extend(offs[min_len:])
        singles['on'].extend(ons[min_len:])
    
    total_changes = len(pairs) * 2 + len(singles['off']) + len(singles['on'])
    if total_changes == 0:
        return
    
    interval_sec = refresh_interval / total_changes
    
    # Process paired changes (turn off and on together) - one interval each
    for off_id, on_id in pairs:
        turn_off_light(off_id)
        set_light_color(on_id, on[on_id]['rgb'])
        if total_changes > 1:
            time.sleep(interval_sec)
    
    # Process remaining offs (all before ons)
    for sid in singles['off']:
        turn_off_light(sid)
        if total_changes > 1:
            time.sleep(interval_sec)
    
    # Process remaining ons
    for sid in singles['on']:
        set_light_color(sid, on[sid]['rgb'])
        if total_changes > 1:
            time.sleep(interval_sec)

def main():
    # Add all new active stops to a dictionary.
    active_stops = intake_trains()
    # print(f"active_stops:{active_stops}")
    # Send all lights that are on from previous refresh to list.
    currently_on = get_on_lights()
    # print(f"currently_on:{currently_on}")
    # Update currently_on to only include stops that are no longer active.
    final_off = actual_off(currently_on, active_stops)
    # print(f"final_off:{final_off}")
    # Update active_stops to only include stations that were not previously lit.
    final_on = actual_on(currently_on, active_stops)
    # print(f"final_on:{final_on}")
    # Finally update the board
    board_refresh(final_off, final_on, refresh_interval)

    sys.exit(0)

if __name__ == "__main__":
    main()