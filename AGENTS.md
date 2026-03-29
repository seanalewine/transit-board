# Agent Coding Guidelines

This document provides instructions for agents working on the Live Transit Board codebase.

## Project Overview

Live Transit Board is an ESPHome project that displays real-time CTA train arrival data on an LED board.
The project fetches data from the CTA TrainTracker API and visualizes train arrivals on physical LED displays.

### Current Structure

```
transit-board/
|- esphome-controller/          # ESPHome firmware
|   |- boards/                   # Board configurations
|   |   |- transit-board-a.yaml
|   |   |- transit-board-b.yaml
|   |   |- .gitignore
|   |- templates/                # Shared C++ templates
|       |- base.yaml
|       |- station_map.h
|       |- train_processor.h
|       |- webserver.css
|- .github/workflows/            # CI/CD pipelines
|   |- esphome-build.yaml        # Firmware builds
|- .devcontainer.json
|- README.md
|- LICENSE
|- repository.yaml
```

## Build/Lint/Test Commands

### ESPHome Validation

```bash
# Install ESPHome
pip install esphome

# Validate a single board config
esphome config esphome-controller/boards/transit-board-a.yaml

# Validate all board configs
for config in esphome-controller/boards/*.yaml; do
  esphome config "$config"
done

# Validate template
esphome config esphome-controller/templates/base.yaml
```

### Build Firmware

```bash
# Build for a specific board
esphome compile esphome-controller/boards/transit-board-a.yaml

# Upload to device (requires device on network)
esphome upload esphome-controller/boards/transit-board-a.yaml
```

### GitHub Actions CI

The repository has one workflow:
- **`esphome-build.yaml`** - Runs on push to `main` or `dev` branches when ESPHome files change

The workflow has four jobs:
1. **lint** - Validates ESPHome YAML configs
3. **build** - Builds firmware (only runs if board version changed)
4. **release** - Creates GitHub releases (only if version changed)

## Code Style Guidelines

### ESPHome YAML

- Use 2-space indentation
- Use lowercase with hyphens for keys: `esphome:`, `sensor:`
- Place secrets in `secrets.yaml` (never commit actual values)
- Use YAML anchors (`&anchor` and `*alias`) for reusable config blocks
- Document hardware-specific settings: chipset, pin, num_leds
- Follow ESPHome v2025.9.0+ syntax

### C++ (Templates)

- Use standard C++17 features
- 4-space indentation
- Use `const` for immutable values
- Name constants: `UPPER_SNAKE_CASE`
- Name functions/variables: `snake_case`
- Name classes: `PascalCase`
- Include guards: `#ifndef FILENAME_H_`

### Error Handling

- Return safe default values on failure (empty arrays, zero values)
- Log errors to serial output: `ESP_LOGW(TAG, "Error: %s", error_msg)`
- Never expose API keys or credentials in logs

### API Requests (in C++)

- Always set timeouts
- Check HTTP status codes before processing
- Include User-Agent header
- Handle JSON parse errors gracefully

## Secrets Management

- Use `!secret var_name` syntax in YAML to reference secrets
- If a secret is accidentally committed, rotate it immediately

## Configuration Files

### Board Config (transit-board-*.yaml)

- Define substitutions for board-specific values
- Use `esp32` or `esp32-c3` as the platform
- Configure WiFi with fallback AP mode
- Define light components for each LED segment
- Set up HTTP requests for CTA API calls

### Station Map (station_map.h)

- Map station IDs to LED indices
- Define station names and routes
- Order corresponds to physical LED strip layout

### Train Processor (train_processor.h)

- Parse CTA API JSON responses
- Calculate arrival times and routes
- Filter trains by destination station

### Web Server (webserver.css)

- Custom CSS for the ESPHome web server interface
- Styling for the LED control panel

## Development Notes

- Each board (transit-board-a, transit-board-b) has independent config
- Station mapping is board-specific (different LED layouts)
- CTA API key must be obtained from transit agency
- Test API changes against CTA TrainTracker documentation
- When adding new train lines, update route definitions

## Hardware Requirements

- ESP32 or ESP32-C3 microcontroller
- Addressable RGB LED strip (WS2812B/NeoPixel)
- LED count: 58 per board (based on station count)

## API Reference

CTA TrainTracker API: https://www.transitchicago.com/developers/traintracker/
