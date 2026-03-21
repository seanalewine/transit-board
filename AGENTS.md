# Agent Coding Guidelines

This document provides instructions for agents working on the CTA Location Tracker codebase.

## Project Overview

This is a Home Assistant add-on that fetches live CTA train data and controls an ESPHome-powered LED light board. The project consists of:

- **`tracker/`** - Home Assistant add-on (Python + Bash)
- **`esphome-controller/`** - ESPHome device configuration (YAML)

## Build/Lint/Test Commands

### Home Assistant Add-on Linting

```bash
# Install the add-on linter (requires Docker)
docker run --rm -v "$(pwd):/data" ghcr.io/home-assistant/amd64-base-debian:trixie \
  python3 -m pip install home-assistant-addon-linter

# Run linter on the tracker add-on
docker run --rm -v "$(pwd)/tracker:/data" \
  ghcr.io/frenck/action-addon-linter:latest /data
```

### Docker Build (for testing locally)

```bash
# Build the tracker add-on for amd64
docker build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:trixie \
  -t cta-tracker:test tracker/

# Build for aarch64
docker build --build-arg BUILD_FROM=ghcr.io/home-assistant/aarch64-base-debian:trixie \
  -t cta-tracker:test-aarch64 tracker/
```

### Python Code Quality

```bash
# Install dependencies
pip install -r tracker/requirements.txt

# Run Python syntax check
python3 -m py_compile tracker/files/processor.py
python3 -m py_compile tracker/files/graphicrefresh.py

# Check Python style (if black is installed)
black --check tracker/files/*.py

# Format Python code
black tracker/files/*.py
```

### GitHub Actions CI

The repository has two workflows:
- **`lint.yaml`** - Runs add-on linter on push/PR to main
- **`builder.yaml`** - Builds Docker images for aarch64/amd64 on main branch pushes

Monitored files for build trigger: `build.yaml`, `config.yaml`, `Dockerfile`, `rootfs`

## Code Style Guidelines

### Python

- **Formatting**: Use standard PEP 8 style. 4-space indentation.
- **Imports**: Standard library first, then third-party (requests, pandas, numpy, dateutil).
- **String formatting**: Use f-strings for readability.
- **Type hints**: Not currently used, but adding them is encouraged for new functions.
- **Line length**: Target 100 characters max, 120 absolute max.

### Error Handling

- Use try/except blocks for external calls (API requests, file I/O).
- Print errors to stderr: `print(f"Error: {e}", file=sys.stderr)`.
- Never expose sensitive information (API keys, tokens) in error messages.
- Always return safe default values (empty DataFrame, empty dict) on failure.

### Naming Conventions

- **Functions**: `snake_case` (e.g., `fetch_route_data`, `get_on_lights`)
- **Variables**: `snake_case` (e.g., `api_key`, `stationlist`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `COLORS`, `ROUTE_IDS`)
- **Classes**: `PascalCase` (not currently used)

### Logging

- Use `print()` with `file=sys.stderr` for logging (to stdout for data pipeline).
- Prefix errors with `ERROR:` or `WARNING:` for easy grep filtering.
- Include relevant context: station IDs, route IDs, error types.

### Environment Variables

- Use `os.environ.get("VAR_NAME", default)` pattern.
- Provide sensible defaults where possible.
- Document required vs optional variables in comments.

### Data Handling

- Use pandas DataFrames for structured train data.
- Filter invalid data explicitly before processing.
- Use `.get()` for dict access to prevent KeyError.
- Convert types explicitly: `df['col'].astype(str).str.strip()`

### API Requests

- Always set timeouts: `requests.get(url, timeout=3)`.
- Check `response.status_code` before processing.
- Include User-Agent header for HTTP requests.

### Bash Scripts

- Use `#!/usr/bin/with-contenv bashio` for Home Assistant addon environment.
- Use `set -o pipefail` to catch pipe failures.
- Use `bashio::config` for reading addon configuration.
- Quote all variable expansions: `"$VAR"` not `$VAR`.

## Configuration Files

### config.yaml (Home Assistant Add-on)

- Follow Home Assistant add-on schema format.
- Define all options with types and defaults.
- Use schema validation for user inputs.
- Document required vs optional options.

### ESPHome script.yaml

- Follow ESPHome v2025.9.0+ syntax.
- Use secrets for sensitive values (wifi, transitions).
- Partition lights for individual control.
- Document hardware-specific settings (chipset, pin, num_leds).

## File Locations

| File | Purpose |
|------|---------|
| `tracker/run.sh` | Main entry point, reads config, runs data loop |
| `tracker/files/processor.py` | Fetches CTA API data, outputs JSON to stdout |
| `tracker/files/graphicrefresh.py` | Reads JSON, controls Home Assistant lights |
| `tracker/files/ctastationlist.csv` | Maps station IDs to LED numbers |
| `esphome-controller/script.yaml` | ESP32 device configuration |
| `esphome-controller/secrets.yaml` | Device secrets (gitignored) |

## Development Notes

- The pipeline is: `run.sh` -> `processor.py` (stdout) -> `graphicrefresh.py`
- Both Python scripts receive config via environment variables.
- The addon runs in a Docker container with Home Assistant API access.
- Test API changes against the CTA TrainTracker API documentation.
- When adding new train lines, update `ROUTE_IDS` and `COLORS` in processor.py.
