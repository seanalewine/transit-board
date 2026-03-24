# Live Transit Board

Real-time transit arrival display using ESPHome and the CTA TrainTracker API.

## About

Live Transit Board pulls real-time train arrival data from the Chicago Transit Authority (CTA) TrainTracker API and displays it on a physical LED display powered by an ESP32 microcontroller running ESPHome.

The board shows upcoming arrivals for configured stations, with each LED representing a station stop. When a train approaches, the corresponding LED lights up.

## Features

- Real-time CTA train arrival data
- Configurable station mapping
- Standalone deployment (runs on ESP32 directly)
- Home Assistant integration (managed via ESPHome addon)

## Hardware

- ESP32 or ESP32-C3 microcontroller
- Addressable RGB LED strip (WS2812B/NeoPixel)
- 3D printed case (optional)

## Deployment

### Standalone

Flash the ESPHome firmware directly to your device and configure your WiFi credentials. The board will fetch data directly from the CTA API.

### Home Assistant

Integrate via the ESPHome addon in Home Assistant for seamless monitoring and control alongside your other smart home devices.

## API Key

You will need to request your own API key from the CTA to use this project. Visit [CTA TrainTracker](https://www.transitchicago.com/developers/traintracker/) for more information.

## License

[MIT](LICENSE)