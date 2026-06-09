# HTML Export Reports

The WebUI can generate two standalone HTML reports from a live authorized ADB device. The export flow is designed as a read-only audit path: it collects public ADB data, formats it, and writes local HTML files.

## Report Types

`share-safe` is intended for public troubleshooting. It redacts or removes:

- Serial-like identifiers.
- MAC/BSSID values.
- LAN IPs.
- SSID/BSSID lines.
- Build fingerprints.
- Session-like identifiers.
- Raw `logcat` output.

`private-full` is intended for local troubleshooting. It can include full serials, Wi-Fi details, Android fingerprints, package lists, raw command appendices, and a short private `logcat` tail. Do not upload it publicly without manual review.

Redaction is best-effort. Always review generated HTML before sharing.

## Report Design

The current report layout is an invoice-style audit sheet:

- White paper surface centered on a gray page background.
- Report number, generation time, privacy stamp, and ADB source in the top-right metadata block.
- Device and collection-policy boxes near the top.
- Summary row for battery, display, storage, and calibration.
- Tables with `Field`, `Value`, and `Evidence Source` columns.
- Explicit factory/calibration inference boundary note.
- Collapsible raw ADB output appendix.
- Print/PDF friendly CSS with no external dependencies.

The design favors readability and evidence traceability over decorative dashboard cards.

## Files Created

Exports are written under the local tool export folder at runtime:

- `Quest3_device_private_full_<timestamp>.html`
- `Quest3_device_share_safe_<timestamp>.html`

The synthetic examples in `examples/` are safe to publish and are not captured from a real headset.

## Read-Only Boundary

The export path uses read-only commands such as `adb devices -l`, `getprop`, `settings list`, `dumpsys`, `pm list`, `df`, and `/proc` reads. It does not call write or state-changing commands such as `settings put`, `settings delete`, `input keyevent`, `am broadcast`, `adb tcpip`, `adb install`, `adb uninstall`, or `adb push`.
