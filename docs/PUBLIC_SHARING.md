# Public Sharing Guide

Use this guide before attaching report files, screenshots, or command output to GitHub issues, forums, Discord, or support posts.

## Safe Default

Share the `share-safe` HTML report only. Review it manually before upload.

The public example `examples/sample_quest3_share_safe.html` is synthetic and demonstrates the intended layout.

## Do Not Share

Avoid publishing:

- `private-full` reports from a real headset.
- Real serial numbers.
- LAN IP addresses, private Wi-Fi names, BSSID/MAC values.
- Android build fingerprints tied to a personal device.
- `logcat`, full bugreports, package dumps, or raw `dumpsys` blobs unless reviewed.
- Account, token, login, app-private, file-path, or local machine data.

## Good GitHub Issue Format

When reporting a problem, include:

- Windows version.
- Quest model and firmware version if visible.
- Whether USB debugging is authorized.
- Which ADB executable is used.
- A short description of what button or menu item was used.
- The synthetic-safe or manually reviewed `share-safe` report if relevant.

Do not attach private-full reports unless a maintainer explicitly asks and you have reviewed the file.

## Screenshots

Screenshots are safer when they come from the `share-safe` report. Check the browser address bar and page contents before sharing, because private local paths or generated filenames can still reveal context.
