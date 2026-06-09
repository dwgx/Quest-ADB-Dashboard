# Security Policy

## Supported Versions

The public repository currently supports the latest release only.

## Reporting A Security Issue

Open a GitHub issue with a minimal description, but do not attach private headset reports, tokens, logs, serial numbers, Wi-Fi data, or raw bugreports. If a private exchange is needed, state that in the issue without posting the sensitive material.

## Local-Only Design

The WebUI is intended to bind to `127.0.0.1` only. Do not expose it to a public network. The token in local URLs is a guard against accidental cross-page calls, not a substitute for network isolation.

## Data Handling

`private-full` reports are for local troubleshooting. `share-safe` reports are designed for public sharing but still require manual review before upload.
