# Live Train Tracker Server for CTA

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

---

## HA Add-on (Deprecated)

The `tracker/` folder contains a deprecated Home Assistant add-on. See [tracker/README.md](tracker/README.md) for details.

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fseanalewine%2Fcta-location-tracker)

## About

**This plugin is in active development and not meaningfully usable without modifying the base code and building your own Docker image each time. Installation not currently recomended.**
**About 80% of this project was written with generative AI including Google Gemini Pro 2.5 and Qwen Coder.**

---

Live Train Tracker Server for CTA is a Home Assistant add-on that does the more complex data processing tasks to control a transit tracker light board powered by an ESPHome device. (picture coming soon)
The add-on pulls data using a transit API. **You will need to request your own API key from the transit agency to use this add-on.** The data is then used to control an ESPHome device installed in Home Assistant with individual lights representing transit stops.  Assigning the output LED to represent the correct stop can be done via the `/tracker/files/ctastationlist.csv` file.

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

<!--

Notes to developers after forking or using the github template feature:
- While developing comment out the 'image' key from 'example/config.yaml' to make the supervisor build the addon
  - Remember to put this back when pushing up your changes.
- When you merge to the 'main' branch of your repository a new build will be triggered.
  - Make sure you adjust the 'version' key in 'example/config.yaml' when you do that.
  - Make sure you update 'example/CHANGELOG.md' when you do that.
- The first time this runs you might need to adjust the image configuration on github container registry to make it public
- You may also need to adjust the github Actions configuration (Settings > Actions > General > Workflow > Read & Write)
- Adjust the 'image' key in 'example/config.yaml' so it points to your username instead of 'home-assistant'.
  - This is where the build images will be published to.
- Rename the example directory.
  - The 'slug' key in 'example/config.yaml' should match the directory name.
- Adjust all keys/url's that points to 'home-assistant' to now point to your user/fork.
- Share your repository on the forums https://community.home-assistant.io/c/projects/9
- Do awesome stuff!
 -->

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg
