# Live Transit Board

Real-time transit arrival display using ESPHome and the CTA TrainTracker API.

## About

Live Transit Board pulls real-time train arrival data from the Chicago Transit Authority (CTA) TrainTracker API and displays it via LED light strip powered by an ESP32 microcontroller running ESPHome.

The board shows the next arrival stations, for each train, with each LED representing a station stop. When a train approaches, the corresponding LED lights up.

## Features

- Real-time CTA train arrival data
- Configurable station mapping (for custom implementations)
- Standalone deployment (runs on ESP32 directly)
- Home Assistant integration (managed via ESPHome addon)

## Hardware

- ESP32-C3 or ESP32-C6 microcontroller
- Addressable RGB LED strip (WS2812B/NeoPixel/etc.)
- Method to connect LEDs to a map

## Board Configurations

This project supports multiple deployable boards. Each board has its own configuration in `esphome-controller/boards/` so each board uses the correct stop to LED map.

- `transit-board-a.yaml` - Board A configuration
- `transit-board-b.yaml` - Board B configuration

## First-Time Setup

On first boot, the ESP32 creates a WiFi Access Point named "Transit Board". Connect to it and navigate to `http://192.168.4.1` to enter your WiFi credentials and CTA API key.

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

Update the `platform`, `pin`, `chipset`, `rgb_order`, and `num_leds` values to match your specific LED strip. See the [ESPHome Documentation](https://esphome.io/components/#light-components) for required variables.

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

### Update Modes

- **Quick Update** - All LED changes happen instantly when new train data arrives at the interval configured in settings.
- **Gradual Update** - LED changes are processed one at a time with smooth delays between each transition. Creates a flowing effect as trains appear to move across the board.
- **Bypass** - Ignores live train data and lights up all station LEDs with their line colors. Useful for testing the display or as a demo mode.

## Deployment

### Standalone

Flash the ESPHome firmware directly to your device and configure your WiFi credentials. The board will fetch data directly from the CTA API.

### Home Assistant

Integrate via the ESPHome addon in Home Assistant for seamless monitoring and control alongside your other smart home devices.

## API Key

You will need to request your own API key from the CTA to use this project. Visit [CTA TrainTracker](https://www.transitchicago.com/developers/traintracker/) for more information.

## License

[MIT](LICENSE)
