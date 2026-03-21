import os
import sys
import requests
import pandas as pd

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
ROUTE_IDS = ("red", "blue", "brn", "g", "org", "p", "pink", "y")
# output_path = os.environ.get("JSON_FILE", "/data/active_train_summary.json")
stationlist = os.environ.get("CTA_STATION_LIST", "/data/ctastationlist.csv")
api_key = os.environ.get("API_KEY")
bidirectional = os.environ.get("BIDIRECTIONAL", "true")
trainsperline = int(os.environ.get("TRAINS_PER_LINE", 5))

def fetch_route_data(route_id):
    api_url = f"http://lapi.transitchicago.com/api/1.0/ttpositions.aspx?key={api_key}&rt={route_id}&outputType=JSON"
    try:
        response = requests.get(api_url, timeout=3, headers={'User-Agent': 'Mozilla/5.0'})
        if response.status_code == 200:
            data = response.json()
            try:
                trains = data['ctatt']['route'][0]['train']
                df = pd.DataFrame(trains)
                if not df.empty:
                    df['color'] = route_id
                    df['rgb'] = COLORS.get(route_id, "255, 255, 255")
                    # Redirect log to stderr so it doesn't pollute the data pipe
                    print(f"Successfully fetched Route {route_id}. # of trains {len(df)}", file=sys.stderr)
                    return df
            except (KeyError, IndexError):
                print(f"No train data found for Route {route_id}.", file=sys.stderr)
        else:
            print(f"API request failed for {route_id} (Code {response.status_code}).", file=sys.stderr)
    except Exception as e:
        print(f"Error fetching Route {route_id}: {e}", file=sys.stderr)
    
    return pd.DataFrame()

def main():
    dfs = [fetch_route_data(route) for route in ROUTE_IDS]
    dfs = [df for df in dfs if not df.empty]

    if not dfs:
        print("No train data available across any routes.", file=sys.stderr)
        # Output an empty JSON array so the next script doesn't crash on empty input
        print("[]") 
        return

    master_df = pd.concat(dfs, ignore_index=True)

    if bidirectional.lower() == "false":
        master_df = master_df[master_df['trDr'] == '1']

    if trainsperline != 0:
        master_df = master_df.groupby('color').head(trainsperline).reset_index(drop=True)

    try:
        stations_df = pd.read_csv(stationlist, names=['nextStaId', 'color', 'unifiedId'], comment='#', header=None)
        stations_df['nextStaId'] = stations_df['nextStaId'].astype(str).str.strip()
        stations_df['color'] = stations_df['color'].astype(str).str.strip()
        master_df['nextStaId'] = master_df['nextStaId'].astype(str).str.strip()
        
        master_df = master_df.merge(stations_df, on=['nextStaId', 'color'], how='left')
        master_df = master_df.dropna(subset=['unifiedId'])
        master_df['unifiedId'] = master_df['unifiedId'].astype(int)
    except Exception as e:
        print(f"Error processing station list CSV: {e}", file=sys.stderr)

    master_df.to_json(sys.stdout, orient='records')

if __name__ == "__main__":
    main()