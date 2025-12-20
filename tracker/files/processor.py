import os
import csv
import json
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

# Read the ctastationlist.csv file to create a lookup dictionary
def load_station_lookup():
    station_lookup = {}
    try:
        with open("/data/ctastationlist.csv", "r") as f:
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
        
        # Debug: Print raw data for inspection
        print(f"Raw data from {file_path}:")
        print(json.dumps(data, indent=2))
        
        trains = []
        if "route" in data and len(data["route"]) > 0:
            route = data["route"][0]
            if "@name" in route:
                line_name = route["@name"]
                for train in route.get("train", []):
                    train_obj = {
                        "rn": train.get("rn"),
                        "nextStaId": train.get("nextStaId"),
                        "isApp": train.get("isApp"),
                        "isDly": train.get("isDly"),
                        "flags": train.get("flags"),
                        "trDr": train.get("trDr"),
                        "color": color_key,
                    }
                    # Debug: Print each train object
                    print(f"Train object: {train_obj}")
                    trains.append(train_obj)
        else:
            print(f"No route found in {file_path}")
        return trains
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return []

# Main function to combine all JSON files
def main():
    # Load the station lookup dictionary
    station_lookup = load_station_lookup()
    
    # Debug: Print sample of station lookup
    print("Sample station_lookup:", list(station_lookup.items())[:5])
    
    print("Processor Running")
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
    
    # Debug: Print color files
    print("Color files:", color_files)
    
    # Collect all train objects
    all_trains = []
    
    # Process each color file
    for color_key, file_path in color_files.items():
        if os.path.exists(file_path):
            print(f"Processing {file_path}")
            trains = process_json_file(file_path, color_key)
            print(f"Got {len(trains)} trains from {file_path}")
            all_trains.extend(trains)
        else:
            print(f"File not found: {file_path}")
    print("Color Added")
    
    # Debug: Print total number of trains collected
    print(f"Total trains collected before adding unifiedId: {len(all_trains)}")
    
    # Add unifiedId to each train
    for train in all_trains:
        next_sta_id = train.get("nextStaId")
        color = train.get("color")
        if next_sta_id and color:
            # Use the color as the line name in the lookup
            unified_id = station_lookup.get((next_sta_id, color))
            if unified_id:
                train["unifiedId"] = unified_id
    
    # Save to output file
    output_path = "/data/active_train_summary.json"
    try:
        with open(output_path, 'w') as f:
            json.dump(all_trains, f, indent=2)
        print(f"Successfully saved to {output_path}")
    except Exception as e:
        print(f"Error saving to {output_path}: {e}")
    
    # Debug: Print final output
    print("Final trains list:")
    for t in all_trains:
        print(t)
    print(f"Total number of trains in final output: {len(all_trains)}")

if __name__ == "__main__":
    main()