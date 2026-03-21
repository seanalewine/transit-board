import os
import csv
import json
import requests
import sys
import subprocess
from collections import defaultdict

# Define colors dictionary with environment variable fallbacks
COLORS = {
    "red": os.environ.get("RED_COLOR", "255, 0, 0"),
    "blue": os.environ.get("BLUE_COLOR", "0, 0, 255"),
    "brn": os.environ.get("BROWN_COLOR", "98, 54, 27"),
    "g": os.environ.get("GREEN_COLOR", "0, 128, 0"),
    "org": os.environ.get("ORANGE_COLOR", "255, 140, 0"),
    "p": os.environ.get("PURPLE_COLOR", "128, 0, 128"),
    "pink": os.environ.get("PINK_COLOR", "255, 105, 180"),
    "y": os.environ.get("YELLOW_COLOR", "255, 255, 0")
}
ROUTE_IDS=("red", "blue", "brn", "g", "org", "p", "pink", "y")
output_path = os.environ.get("JSON_FILE","/data/active_train_summary.json")
stationlist = os.environ.get("CTA_STATION_LIST","/data/ctastationlist.csv")
api_key = os.environ.get("API_KEY")
persist_dir = os.environ.get("PERSIST_DIR", "/data/position")
bidirectional = os.environ.get("BIDIRECTIONAL","true")
trainsperline = int(os.environ.get("TRAINS_PER_LINE", 5))

def fetch_route_data(route_id):
    """
    Fetch real-time transit data for a specific route from Chicago Transit Authority API
    
    Args:
        route_id (str): The transit route ID to fetch data for
    
    Returns:
        bool: True if successful, False otherwise
    """
    
    # Construct the API URL
    api_url = f"http://lapi.transitchicago.com/api/1.0/ttpositions.aspx?key={api_key}&rt={route_id}&outputType=JSON"
    
    # Construct the file path
    json_file = os.path.join(persist_dir, f"/{route_id}.json")
    
    try:
        # Make the request with timeout and error handling
        response = requests.get(
            api_url,
            timeout=1,  # 1 second timeout
            headers={'User-Agent': 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:15.0) Gecko/20100101 Firefox/15.0.1'}
        )
        
        # Check if request was successful
        if response.status_code == 200:
            # Save the data to file
            with open(json_file, 'w') as f:
                f.write(response.text)
            data = response.json()
            train_count = len(data['ctatt']['route'][0]['train']) if 'ctatt' in data and 'route' in data['ctatt'] and data['ctatt']['route'] and 'train' in data['ctatt']['route'][0] else 0

            print(f"Successfully fetched data for Route {route_id}. # of trains {train_count}")
            return True
            
        else:
            # Handle non-200 responses
            print(f"Error: API request failed for Route {route_id} with HTTP status code {response.status_code}.")
            print(f"Request URL: {api_url}")
            
            # Remove the potentially incomplete/erroneous file if it exists
            if os.path.exists(json_file):
                try:
                    os.remove(json_file)
                    print(f"Removed potentially erroneous file: {json_file}")
                except OSError as e:
                    print(f"Warning: Could not remove file {json_file}: {e}")
            
            return False
            
    except requests.exceptions.RequestException as e:
        # Handle network-related errors
        print(f"Error: Network request failed for Route {route_id}: {str(e)}")
        print(f"Request URL: {api_url}")
        
        # Remove the potentially incomplete/erroneous file if it exists
        if os.path.exists(json_file):
            try:
                os.remove(json_file)
                print(f"Removed potentially erroneous file: {json_file}")
            except OSError as e:
                print(f"Warning: Could not remove file {json_file}: {e}")
        
        return False
    except Exception as e:
        # Handle any other unexpected errors
        print(f"Error: Unexpected error for Route {route_id}: {str(e)}")
        print(f"Request URL: {api_url}")
        
        # Remove the potentially incomplete/erroneous file if it exists
        if os.path.exists(json_file):
            try:
                os.remove(json_file)
                print(f"Removed potentially erroneous file: {json_file}")
            except OSError as e:
                print(f"Warning: Could not remove file {json_file}: {e}")
        
        return False

def correct_bidirectional(route_id):
    """
    Correct bidirectional train data in JSON file
    
    Args:
        route_id (str): The route identifier
        persist_dir (str): Directory where JSON files are stored
    """
    json_file = os.path.join(persist_dir, f"/{route_id}.json")
    
    # Check if file exists
    if not os.path.exists(json_file):
        print(f"Error: File {json_file} does not exist.")
        return True
    elif os.path.getsize(json_file) == 0:
        print(f"Warning: File {json_file} is empty, skipping processing.")
        return True
    else:
        # Validate JSON format
        try:
            with open(json_file, 'r') as f:
                json.load(f)
        except json.JSONDecodeError as e:
            print(f"Error: File {json_file} contains invalid JSON.")
            return True
    
    # Check if the structure exists and has train data
    try:
        with open(json_file, 'r') as f:
            data = json.load(f)
        
        # Check for train data in route structure
        has_train_data = False
        if 'ctatt' in data and 'route' in data['ctatt']:
            for route in data['ctatt']['route']:
                if isinstance(route, dict) and 'train' in route and route['train']:
                    has_train_data = True
                    break
        
        if not has_train_data:
            print(f"Warning: No train data found in {json_file}, skipping processing.")
            return 0
        else:
            # Apply transformation safely
            # Process the data to filter trains with trDr == "1"
            for route in data['ctatt']['route']:
                if isinstance(route, dict) and 'train' in route and route['train']:
                    route['train'] = [train for train in route['train'] 
                                    if train.get('trDr') == '1']
            
            # Write back to file
            with open(json_file + '.tmp', 'w') as f:
                json.dump(data, f, indent=2)
            
            # Replace original file
            os.replace(json_file + '.tmp', json_file)
            
    except Exception as e:
        print(f"Error processing {json_file}: {e}")
        return 0
    
    return 0

