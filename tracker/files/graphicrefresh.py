import os
import json
import requests
import sys
import re
import time
import pandas as pd

token = os.environ.get("SUPERVISOR_TOKEN")
boardname = os.environ.get("LIGHT_BOARD_BASE")
refresh_interval = int(os.environ.get("DATA_REFRESH_INTERVAL_SEC", 60))
previous_trains_path = "/data/previous_trains.json"
bypass_mode = os.environ.get("BYPASS_MODE", "false") == "true"

STATION_COLORS = {}
COLORS = {
    "red": os.environ.get("RED_COLOR", "198, 12, 48"),
    "pink": os.environ.get("PINK_COLOR", "226, 126, 166"),
    "org": os.environ.get("ORANGE_COLOR", "255, 146, 25"),
    "y": os.environ.get("YELLOW_COLOR", "249, 227, 0"),
    "g": os.environ.get("GREEN_COLOR", "0, 155, 58"),
    "blue": os.environ.get("BLUE_COLOR", "0, 161, 222"),
    "p": os.environ.get("PURPLE_COLOR", "82, 35, 152"),
    "brn": os.environ.get("BROWN_COLOR", "150, 75, 0"),
}
csv_path = os.environ.get("CTA_STATION_LIST", "/data/ctastationlist.csv")
try:
    df = pd.read_csv(csv_path)
    for _, row in df.iterrows():
        STATION_COLORS[int(row["unifiedId"])] = row["line"]
except Exception as e:
    print(f"WARNING: Could not load station color map: {e}", file=sys.stderr)


# Function Definitions
def get_global_brightness():
    brightness_entity = f"number.{boardname}global_brightness"
    try:
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }
        response = requests.get(
            f"http://supervisor/core/api/states/{brightness_entity}",
            headers=headers,
            timeout=3,
        )
        if response.status_code == 200:
            return int(float(response.json().get("state", 100)))
    except Exception as e:
        print(
            f"WARNING: Could not fetch brightness from {brightness_entity}: {e}",
            file=sys.stderr,
        )
    return 100


def get_on_lights():
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    response = requests.get("http://supervisor/core/api/states", headers=headers)
    states_json = response.json()

    on_ids = set()
    for entity in states_json:
        if entity.get("entity_id", "").startswith(f"light.{boardname}"):
            if entity.get("state") == "on":
                match = re.search(r"_(\d+)$", entity.get("entity_id", ""))
                if match:
                    on_ids.add(int(match.group(1)))

    return on_ids


def load_previous_trains():
    try:
        if os.path.exists(previous_trains_path):
            with open(previous_trains_path, "r") as f:
                data = json.load(f)
                return {rn: int(uid) for rn, uid in data.items()}
    except Exception as e:
        print(f"WARNING: Could not load previous trains: {e}", file=sys.stderr)
    return {}


def save_previous_trains(trains):
    try:
        with open(previous_trains_path, "w") as f:
            json.dump(trains, f)
    except Exception as e:
        print(f"WARNING: Could not save previous trains: {e}", file=sys.stderr)


def set_light_color(sta_id, color_rgb):
    if isinstance(color_rgb, str):
        color_rgb = [int(val.strip()) for val in color_rgb.split(",")]
    data = {
        "entity_id": f"light.{boardname}{sta_id}",
        "rgb_color": color_rgb,
        "brightness_pct": get_global_brightness(),
    }

    # Send POST request
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    try:
        response = requests.post(
            "http://supervisor/core/api/services/light/turn_on",
            headers=headers,
            json=data,
        )

        # Check if request was successful
        if response.status_code != 200:
            print(
                f"ERROR: Failed to set light color. Status code: {response.status_code}"
            )
            print(f"ERROR: Response details - {response.text}")

    except Exception as e:
        print(f"ERROR: Exception occurred - {str(e)}")
        print(f"ERROR: Exception type - {type(e).__name__}")


