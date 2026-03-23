#!/usr/bin/env python3
import json
import sys
import os

previous_trains_path = "/tmp/test_previous_trains.json"

with open(previous_trains_path, "w") as f:
    json.dump({"815": 100, "817": 105, "999": 200}, f)

os.environ["LIGHT_BOARD_BASE"] = "testboard"
os.environ["DATA_REFRESH_INTERVAL_SEC"] = "30"
os.environ["SUPERVISOR_TOKEN"] = "fake_token"
os.environ["CTA_STATION_LIST"] = "/home/sean/Code Projects/cta-location-tracker/tracker/files/ctastationlist.csv"
os.environ["BYPASS_MODE"] = "true"
os.environ["RED_COLOR"] = "198, 12, 48"
os.environ["BLUE_COLOR"] = "0, 161, 222"
os.environ["GREEN_COLOR"] = "0, 155, 58"
os.environ["YELLOW_COLOR"] = "249, 227, 0"
os.environ["ORANGE_COLOR"] = "255, 146, 25"
os.environ["PINK_COLOR"] = "226, 126, 166"
os.environ["PURPLE_COLOR"] = "82, 35, 152"
os.environ["BROWN_COLOR"] = "150, 75, 0"

sys.path.insert(0, "/home/sean/Code Projects/cta-location-tracker/tracker/files")

import graphicrefresh

print("=== Bypass Mode Test ===")
print(f"Bypass mode enabled: {graphicrefresh.bypass_mode}")
print(f"COLORS dict: {graphicrefresh.COLORS}")
print(f"STATION_COLORS count: {len(graphicrefresh.STATION_COLORS)}")

csv_path = os.environ.get("CTA_STATION_LIST", "/data/ctastationlist.csv")
df = graphicrefresh.pd.read_csv(csv_path)
unique_ids = df["unifiedId"].dropna().astype(int).unique()
print(f"Unique station IDs from CSV: {len(unique_ids)}")
print(f"Sample IDs: {list(unique_ids[:5])}")

print("\n=== Expected behavior in bypass mode ===")
print("- Should turn on ALL station LEDs (191 stations with valid unifiedId)")
print("- Each LED should use color based on its line from CSV")
print("- Should NOT make any API calls to CTA (skipped in processor.py)")
print("- Should NOT fetch live train data")

success = graphicrefresh.bypass_mode and len(graphicrefresh.STATION_COLORS) > 0
print(f"\n=== Test result: {'PASS' if success else 'FAIL'} ===")