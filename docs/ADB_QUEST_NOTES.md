# ADB And Quest Notes

## ADB Basics

ADB is Android Debug Bridge. On Quest headsets it becomes available after:

- Developer Mode is enabled for the Meta account/device.
- USB debugging is authorized inside the headset.
- Windows can see a working USB data connection and an `adb.exe` is available.

Typical connection states:

- `device`: online and authorized.
- `unauthorized`: USB debugging prompt still needs approval in the headset.
- `offline`: stale transport or USB/driver instability.
- no device: cable, driver, developer mode, or authorization is missing.

## Quest 3 Reference Device

The author-tested headset is **Meta Quest 3**, product/device family commonly exposed as `eureka` in Android properties. The observed Quest 3 class can expose:

- Android 14 / SDK 34 on recent firmware.
- Oculus/Meta product properties.
- Qualcomm XR SoC properties.
- Display, battery, thermal, USB, Wi-Fi, Bluetooth, camera, and sensor data through normal ADB reads.
- Factory and online calibration metadata inside `dumpsys sensorservice` on some firmware.

These are observations from one Quest 3 class of device. Firmware updates can change exposed fields.

## Factory / Calibration Metadata

Some Quest 3 devices expose JSON-like calibration data through `dumpsys sensorservice`. This can include:

- `DeviceType`
- `BuildType`
- `FileFormat.Timestamp`
- `Source=Factory`
- `Source=Online`
- `location_id`
- `station_id`
- `station_type`
- IMU and camera calibration fields

Important boundary: internal station/location codes are not public factory addresses. This project displays the evidence and labels uncertainty instead of translating codes into country, city, or factory claims.

## Read-Only Commands Used For Export

The HTML export path is built from read-only commands. Representative examples:

```bat
adb devices -l
adb shell getprop
adb shell settings list global
adb shell settings list system
adb shell settings list secure
adb shell dumpsys battery
adb shell dumpsys power
adb shell dumpsys display
adb shell dumpsys sensorservice
adb shell dumpsys thermalservice
adb shell pm list packages -f -i
adb shell pm list features
```

The private report may include a short `logcat -d -t 3000` tail. The share-safe report omits or redacts privacy-heavy values.

## Commands To Treat As Write / State-Changing

These are not part of the read-only export flow:

- `settings put`
- `settings delete`
- `input keyevent`
- `am broadcast`
- `adb tcpip`
- `adb usb`
- `adb reboot`
- `adb install`
- `adb uninstall`
- `adb push`
- `pm clear`
- `pm disable`
- `pm enable`

The tool contains some interactive convenience actions that use a few of these, but they are separate from export.
