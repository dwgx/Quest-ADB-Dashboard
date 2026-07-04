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
- `observe_screen(serial?, include_elements?)` — **read-only perception.** Reports
  the focused window/activity, the display list (Quest renders each 2D panel on
  its own virtual display), and a compact list of interactable elements parsed
  from `uiautomator` with server-computed tap `center`s. Use it before tapping,
  then act with `tap_element(id)`. Falls back to a screenshot hint when no UI
  hierarchy is available (immersive VR / custom-drawn surfaces). No confirm.
- `capture_screenshot(serial?, output_dir?, return_image?, confirm)` — triggers the
  headset's own `com.oculus.metacam` `TAKE_SCREENSHOT` service, waits for the new
  file in `/sdcard/Oculus/Screenshots/`, and pulls it to
  `Quest_ADB_Logs/control-screenshots/`. On `confirm=True` it returns the image
  **inline** (downscaled JPEG, longest edge 1024 px) alongside the full-res
  `local_path`, so the agent can actually see the screen. Set `return_image=False`
  for metadata only. Requires the headset awake/worn.
- `send_keyevent(key, ...)` — whitelisted keys only: HOME, BACK, ENTER,
  DPAD_*, VOLUME_*, MEDIA_*, APP_SWITCH, WAKEUP, SLEEP. Accepts both `HOME` and
  `KEYCODE_HOME` forms.
- `tap(x, y, display_id?, ...)`, `swipe(..., display_id?, ...)` — Android 2D input
  layer. `display_id` targets a specific Quest panel display with display-local
  coordinates (see capability boundary).
- `tap_element(element_id, ...)` — taps the server-computed center of an element
  from the most recent `observe_screen` call, so you never compute pixels.
- `input_text(text, ...)` — types into the focused 2D field.
- `launch_app(package, ...)` — launcher intent via monkey.
- `wake_headset` / `sleep_headset` — display wake/sleep.

All tools carry MCP tool annotations (`readOnlyHint`/`destructiveHint`/
`idempotentHint`/`openWorldHint`) so well-behaved clients can drive confirmation
UX. Annotations are advisory; the real guarantees remain the two-phase confirm,
the hard-block policy, and the metacharacter guards.

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
  controllers are Bluetooth HID, not in `/dev/input`. The only injection paths
  (Meta XR Simulator, IWER) are PC-side OpenXR runtimes, not on-device adb.
- `tap`/`swipe` only affect 2D system surfaces, not immersive VR scenes. On
  Quest each 2D panel renders on its **own virtual display**; a plain tap goes
  to the default display (0), which is the empty composited eye buffer, so it
  appears to do nothing. Target the panel's `display_id` with display-local
  coordinates (`input -d <id> tap x y`), which is what `observe_screen` +
  `tap_element` resolve for you. Verified on hardware: `uiautomator` returns a
  real element hierarchy for 2D panels, `input -d` is the correct targeting,
  and the observe→tap_element→re-observe loop runs end to end.
- Screenshots require the headset awake/worn; an asleep headset yields no image.

## Dependencies

`mcp>=1.9.0` is required. `Pillow` is an optional extra used to downscale the
inline screenshot returned to the agent; without it `capture_screenshot` still
works and returns the full-resolution image inline.

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
