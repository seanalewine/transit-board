import os
import sys
import signal
import requests
import pandas as pd

# Define colors dictionary with environment variable fallbacks
COLORS = {
    "red": os.environ.get("RED_COLOR", "198, 12, 48"),
    "blue": os.environ.get("BLUE_COLOR", "0, 161, 222"),
    "brn": os.environ.get("BROWN_COLOR", "150, 75, 0"),
    "g": os.environ.get("GREEN_COLOR", "0, 155, 58"),
    "org": os.environ.get("ORANGE_COLOR", "255, 146, 25"),
    "p": os.environ.get("PURPLE_COLOR", "82, 35, 152"),
    "pink": os.environ.get("PINK_COLOR", "226, 126, 166"),
    "y": os.environ.get("YELLOW_COLOR", "249, 227, 0")
}
ROUTE_IDS = ("red", "blue", "brn", "g", "org", "p", "pink", "y")
# output_path = os.environ.get("JSON_FILE", "/data/active_train_summary.json")
stationlist = os.environ.get("CTA_STATION_LIST", "/data/ctastationlist.csv")
station_frequency_csv = "/data/station_frequency.csv"
api_key = os.environ.get("API_KEY")
bidirectional = os.environ.get("BIDIRECTIONAL", "true")
trainsperline = int(os.environ.get("TRAINS_PER_LINE", 0))

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

def track_station_frequency(df, csv_path):
    if df.empty or 'nextStaId' not in df.columns:
        return
    
    counts_df = df['nextStaId'].value_counts().reset_index()
    counts_df.columns = ['nextStaId', 'count']
    counts_df['last_seen'] = pd.Timestamp.now().isoformat()
    
    try:
        if os.path.exists(csv_path):
            existing_df = pd.read_csv(csv_path)
            for _, row in counts_df.iterrows():
                mask = existing_df['nextStaId'] == row['nextStaId']
                if mask.any():
                    existing_df.loc[mask, 'count'] += row['count']
                    existing_df.loc[mask, 'last_seen'] = row['last_seen']
                else:
                    existing_df = pd.concat([existing_df, row.to_frame().T], ignore_index=True)
            existing_df.to_csv(csv_path, index=False)
        else:
            counts_df.to_csv(csv_path, index=False)
    except Exception as e:
        print(f"Error updating frequency CSV: {e}", file=sys.stderr)

def handle_broken_pipe(signum, frame):
    sys.exit(0)

signal.signal(signal.SIGPIPE, handle_broken_pipe)

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
        stations_df = pd.read_csv(stationlist)
        stations_df = stations_df.rename(columns={'line': 'color'})[['nextStaId', 'color', 'unifiedId']]
        stations_df['nextStaId'] = stations_df['nextStaId'].astype(str).str.strip()
        stations_df['color'] = stations_df['color'].astype(str).str.strip()
        master_df['nextStaId'] = master_df['nextStaId'].astype(str).str.strip()
        
        master_df = master_df.merge(stations_df, on=['nextStaId', 'color'], how='left')
        master_df = master_df.dropna(subset=['unifiedId'])
        master_df['unifiedId'] = master_df['unifiedId'].astype(int)
    except Exception as e:
        print(f"Error processing station list CSV: {e}", file=sys.stderr)

    track_station_frequency(master_df, station_frequency_csv)

    master_df.to_json(sys.stdout, orient='records')

if __name__ == "__main__":
    main()