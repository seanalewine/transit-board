# Server for Custom Live Transit Tracker

---

## How to Use

Use of this add-on requires the following steps before it will do anything.

1. **Request API key** from CTA and add to the configuration tab as the `api_key` value. [Apply for a key here.](https://www.transitchicago.com/developers/traintrackerapply/)

2. **Setup your ESPHome device** with attached individual RGB lights to be controlled by this add-on. Set the `light_board` value to your ESPHome device name (without the `light.` prefix). For example, if your light entity is `light.trainboard`, enter `trainboard`. **Brightness is controlled via a "Global Brightness" number entity in Home Assistant, auto-named as `number.{light_board}_global_brightness` (e.g., `number.trainboard_global_brightness`).**

3. **Map stations to LEDs** by editing the `ctastationlist.csv` file to assign each station's `unifiedId` (LED number) to the correct station name. Each light on your board should be numbered and matched to a station.

---

## Configuration Options

The add-on must be restarted to process changes to any of these values.

| Option | Required | Default | Description |
|--------|:--------:|:-------:|-------------|
| `api_key` | Yes | - | CTA TrainTracker API key. [Apply here.](https://www.transitchicago.com/developers/traintrackerapply/) |
| `light_board` | Yes | - | ESPHome device name (without `light.` prefix). E.g., `trainboard` for `light.trainboard` |
| `trainsPerLine` | No | 0 | Maximum trains to show per line. Set 0 to display all trains. |
| `data_refresh_interval_sec` | No | 60 | How often to refresh data (seconds). Minimum 7, maximum 5000. |
| `bidirectional` | No | true | Show trains in both directions. Set `false` for only one direction. |
| `red_line_color` | No | 198, 12, 48 | RGB color for red line trains |
| `pink_line_color` | No | 226, 126, 166 | RGB color for pink line trains |
| `orange_line_color` | No | 255, 146, 25 | RGB color for orange line trains |
| `yellow_line_color` | No | 249, 227, 0 | RGB color for yellow line trains |
| `green_line_color` | No | 0, 155, 58 | RGB color for green line trains |
| `blue_line_color` | No | 0, 161, 222 | RGB color for blue line trains |
| `purple_line_color` | No | 82, 35, 152 | RGB color for purple line trains |
| `brown_line_color` | No | 150, 75, 0 | RGB color for brown line trains |
| `init_commands` | No | `[]` | Reserved for future use. Leave empty. |

---
