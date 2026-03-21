import os
import csv
import json
import requests
import sys
import subprocess
import re
import time
from collections import defaultdict

token = os.environ.get("SUPERVISOR_TOKEN")
boardname = os.environ.get("LIGHT_BOARD_BASE")
brightness = int(os.environ.get("BRIGHTNESS", 100))
sleeptime = int(os.environ.get("SLEEP_TIME", 0.02))
input_path = os.environ.get("JSON_FILE","/data/active_train_summary.json")

# Function Definitions
def get_on_lights():
    print("Fetching current state of all light entities...")
    
    # Call the Home Assistant API to get all states
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
                    on_ids.append(match.group(1))
    
    return on_ids

def set_light_color(sta_id, color_rgb):    
    
    if isinstance(color_rgb, str):
        color_rgb = [int(val.strip()) for val in color_rgb.split(',')]
    # Create data payload
    data = {
        "entity_id": f"{boardname}{sta_id}",
        "rgb_color": color_rgb,
        "brightness_pct": brightness
    }
    
    # Debug: Print the data being sent
    print(f"DEBUG: Sending data - {data}")
    
    # Send POST request
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    # Debug: Print headers
    print(f"DEBUG: Headers - {headers}")
    
    # Debug: Print URL
    url = "http://supervisor/core/api/services/light/turn_on"
    print(f"DEBUG: Posting to URL - {url}")
    
    try:
        response = requests.post(
            url,
            headers=headers,
            json=data
        )
        
        # Debug: Print response status and content
        print(f"DEBUG: Response status code - {response.status_code}")
        print(f"DEBUG: Response content - {response.text}")
        
        # Check if request was successful
        if response.status_code >= 200 and response.status_code < 300:
            print(f"SUCCESS: Light color set for station {sta_id}")
        else:
            print(f"ERROR: Failed to set light color. Status code: {response.status_code}")
            print(f"ERROR: Response details - {response.text}")
            
    except Exception as e:
        # Debug: Print any exceptions
        print(f"ERROR: Exception occurred - {str(e)}")
        print(f"ERROR: Exception type - {type(e).__name__}")
    
    # Debug: Print sleep info
    print(f"DEBUG: Sleeping for {sleeptime/1000} seconds")
    time.sleep(sleeptime/1000)
    
    # Debug: Confirm completion
    print(f"DEBUG: Function completed for station {sta_id}")


def turn_off_light(sta_id):
    # Prepare the request
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    data = {"entity_id": f"{boardname}{sta_id}"}
    
    try:
        # Make the POST request
        response = requests.post(
            "http://supervisor/core/api/services/light/turn_off",
            headers=headers,
            json=data,
            timeout=2 # Add a reasonable timeout
        )
        
        # Check if request was successful
        if response.status_code != 200:
            print(f"ERROR: Failed to execute request for station ID: {station_id}")
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
        
        # Success case
        # print(f"DEBUG: Successfully turned off light for entity: {station_id}")
        time.sleep(sleeptime/1000)
        return True
        
    except requests.exceptions.RequestException as e:
        print(f"ERROR: Failed to execute curl request for station ID: {station_id}")
        print(f"Exception: {str(e)}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"ERROR: Unexpected error occurred: {str(e)}")
        return False

def intake_trains():
    result_dict = {}    
    try:
        with open(input_path, 'r') as f:
            data = json.load(f)
        
        # Process each item in the JSON array
        for item in data:
            # Extract unifiedId and rgb values
            sta_id = item.get('unifiedId')
            color = item.get('rgb')
            
            # Check if sta_id is a valid integer between 0 and 319
            if isinstance(sta_id, int) and 0 <= sta_id <= 319:
                result_dict[sta_id] = color
            else:
                print(f"Warning: Invalid unifiedId found: {sta_id}. Skipping.", file=sys.stderr)
                
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Error processing file: {e}", file=sys.stderr)
    
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

def board_refresh(off, on):
    dict_keys = list(on.keys())
    
    # Determine the maximum length to know when to stop
    max_length = max(len(dict_keys), len(off))
    
    # Alternate between operations
    for i in range(max_length):
        # If we have keys left, set light color
        if i < len(dict_keys):
            key = dict_keys[i]
            value = on[key]
            set_light_color(key, value)
        
        # If we have values left, turn off lights
        if i < len(off):
            turn_off_light(off[i])

def main():
    # Add all new active stops to a dictionary.
    active_stops = intake_trains()
    print(f"active_stops:{active_stops}")
    # Send all lights that are on from previous refresh to list.
    currently_on = get_on_lights()
    print(f"currently_on:{currently_on}")
    # Update currently_on to only include stops that are no longer active.
    final_off = actual_off(currently_on, active_stops)
    print(f"final_off:{final_off}")
    # Update active_stops to only include stations that were not previously lit.
    final_on = actual_on(currently_on, active_stops)
    print(f"final_on:{final_on}")
    # Finally update the board
    board_refresh(final_off, final_on)

    sys.exit(0)

if __name__ == "__main__":
    main()