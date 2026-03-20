# Server for Custom Live Transit Tracker



## How to use

 

Use of this add-on requires the following steps before it will do anything.

  

1. Request API key from CTA and add to configuration tab and enter that for the `api_key` value.(Other transit agencies may be added later.)

2. Setup your ESPHome device with attached individual rgb lights to be controlled by this add-on. Then set the `light_board` value on the configuration page to the entity ID of your device. The value should look like: `light.*` where the * is your entity ID without the trailing underscore.

3. Each light needs to be programmed to correlate with the correct stop by updating the `ctastationlist.csv` file to assign the numeric LED to each station name.

  
  

## Configuration Options Explained

The add-on must be restarted to process changes to any of these values.

- `api_key` **User Configuration Required.** A string of characters provided by the transit agency allowing retrieval of live train data. [Apply for a key from the Chicago Transit Authority here.](https://www.transitchicago.com/developers/traintrackerapply/)

- `light_board` **User Configuration Required.** Follow the instructions further in this guide to setup your ESPHome device to work with this add-on. The full entity ID is required. An example would be: *"light.exampleESPdevice"*.

- `trainsPerLine` **Default to `0`.** Set a maximum number of trains to show per line if the light board is too "busy". Setting this value to 0 will display all trains on that line.

- `brightness` **Default to `100`.** Set global LED brightness on a scale from 0 to 100. *Due to the method RGB LEDs use to adjust brightness, setting this value too low may produce inaccurate colors.*

- `data_refresh_interval_sec` **Default to `60`.** Set the interval (in seconds) at which the add-on will refresh data from the transit agency and update the light board. The CTA limits API calls to 100,000/day. Due to how many calls are made to refresh all data, the most frequent refresh interval is 7 seconds. The arbitrary max for this value is 5000 seconds.

- `indiv_light_refresh_delay_milliseconds` **Default to `200`.** Set the interval (in milliseconds) for which the add-on turns on or off individual lights during an update cycle. This option can be used for effect or to help reduce flickering during a refresh on some lights.

- `bidirectional` **Default to `true`.** The data shared by the CTA will assign directionality to each train corresponding with the stop at the end of the line. If you only want to show trains moving in one direction set this to `false`. 

- `red_line_color` **Default to `198, 16, 48`**

- `pink_line_color` **Default to `226, 126, 166`**

- `orange_line_color` **Default to `249, 70, 28`**

 - `yellow_line_color` **Default to `249, 227, 0`**

- `green_line_color` **Default to `0, 155, 58`**

- `blue_line_color` **Default to `0, 161, 222`**

- `purple_line_color` **Default to `82, 35, 152`**

- `brown_line_color` **Default to `8, 54, 27`**

- `assign_stations_program` **Default to `false`.** Not currently used. May be added at later point to assist with the process of assigning each station to an LED.

- `init_commands` **Leave blank**