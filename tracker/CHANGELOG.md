<!-- https://developers.home-assistant.io/docs/add-ons/presentation#keeping-a-changelog -->
## 1.0.0
- **Major version release** - stable, production-ready
- Architecture: HA addon fetches CTA API → outputs JSON → graphicrefresh.py controls ESPHome lights via HA API
- All core features complete: live train tracking, smart train transitions, bypass mode, station frequency logging, multi-line color support
- This version will be deprecated in favor of v2.0.0 which moves core functionality to ESPHome device

## 0.9.8
- Fixed frequency CSV error: added validation for required columns ("color", "nextStaId") when reading existing CSV, recreates file if columns are missing

## 0.9.7
- Corrected output structure of station_frequency.csv: fixed duplicate nextStaId rows and added multi-color support (tracks composite key)
- Reduced log verbosity: condensed 8 per-route messages to single summary line
- Added parallelization to fetch_route_data: 8 routes now fetched concurrently using ThreadPoolExecutor
- Added 3s timeouts to all HA API calls in graphicrefresh.py to prevent infinite hangs

## 0.9.6
- Moved sleep delay from run.sh to graphicrefresh.py bypass_mode function - ensures pause occurs at end of bypass mode cycle specifically

## 0.9.5
- Fixed bypass mode infinite loop: added sleep between refresh cycles in run.sh
- Reduced verbose logging during normal operation
- Added data refresh summary log output showing active trains and update count

## 0.9.3
- Fixed bypass mode error: `get_on_lights()` now returns a set for proper set operations
- Added test script for bypass mode validation

## 0.9.2
- Added bypass mode: when enabled, skips API calls and displays all CTA stations as lit (useful for testing or when API is unavailable)
- Config option `bypass_mode: bool` added to addon settings (default: false)

## 0.9.1
- Stale light cleanup: compares actual HA light states to expected states and turns off any stale lights that should not be on.

## 0.9.0
- Smart train tracking: now tracks individual trains by their persistent "rn" identifier between refresh cycles
- Moved trains now transition smoothly: when a train moves between stations, its light turns off at the old station and immediately turns on at the new station (single animation step)
- New trains (first appearance) and gone trains (no longer visible) are treated as separate operations
- Previous train state persists across refresh cycles via /data/previous_trains.json

## 0.8.4
- Station frequency data now persists across container restarts using Home Assistant's /share directory
- Data stored in /share/station_frequency.csv instead of /data/
- Web server now serves persistent data via symlink

## 0.8.1
- Added Python HTTP web server to serve station data files (station_frequency.csv, ctastationlist.csv, etc.)
- Web server runs on port 8000 and serves files from /data directory
- Access station data at http://<ha-ip>:8000/station_frequency.csv

## 0.8.0
- Added color-pairing logic for smoother visual updates: lights turning off and on of the same color are now processed together in the same refresh interval
- Color data now included in JSON output from processor to graphicrefresh
- Station color map loaded from ctastationlist.csv at startup

## 0.7.5
- Revised default color values to better match CTA line colors: red (198,12,48), pink (226,126,166), orange (255,146,25), yellow (249,227,0), green (0,155,58), blue (0,161,222), purple (82,35,152), brown (150,75,0)
- Fixed trainsPerLine default mismatch (was 5 in code, now 0)
- Marked api_key and light_board as required options in schema

## 0.7.2
- `light_board` config now accepts device name without `light.` prefix (e.g., `trainboard` instead of `light.trainboard`)
- Brightness entity auto-derived from config: `number.{light_board}_global_brightness`

## 0.7.1
- Brightness entity ID is now auto-derived from `light_board` config value: `{light_board}_global_brightness` (e.g., `number.trainboard_global_brightness`)
- Global Brightness uses `number.template` entity in ESPHome (no `light.template` platform exists)

## 0.7.0
- Board updates are now evenly spaced over the `data_refresh_interval_sec` duration
- Light changes are calculated as: `data_refresh_interval_sec / total_changes`, providing smooth, distributed updates instead of rapid sequential changes
- Removed `indiv_light_refresh_delay_milliseconds` config option (no longer needed)

## 0.6.0
- Brightness is now controlled via ESPHome device slider ("Global Brightness") instead of addon config option
- Removed `brightness` from addon configuration

## 0.5.0
- Stable
- Rewritten in python and data manipulation using pandas
- Refreshes board correctly.
- Config option `indiv_light_refresh_delay_sec` has been changed to `indiv_light_refresh_delay_milliseconds` and is now measured in milliseconds.

## 0.3.0
- Stable
- The following config options work:`api-key`, `light_board`, `brightness`, `data_refresh_interval_sec`, `indiv_light_refresh_delay_sec`, and all color options are functioning.
- Improved but slightly verbose error reporting.

## 0.2.1
- Disable web interface.

## 0.2.0

- Stable!
- Controls W2812 Light Strip
- Features include setting the entity root id, setting the light refresh delay between LEDs, brightness, 
- Imports live data, processes it, and directs ESPHome Light entity to change colors.

## 0.1.0

- Stable!
- Allows user to set their personal CTA Data API Key
-  Allows user to set train line colors, default are CTA specified.
- Outputs interpreted train data at http://[Home Assistant URL]:[PORT]/active_train_summary.json
- Future release to control ESPHome device via HA Core API

---

# v2.0.0 Roadmap

## Architecture Goal
Move core functionality from HA addon to ESPHome device for standalone operation. ESPHome device fetches CTA API directly, processes train data, and controls lights without HA addon dependency.

## Phase 1: Core ESPHome Migration
- Add `http_request` component to fetch CTA API
- Create C++ custom sensor with hardcoded station mapping array (192 entries)
- Implement train tracking (`rn → unifiedId` mapping, detect moved/new/gone)
- Convert partition lights to template lights with color action
- Add config entities: `api_key`, `refresh_interval`, `trains_per_line`, `bidirectional`

## Phase 2: Standalone Operation
- Remove HA API dependency - ESPHome controls lights internally
- Device operates fully without HA addon
- HA addon becomes minimal: copy files, optional frequency logging to console

## Phase 3: Multi-Board Support
- Create `templates/base.yaml` with shared logic
- Create `boards/kitchen.yaml` and `boards/living_room.yaml` as examples
- Each board defines its own unifiedId array (set at compile time)
- Structure supports adding more boards by copy + edit

## Phase 4: Configuration & Features
- Runtime-configurable entities via ESPHome native API to HA:
  - `api_key` (secure text)
  - `refresh_interval` (number)
  - `trains_per_line` (number)
  - `bidirectional` (switch)
  - `bypass_mode` (switch)
  - `brightness` (number - existing)
  - 8 line color entities (select)
  - `holiday_mode` (switch) - detects `rn=1225` (Holiday Train), cycles red/green at station

## Out of Scope
- Technical debt cleanup (deprecated code will be removed, not migrated)
- Station frequency CSV persistence (separate "Board Diagnosis" app)
- Web server on ESPHome