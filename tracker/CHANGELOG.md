<!-- https://developers.home-assistant.io/docs/add-ons/presentation#keeping-a-changelog -->
## 0.7.1
- Global Brightness is now a `light.template` entity (was `number.template`)
- Brightness entity ID is auto-derived from `light_board` config value: `{light_board}_global_brightness`
- Brightness is controlled via Home Assistant's native Light entity with built-in brightness slider

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