def truncate_train_entries(route_id):
    json_file = os.path.join(persist_dir, f"/{route_id}.json")
    
    # Check if file exists
    if not os.path.exists(json_file):
        print(f"Error: File {json_file} does not exist.")
        return 0
    elif os.path.getsize(json_file) == 0:
        print(f"Warning: File {json_file} is empty, skipping processing.")
        return 0
    else:
        # Validate JSON
        try:
            with open(json_file, 'r') as f:
                data = json.load(f)
        except json.JSONDecodeError:
            print(f"Error: File {json_file} contains invalid JSON.")
            return 0
        
        # Truncate the train array to first few entries
        try:
            
            # Navigate to the train array and truncate it
            if 'ctatt' in data and 'route' in data['ctatt'] and len(data['ctatt']['route']) > 0:
                if 'train' in data['ctatt']['route'][0]:
                    data['ctatt']['route'][0]['train'] = data['ctatt']['route'][0]['train'][:trainsperline]
            
            # Write back to file
            with open(json_file, 'w') as f:
                json.dump(data, f, indent=2)
                
        except Exception as e:
            print(f"Error processing file {json_file}: {e}")
            return 0
    
    return 0

# Read the ctastationlist.csv file to create a lookup dictionary
def load_station_lookup():
    station_lookup = {}
    try:
        with open(stationlist, "r") as f:
            for line in f:
                if not line.strip() or line.startswith("#"):
                    continue
                parts = line.strip().split(",")
                if len(parts) >= 3:
                    next_sta_id = parts[0].strip()
                    line_name = parts[1].strip()
                    unified_id = parts[2].strip()
                    station_lookup[(next_sta_id, line_name)] = unified_id
    except Exception as e:
        print(f"Error reading ctastationlist.csv: {e}")
    return station_lookup

# Process a single JSON file
def process_json_file(file_path, color_key):
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
        
        trains = []
        # Check if we have the expected structure
        if "ctatt" in data and "route" in data["ctatt"]:
            for route in data["ctatt"]["route"]:
                if "@name" in route and route["@name"] == color_key:
                    for train in route.get("train", []):
                        train_obj = {
                            "rn": train.get("rn"),
                            "nextStaId": train.get("nextStaId"),
                            "isApp": train.get("isApp"),
                            "isDly": train.get("isDly"),
                            "flags": train.get("flags"),
                            "trDr": train.get("trDr"),
                            "color": color_key,
                            "rgb": COLORS.get(color_key, "255, 255, 255")
                        }
                        trains.append(train_obj)
        else:
            print(f"Data for {color_key} line malformed or no trains.")
        return trains
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return []

# Main function to combine all JSON files
def main():
    # Load the station lookup dictionary
    station_lookup = load_station_lookup()
    
    # Define the expected file names
    color_files = {
        "red": "/data/position/red.json",
        "blue": "/data/position/blue.json",
        "brn": "/data/position/brn.json",
        "g": "/data/position/g.json",
        "org": "/data/position/org.json",
        "p": "/data/position/p.json",
        "pink": "/data/position/pink.json",
        "y": "/data/position/y.json"
    }

    for route in ROUTE_IDS:
        fetch_route_data(route)
    
    #Set trains to only one direction, defaults to '1' or Northbound
    if bidirectional.lower() == "false":
        print("Bidirectional is set to 'false' so only Northbound trains will display.")
        for ROUTE in ROUTE_IDS:
            correct_bidirectional(ROUTE)

    # Check if there is a config limit set for trains per line then run function to reduce number of trains.
    if trainsperline != 0:
        print(f"Trains per line limited to: {trainsperline}. Removing excess trains.")
        for ROUTE in ROUTE_IDS:
            truncate_train_entries(ROUTE)

    
    # Collect all train objects
    all_trains = []
    
    # Process each color file
    for color_key, file_path in color_files.items():
        if os.path.exists(file_path):
            #print(f"Processing {file_path}")
            trains = process_json_file(file_path, color_key)
            #print(f"Got {len(trains)} trains from {file_path}")
            all_trains.extend(trains)
        else:
            print(f"File not found: {file_path}")
    
    # Add unifiedId to each train
    for train in all_trains:
        next_sta_id = train.get("nextStaId")
        color = train.get("color")
        if next_sta_id and color:
            # Use the color as the line name in the lookup
            unified_id = station_lookup.get((next_sta_id, color))
            if unified_id is not None:
                # Convert to integer
                try:
                    train["unifiedId"] = int(unified_id)
                except (ValueError, TypeError):
                    print(f"Warning: Could not convert unified_id '{unified_id}' to integer. Skipping train.")
                    continue
    
    # Save to output file
    try:
        with open(output_path, 'w') as f:
            json.dump(all_trains, f, indent=2)
        print(f"Successfully saved to {output_path}")
    except Exception as e:
        print(f"Error saving to {output_path}: {e}")
    
    # Debug: Print final output
    #print("Final trains list:")
    #for t in all_trains:
    #    print(t)
    #print(f"Total number of trains in final output: {len(all_trains)}")

if __name__ == "__main__":
    main()
