# Control MCP (state-changing, two-phase confirm)

This project includes a **separate** control MCP server, distinct from the
read-only inventory server:

```text
mcp/quest_adb_control_mcp.py     # control: screenshot, keys, tap, launch, wake/sleep
mcp/quest_adb_safe_mcp.py        # read-only: status, getprop, dumpsys, snapshot
```

The read-only server is unchanged and remains the default for inspection. The
control server is the only place that can change Quest state, and it does so
under a strict two-phase confirmation model.

## Two-phase confirmation

Every state-changing tool takes `confirm` (default `False`):

1. `confirm=False` (preview): returns `requires_confirmation: True`,
   `executed: False`, and `would_run` (the exact adb command). It does **not**
   touch the device.
2. `confirm=True`: actually runs the command.

An agent must show the user `would_run` and wait for approval before passing
`confirm=True`.

## Tools

- `control_policy()` — capability boundary and hard-blocked families (read-only).
- `list_devices()` — online check (read-only).
- `capture_screenshot(serial?, output_dir?, confirm)` — triggers the headset's
  own `com.oculus.metacam` `TAKE_SCREENSHOT` service, waits for the new file in
  `/sdcard/Oculus/Screenshots/`, and pulls it to
  `Quest_ADB_Logs/control-screenshots/`. Requires the headset awake/worn.
- `send_keyevent(key, ...)` — whitelisted keys only: HOME, BACK, ENTER,
  DPAD_*, VOLUME_*, MEDIA_*, APP_SWITCH, WAKEUP, SLEEP.
- `tap`, `swipe`, `input_text` — Android 2D input layer (system panels only).
- `launch_app(package, ...)` — launcher intent via monkey.
- `wake_headset` / `sleep_headset` — display wake/sleep.

## Hard limits (enforced even with confirm=True)

No tool exposes, and the server refuses, these families:

- `install`, `uninstall`, `push`, `pull`, `reboot`, `tcpip`, `usb`, `root`,
  `remount`, `sideload`, `bugreport`
- `pm clear/disable/disable-user/enable/hide/install/suspend/uninstall`
- filesystem mutation (`rm/mv/cp/dd/mkfs/format/wipe`), `reboot`/`recovery`,
  `svc power reboot`, `setprop sys.powerctl`, and critical provisioning
  settings keys (`device_provisioned`, `user_setup_complete`).

## Capability boundary

- adb **cannot** emulate the Quest's 6DoF VR controllers (laser + trigger);
  controllers are Bluetooth HID, not in `/dev/input`.
- Coordinate `tap`/`swipe` only affect 2D system surfaces, not VR scenes.
- Screenshots require the headset awake/worn; an asleep headset yields no image.

## MCP client configuration

Use the same project venv as the read-only server. Add to
`%USERPROFILE%\.codex\config.toml` (or a Claude MCP config) and start a new
session:

```toml
[mcp_servers.quest-adb-control]
command = "<repo>\\.venv-mcp\\Scripts\\python.exe"
args = ["<repo>\\mcp\\quest_adb_control_mcp.py"]
enabled = true
```

The agent-facing workflow and trigger phrases live in the `quest-control`
skill (`~/.claude/skills/quest-control/SKILL.md`).

## Tests

Offline policy tests (no headset needed):

```powershell
python -m unittest tests.test_control_mcp_policy
```

They assert that irreversible families are hard-blocked (even with `-s SERIAL`),
that destructive shell commands are refused, and that preview mode never runs
adb.
