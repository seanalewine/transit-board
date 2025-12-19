# Live Train Tracker Server for CTA

## About

**This plugin is in active development and not meaningfully usable without modifying the base code and building your own Docker image each time. Installation not currently recomended.**

---

Live Train Tracker Server for CTA is a Home Assistant add-on that does the more complex data processing tasks to control a transit tracker light board powered by an ESPHome device. (picture coming soon)
The add-on pulls data using a transit API. **You will need to request your own API key from the transit agency to use this add-on.** and then controls an ESPHome device with individual lights representing transit stops.  Assigning the output LED to represent the correct stop can be set via the `/files/ctastationlist.csv` file.

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
