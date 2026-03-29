# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Web interface styling via `webserver.css` template
- Support for firmware updates via web page

### Changed
- GitHub Actions workflow now skips builds when `project_version` hasn't changed
- Added version checking job to CI pipeline

## [1.3.0] - 2025-03-24

### Added
- Station map template (`station_map.h`) for LED station mapping
- Train processor template (`train_processor.h`) for CTA API response parsing

### Changed
- Refactored ESPHome configuration into templates for better reusability

## [1.2.0] - 2025-03-23

### Changed
- Combined READMEs and added update modes documentation
- Disabled auto-update, switched to manual firmware deployment only

## [1.1.2] - 2025-03-22

### Fixed
- Path corrections in build configuration

## [1.1.1] - 2025-03-21

### Changed
- Codebase cleanup and improved builder rules

### Removed
- Deprecated Home Assistant addon (archived in v1.0.9)

## [1.1.0] - 2025-03-XX

### Changed
- Removed secrets.yaml dependency
- Improved ESPHome build workflow

## [1.0.9] - 2025-03-XX

### Removed
- Deprecated HA addon


