# ESPHome Controller Setup

Configuration Instructions and Files for setting up an esphome microcontroller with attached light strip/array to wirk with the Home Assistant add-on located in the `tracker` folder.


## Setting up script.yaml

Follow instructions on using [ESPHome Web](https://web.esphome.io/) for installing the script.yaml onto your ESP32 microcontroller of choice. **You will need to modify configuration variables mentioned below for your specific use case.**

### Bottom of the script.yaml file
```
  - platform: esp32_rmt_led_strip
    id: stop_indicators 
    rgb_order: GRB
    pin: GPIO0
    internal: True
    default_transition_length: !secret transition_length
    use_psram: False
    num_leds: 256
    chipset: WS2812
    name: "Stop Indicators"
```

You will need to update the `platform`, `pin`, `chipset`, `rgb_order`, and `num_leds` values to match your specific individually addressable light source. The [ESPHome Documentation](https://esphome.io/components/#light-components) is essential in confirming you have all the required variables for your implementation.

## secrets.yaml
Depending on if you're using locally hosted ESPHome Device Builder or [ESPHome Web](https://web.esphome.io/) the actual process of applying the secrets.yaml file may varry. To build properly all 3 secrets in the example `secrets.yaml` file must be set properly.

## Global Brightness Control
A "Global Brightness" slider (0-100) is available as a `number` entity in Home Assistant under the ESPHome device. This controls the brightness of all partition lights. The addon reads this value during each refresh cycle and applies it when setting LED colors.