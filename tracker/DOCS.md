# Live Train Tracker Server for CTA

## How to use

Use of this add-on requires the following steps before it will do anything.

1. Request API key from CTA and add to configuration tab and enter that for the `api_key` value.(Other transit agenceis may be added later.)
2. Setup your ESPHome device with attached individual rgb lights to be controlled by this add-on. Then set the  `light_board` value on the configuration page to the entity ID of your device.
3. Each light needs to be programmed to correlate with the correct stop by 
