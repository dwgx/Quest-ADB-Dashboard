# Methods And Inference Limits

This project treats ADB output as evidence, not as a license to guess. The report generator keeps raw command output near the summary fields so users can inspect where a value came from.

## Data Sources

The main data sources are public Android/ADB reads:

- `adb devices -l` for connection and transport hints.
- `getprop` for product, build, Android, SDK, SoC, ABI, and patch fields.
- `settings list` for currently visible global/system/secure values.
- `dumpsys battery`, `power`, `display`, `usb`, `wifi`, `bluetooth_manager`, `thermalservice`, `media.camera`, and `sensorservice`.
- `pm list packages`, `pm list features`, and package dumps for selected apps.
- `df`, `/proc/meminfo`, `/proc/cpuinfo`, and `uname`.

## Quest 3 Focus

The author-tested device class is Meta Quest 3, commonly exposed as `eureka` in Android properties. Firmware updates may add, remove, rename, or hide fields. Other Quest models may work for basic Android inventory, but factory/calibration fields are device and firmware dependent.

## Factory And Calibration Metadata

Some devices expose JSON-like metadata inside `dumpsys sensorservice`. The tool can display fields such as:

- `DeviceType`
- `BuildType`
- `Timestamp`
- `location_id`
- `station_id`
- `station_type`
- `cal_test_id`
- `operator_id`
- `calibration_type`
- Online calibration markers

Some firmware prints this metadata as a JSON string embedded inside another
dump line, so keys may appear escaped as `\"DeviceType\"` rather than plain
`"DeviceType"`. The collector normalizes both forms before extracting summary
fields.

These are internal evidence fields. They are not proven country, city, factory, or production-line names. The report should show the value and label uncertainty instead of translating codes into real-world locations.

## What ADB Cannot Reliably Prove

ADB inventory should not be used alone to claim:

- Exact factory address or country of manufacture.
- Complete device production history.
- Hardware authenticity beyond exposed software/hardware properties.
- Hidden calibration values that the firmware does not expose.
- Account ownership, warranty state, or store purchase source.

## Why There Are Two Reports

The `private-full` report is useful when you own the device and need maximum local evidence. The `share-safe` report is for public support. It removes or masks common privacy-heavy values but still requires manual review.
