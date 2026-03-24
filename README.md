# Live Transit Board (works with CTA)

## Recommended: ESPHome Standalone Implementation

**For new installations, use the ESPHome implementation in `esphome-controller/`**. This is the recommended approach - the device operates standalone without requiring the Home Assistant add-on.

### Features
- ESPHome device fetches CTA API directly
- Full standalone operation without HA addon
- Web-based configuration via built-in web server
- Automatic OTA updates via GitHub Releases
- Configurable via Home Assistant or web browser

### Quick Start
1. Flash ESPHome firmware to ESP32-C6 device
2. Connect to "Transit Board" WiFi AP to configure WiFi
3. Enter CTA API key via web interface or HA
4. Device operates independently


