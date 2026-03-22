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

# Function Definitions
def get_global_brightness():
    brightness_entity = os.environ.get("BRIGHTNESS_ENTITY", "number.esp_train_tracker_global_brightness")
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
        if entity.get("entity_id", "").startswith(boardname):
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
        "entity_id": f"{boardname}{sta_id}",
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
    
    data = {"entity_id": f"{boardname}{sta_id}"}
    
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
        # Read the JSON payload piped in from the bash script via stdin
        df = pd.read_json(sys.stdin)

        if not df.empty:
            valid_mask = (df['unifiedId'] >= 0) & (df['unifiedId'] <= 319)
            valid_df = df[valid_mask]
            
            invalid_ids = df[~valid_mask]['unifiedId'].tolist()
            for invalid_id in invalid_ids:
                print(f"Warning: Invalid unifiedId: {invalid_id}. Skipping.", file=sys.stderr)

            result_dict = dict(zip(valid_df['unifiedId'].astype(int), valid_df['rgb']))

    except ValueError as e:
        print(f"Error parsing dataframe from stdin: {e}", file=sys.stderr)
        
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
    dict_keys = list(on.keys())
    total_on = len(dict_keys)
    total_off = len(off)
    total_changes = total_on + total_off
    
    if total_changes == 0:
        return
    
    interval_sec = refresh_interval / total_changes
    delay_ms = interval_sec * 1000
    
    for i in range(max(total_on, total_off)):
        if i < total_on:
            set_light_color(dict_keys[i], on[dict_keys[i]])
        if i < total_off:
            turn_off_light(off[i])
        
        if i < total_changes - 1:
            time.sleep(delay_ms / 1000)

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