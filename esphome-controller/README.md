# ESPHome Controller Setup

Configuration Instructions and Files for setting up an ESPHome microcontroller with an attached light strip/array.

## Board Configurations

This project supports multiple LED boards. Each board has its own configuration in the `boards/` directory:

- `transit-board-a.yaml` - Board A configuration
- `transit-board-b.yaml` - Board B configuration

## First-Time Setup

On first boot, the ESP32 creates a WiFi Access Point named "Transit Board". Connect to it and navigate to `http://192.168.4.1` to enter your WiFi credentials and CTA API key.

## Setting Up a Board

Follow instructions on using [ESPHome Web](https://web.esphome.io/) for installing the configuration onto your ESP32 microcontroller.

### LED Strip Configuration

In your board's YAML file, update the `esp32_rmt_led_strip` platform settings:

```yaml
- platform: esp32_rmt_led_strip
  id: stop_indicators 
  rgb_order: GRB
  pin: GPIO0
  internal: true
  default_transition_length: 500ms
  use_psram: false
  num_leds: 320
  chipset: WS2812
  name: "Stop Indicators"
```

Update the `platform`, `pin`, `chipset`, `rgb_order`, and `num_leds` values to match your specific LED strip. The [ESPHome Documentation](https://esphome.io/components/#light-components) is essential for confirming you have all required variables.

## Configurable Options

All options are accessible via the ESPHome web interface or Home Assistant:

| Option | Type | Description |
|--------|------|-------------|
| API Key | Text | Your CTA TrainTracker API key |
| Global Brightness | Number (0-100) | Controls brightness of all LEDs |
| Refresh Interval | Number (7-5000 sec) | Time between API fetches |
| Trains Per Line | Number (0-20) | Max trains to display per line |
| Bidirectional | Switch | Enable tracking in both directions |
| Holiday Mode | Switch | Enable special holiday display mode |
| Update Mode | Select | Quick Update, Gradual Update, or Bypass |

## API Key

You will need to request your own API key from the CTA. Visit [CTA TrainTracker](https://www.transitchicago.com/developers/traintracker/) for more information.

## Home Assistant Integration

The device integrates with Home Assistant via the ESPHome integration, providing entities for all configurable options.