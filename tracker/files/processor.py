import os
import sys
import signal
import json
import requests
import pandas as pd
from concurrent.futures import ThreadPoolExecutor, as_completed

# Define colors dictionary with environment variable fallbacks
COLORS = {
    "red": os.environ.get("RED_COLOR", "198, 12, 48"),
    "blue": os.environ.get("BLUE_COLOR", "0, 161, 222"),
    "brn": os.environ.get("BROWN_COLOR", "150, 75, 0"),
    "g": os.environ.get("GREEN_COLOR", "0, 155, 58"),
    "org": os.environ.get("ORANGE_COLOR", "255, 146, 25"),
    "p": os.environ.get("PURPLE_COLOR", "82, 35, 152"),
    "pink": os.environ.get("PINK_COLOR", "226, 126, 166"),
    "y": os.environ.get("YELLOW_COLOR", "249, 227, 0"),
}
ROUTE_IDS = ("red", "blue", "brn", "g", "org", "p", "pink", "y")
# output_path = os.environ.get("JSON_FILE", "/data/active_train_summary.json")
stationlist = os.environ.get("CTA_STATION_LIST", "/data/ctastationlist.csv")
station_frequency_csv = "/share/station_frequency.csv"
api_key = os.environ.get("API_KEY")
bidirectional = os.environ.get("BIDIRECTIONAL", "true")
trainsperline = int(os.environ.get("TRAINS_PER_LINE", 0))
bypass_mode = os.environ.get("BYPASS_MODE", "false") == "true"


def fetch_route_data(route_id):
    api_url = f"http://lapi.transitchicago.com/api/1.0/ttpositions.aspx?key={api_key}&rt={route_id}&outputType=JSON"
    try:
        response = requests.get(
            api_url, timeout=3, headers={"User-Agent": "Mozilla/5.0"}
        )
        if response.status_code == 200:
            data = response.json()
            try:
                trains = data["ctatt"]["route"][0]["train"]
                df = pd.DataFrame(trains)
                if not df.empty:
                    df["color"] = route_id
                    df["rgb"] = COLORS.get(route_id, "255, 255, 255")
                    return df, "success"
            except (KeyError, IndexError):
                return pd.DataFrame(), "no_data"
        else:
            return pd.DataFrame(), "failed"
    except Exception as e:
        print(f"Error fetching Route {route_id}: {e}", file=sys.stderr)
        return pd.DataFrame(), "error"

    return pd.DataFrame(), "error"


def track_station_frequency(df, csv_path):
    if df.empty or "nextStaId" not in df.columns or "color" not in df.columns:
        return

    counts_df = df.groupby(["nextStaId", "color"]).size().reset_index(name="count")
    counts_df["nextStaId"] = counts_df["nextStaId"].astype(int)
    counts_df["color"] = counts_df["color"].astype(str).str.strip()
    counts_df["last_seen"] = pd.Timestamp.now().isoformat()

    try:
        if os.path.exists(csv_path):
            existing_df = pd.read_csv(csv_path)
            if "color" not in existing_df.columns or "nextStaId" not in existing_df.columns:
                print("WARNING: frequency CSV missing required columns, recreating", file=sys.stderr)
                counts_df.to_csv(csv_path, index=False)
                return
            existing_df = existing_df.drop_duplicates(subset=["nextStaId", "color"], keep="last")
            for _, row in counts_df.iterrows():
                mask = (existing_df["nextStaId"] == row["nextStaId"]) & (existing_df["color"] == row["color"])
                if mask.any():
                    existing_df.loc[mask, "count"] += row["count"]
                    existing_df.loc[mask, "last_seen"] = row["last_seen"]
                else:
                    existing_df = pd.concat(
                        [existing_df, row.to_frame().T], ignore_index=True
                    )
            existing_df.to_csv(csv_path, index=False)
        else:
            counts_df.to_csv(csv_path, index=False)
    except Exception as e:
        print(f"Error updating frequency CSV: {e}", file=sys.stderr)


def handle_broken_pipe(signum, frame):
    sys.exit(0)


signal.signal(signal.SIGPIPE, handle_broken_pipe)


def main():
    if bypass_mode:
        print("[]")
        return

    results = []
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(fetch_route_data, route): route for route in ROUTE_IDS}
        for future in as_completed(futures):
            route = futures[future]
            try:
                result = future.result()
                results.append((route, result))
            except Exception as e:
                print(f"Error fetching Route {route}: {e}", file=sys.stderr)
                results.append((route, (pd.DataFrame(), "error")))

    train_counts = {}
    dfs = []
    for route, (df, status) in results:
        if status == "success":
            train_counts[route] = len(df)
            dfs.append(df)
        elif status == "no_data":
            train_counts[route] = 0

    if not dfs:
        print("No train data available across any routes.", file=sys.stderr)
        print("[]")
        return

    summary = ", ".join(f"{route}={train_counts.get(route, 0)}" for route in ROUTE_IDS)
    total = sum(train_counts.values())
    print(f"Fetched trains: {summary} (total {total})", file=sys.stderr)

    master_df = pd.concat(dfs, ignore_index=True)

    if bidirectional.lower() == "false":
        master_df = master_df[master_df["trDr"] == "1"]

    if trainsperline != 0:
        master_df = (
            master_df.groupby("color").head(trainsperline).reset_index(drop=True)
        )

    try:
        stations_df = pd.read_csv(stationlist)
        stations_df = stations_df.rename(columns={"line": "color"})[
            ["nextStaId", "color", "unifiedId"]
        ]
        stations_df["nextStaId"] = stations_df["nextStaId"].astype(str).str.strip()
        stations_df["color"] = stations_df["color"].astype(str).str.strip()
        master_df["nextStaId"] = master_df["nextStaId"].astype(str).str.strip()

        master_df = master_df.merge(stations_df, on=["nextStaId", "color"], how="left")
        master_df = master_df.dropna(subset=["unifiedId"])
        master_df["unifiedId"] = master_df["unifiedId"].astype(int)
    except Exception as e:
        print(f"Error processing station list CSV: {e}", file=sys.stderr)

    track_station_frequency(master_df, station_frequency_csv)

    output_data = []
    for _, row in master_df.iterrows():
        output_data.append(
            {
                "unifiedId": int(row["unifiedId"]),
                "rgb": row["rgb"],
                "color": row["color"],
                "rn": str(row["rn"]),
            }
        )

    print(json.dumps(output_data), file=sys.stdout)


if __name__ == "__main__":
    main()