def turn_off_light(sta_id):
    # Prepare the request
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

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
            print(
                "ERROR: Bad Request returned from Home Assistant - likely invalid entity ID or malformed request",
                file=sys.stderr,
            )
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
            unified_id = item.get("unifiedId", -1)
            rn = item.get("rn")
            if 0 <= unified_id <= 319 and rn:
                result_dict[rn] = {
                    "unifiedId": unified_id,
                    "rgb": item.get("rgb", "255,255,255"),
                    "color": item.get("color", "unknown"),
                }
            else:
                if unified_id < 0 or unified_id > 319:
                    print(
                        f"Warning: Invalid unifiedId: {unified_id}. Skipping.",
                        file=sys.stderr,
                    )
                if not rn:
                    print(
                        f"Warning: Missing rn for unifiedId: {unified_id}. Skipping.",
                        file=sys.stderr,
                    )

    except json.JSONDecodeError as e:
        print(f"Error parsing JSON from stdin: {e}", file=sys.stderr)
    except Exception as e:
        print(f"Error processing train data: {e}", file=sys.stderr)

    return result_dict


def calculate_changes(prev_trains, curr_trains):
    moved = []
    new_trains = []
    gone_trains = []

    prev_rns = set(prev_trains.keys())
    curr_rns = set(curr_trains.keys())

    for rn in curr_rns:
        if rn in prev_rns:
            prev_id = prev_trains[rn]
            curr_id = curr_trains[rn]["unifiedId"]
            if prev_id != curr_id:
                moved.append((prev_id, curr_id, curr_trains[rn]["rgb"]))
        else:
            new_trains.append((curr_trains[rn]["unifiedId"], curr_trains[rn]["rgb"]))

    for rn in prev_rns - curr_rns:
        gone_trains.append(prev_trains[rn])

    return moved, new_trains, gone_trains


def board_refresh(moved, new_trains, gone_trains, refresh_interval):
    moved_count = len(moved)
    new_count = len(new_trains)
    gone_count = len(gone_trains)
    total_units = moved_count + new_count + gone_count

    if total_units == 0:
        return 0

    interval_sec = refresh_interval / total_units

    for old_id, new_id, rgb in moved:
        turn_off_light(old_id)
        set_light_color(new_id, rgb)
        if total_units > 1:
            time.sleep(interval_sec)

    for sid in gone_trains:
        turn_off_light(sid)
        if total_units > 1:
            time.sleep(interval_sec)

    for sid, rgb in new_trains:
        set_light_color(sid, rgb)
        if total_units > 1:
            time.sleep(interval_sec)

    return total_units


def main():
    if bypass_mode:
        csv_path = os.environ.get("CTA_STATION_LIST", "/data/ctastationlist.csv")
        try:
            df = pd.read_csv(csv_path)
            unique_ids = set(df["unifiedId"].dropna().astype(int).tolist())

            currently_on = get_on_lights()
            new_on = unique_ids - currently_on
            gone = currently_on - unique_ids

            for sid in gone:
                turn_off_light(sid)

            for sid in new_on:
                line = STATION_COLORS.get(sid, "red")
                rgb = COLORS.get(line, "255, 255, 255")
                set_light_color(sid, rgb)

            save_previous_trains({str(i): i for i in unique_ids})
            print(f"Bypass mode: {len(unique_ids)} stations lit, {len(new_on) + len(gone)} updates", file=sys.stderr)
        except Exception as e:
            print(f"ERROR: Bypass mode failed: {e}", file=sys.stderr)

        sys.exit(0)

    active_trains = intake_trains()
    prev_trains = load_previous_trains()

    moved, new_trains, gone_trains = calculate_changes(prev_trains, active_trains)

    currently_on = get_on_lights()
    expected_on = {data["unifiedId"] for rn, data in active_trains.items()}
    stale_lights = [sid for sid in currently_on if sid not in expected_on]
    gone_trains = list(set(gone_trains + stale_lights))

    total_updates = board_refresh(moved, new_trains, gone_trains, refresh_interval)

    curr_trains = {rn: data["unifiedId"] for rn, data in active_trains.items()}
    save_previous_trains(curr_trains)

    print(f"Data refresh complete: {len(active_trains)} active trains, {total_updates} updates", file=sys.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()
