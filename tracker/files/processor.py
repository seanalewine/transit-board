import csv
import json
import os
import glob
import argparse

# 1. Configuration (Reads colors from environment variables set by Bash wrapper)
# The default values are set to the requested "R, G, B" string format.
COLORS = {
    "red": os.environ.get("RED_COLOR", "255, 0, 0"),
    "blue": os.environ.get("BLUE_COLOR", "0, 0, 255"),
    "brn": os.environ.get("BROWN_COLOR", "98, 54, 27"),
    "g": os.environ.get("GREEN_COLOR", "0, 128, 0"),
    "org": os.environ.get("ORANGE_COLOR", "255, 140, 0"),
    "p": os.environ.get("PURPLE_COLOR", "128, 0, 128"),
    "pink": os.environ.get("PINK_COLOR", "255, 105, 180"),
    "y": os.environ.get("YELLOW_COLOR", "255, 255, 0"),
}

def load_station_map(csv_file_path):
    """
    Loads the CTA station list CSV into a dictionary map for unified ID lookup.
    Key: "nextStaId:line_code" (string)
    Value: unifiedId (integer, to match the original jq | tonumber requirement)
    """
    station_map = {}
    
    if not os.path.exists(csv_file_path):
        print(f"Fatal Error: CSV station list not found at {csv_file_path}")
        return station_map

    print(f"Creating station ID lookup map from {csv_file_path}...")
    try:
        with open(csv_file_path, mode='r', encoding='utf-8-sig') as file:
            reader = csv.reader(file)
            next(reader, None)  # Skip header row

            for row in reader:
                if len(row) < 3:
                    continue
                
                # Assuming columns: 0=nextStaId, 1=line, 2=unifiedId
                next_sta_id = row[0].strip()
                line_code = row[1].strip().lower()
                unified_id_str = row[2].strip()
                
                if next_sta_id and line_code and unified_id_str:
                    try:
                        key = f"{next_sta_id}:{line_code}"
                        # Store as integer (required by the original jq logic)
                        station_map[key] = int(unified_id_str)
                    except ValueError:
                        print(f"Warning: unifiedId '{unified_id_str}' is not numeric. Skipping.")

        print(f"Map created with {len(station_map)} entries.")
    except Exception as e:
        print(f"Error loading station map: {e}")
        
    return station_map

def process_train_data(input_dir, station_map):
    """
    Processes all JSON files, maps IDs, applies colors, and creates the final data structure.
    """
    all_trains = []
    
    train_lines = ("red", "blue", "brn", "g", "org", "p", "pink", "y")
    
    for line_code in train_lines:
        file_path = os.path.join(input_dir, f"{line_code}.json")
        
        if not os.path.exists(file_path):
            print(f"Warning: Input file not found for line {line_code} at {file_path}. Skipping.")
            continue
            
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
        except Exception as e:
            print(f"Warning: Could not read/parse {file_path}. Skipping. Error: {e}")
            continue

        routes = data.get('ctatt', {}).get('route')
        if not routes or not isinstance(routes, list):
            continue

        for route in routes:
            trains = route.get('train')
            if not trains or not isinstance(trains, list):
                continue
                
            for train in trains:
                next_sta_id_str = train.get('nextStaId')
                is_delay = train.get('isDly') == "1"
                is_approach = train.get('isApp') == "1"
                
                if not next_sta_id_str:
                    continue

                # --- Step 1: ID Mapping and 'tonumber' conversion ---
                lookup_key = f"{next_sta_id_str}:{line_code}"
                
                # Check if the key exists in the map
                if lookup_key in station_map:
                    unified_id = station_map[lookup_key]
                else:
                    # Value not found in map. Fallback to original ID and print warning.
                    unified_id = next_sta_id_str
                    print(f"Warning: Could not find unified ID for key '{lookup_key}'. Using original nextStaId: {unified_id}")

                # CRITICAL: Match jq's '| tonumber' behavior: the output field MUST be a JSON number.
                try:
                    unified_id = int(unified_id)
                except (TypeError, ValueError):
                    # If conversion fails, use the original string as a fallback.
                    pass # Keep unified_id as the string value it already is.
                
                # --- Step 2: Determine Status Value ---
                value = 2 if is_delay else (1 if is_approach else 0)

                # --- Step 3: Apply Color ---
                output_color = COLORS.get(line_code, line_code) 
                
                all_trains.append({
                    "nextStaId": unified_id,
                    "output_color": output_color,
                    "value": value
                })
                
    return all_trains

def main():
    parser = argparse.ArgumentParser(description="Process CTA train data.")
    parser.add_argument('--station-list', required=True, help="Path to the CTA station list CSV.")
    parser.add_argument('--input-dir', required=True, help="Directory containing train position JSON files.")
    parser.add_argument('--output-file', required=True, help="Path to the final output JSON file.")
    args = parser.parse_args()

    # 1. Load the map
    station_map = load_station_map(args.station_list)
    
    # 2. Process all data
    final_data = process_train_data(args.input_dir, station_map)
    
    # 3. Write final output
    output_dict = {"trains": final_data}
    
    try:
        with open(args.output_file, 'w') as f:
            json.dump(output_dict, f, indent=4)
        print(f"Successfully processed {len(final_data)} train records.")
    except Exception as e:
        print(f"Fatal Error: Could not write output file {args.output_file}: {e}")
        exit(1)

if __name__ == "__main__":
    main()