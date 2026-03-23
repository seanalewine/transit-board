#!/usr/bin/env python3
import json
import sys
import os

previous_trains_path = "/tmp/test_previous_trains.json"

with open(previous_trains_path, 'w') as f:
    json.dump({"815": 100, "817": 105, "999": 200}, f)

os.environ["LIGHT_BOARD_BASE"] = "testboard"
os.environ["DATA_REFRESH_INTERVAL_SEC"] = "30"
os.environ["SUPERVISOR_TOKEN"] = "fake_token"
os.environ["CTA_STATION_LIST"] = "/home/sean/Code Projects/cta-location-tracker/tracker/files/ctastationlist.csv"

sys.path.insert(0, "/home/sean/Code Projects/cta-location-tracker/tracker/files")

import importlib
import graphicrefresh
importlib.reload(graphicrefresh)

graphicrefresh.previous_trains_path = previous_trains_path

from io import StringIO

old_stdin = sys.stdin
train_data = [
    {"unifiedId": 105, "rgb": "198,12,48", "color": "red", "rn": "817"},
    {"unifiedId": 110, "rgb": "198,12,48", "color": "red", "rn": "815"},
    {"unifiedId": 150, "rgb": "0,161,222", "color": "blue", "rn": "920"}
]
sys.stdin = StringIO(json.dumps(train_data))

active_trains = graphicrefresh.intake_trains()
print(f"Current trains: {active_trains}")

prev_trains = graphicrefresh.load_previous_trains()
print(f"Previous trains: {prev_trains}")

moved, new_trains, gone = graphicrefresh.calculate_changes(prev_trains, active_trains)
print(f"\nMoved: {moved}")
print(f"New: {new_trains}")
print(f"Gone: {gone}")

print("\n=== Expected behavior ===")
print("- rn 817: station 105 -> 105 (SAME: no action)")
print("- rn 815: station 100 -> 110 (MOVED: turn off 100, turn on 110)")
print("- rn 920: new train at station 150 (NEW: turn on 150)")
print("- rn 999: gone from station 200 (GONE: turn off 200)")

sys.stdin = old_stdin