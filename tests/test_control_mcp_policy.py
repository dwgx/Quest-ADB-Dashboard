import importlib.util
import sys
import types
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "mcp" / "quest_adb_control_mcp.py"

fake_mcp = types.ModuleType("mcp")
fake_server = types.ModuleType("mcp.server")
fake_fastmcp = types.ModuleType("mcp.server.fastmcp")


class FakeFastMCP:
    def __init__(self, *args, **kwargs):
        pass

    def tool(self):
        def decorator(func):
            return func

        return decorator

    def run(self):
        raise AssertionError("Fake MCP server should not run during policy tests")


fake_fastmcp.FastMCP = FakeFastMCP
sys.modules.setdefault("mcp", fake_mcp)
sys.modules.setdefault("mcp.server", fake_server)
sys.modules.setdefault("mcp.server.fastmcp", fake_fastmcp)

spec = importlib.util.spec_from_file_location("quest_adb_control_mcp", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


def assert_blocked(args):
    try:
        module._refuse_if_hard_blocked(["adb.exe"] + args)
    except ValueError:
        return
    raise AssertionError(f"command was not hard-blocked: {args}")


def assert_allowed(args):
    module._refuse_if_hard_blocked(["adb.exe"] + args)


class ControlMcpPolicyTests(unittest.TestCase):
    def test_irreversible_adb_commands_are_blocked_even_with_serial(self):
        for args in [
            ["install", "app.apk"],
            ["-s", "SERIAL", "install", "app.apk"],
            ["uninstall", "com.example.app"],
            ["push", "a", "/sdcard/a"],
            ["pull", "/sdcard/a", "a"],
            ["-s", "SERIAL", "reboot"],
            ["tcpip", "5555"],
            ["usb"],
            ["root"],
            ["remount"],
            ["bugreport"],
            ["backup", "-all"],
            ["restore", "backup.ab"],
            ["disable-verity"],
        ]:
            with self.subTest(args=args):
                assert_blocked(args)

    def test_shell_injection_metacharacters_are_refused(self):
        # The input_text bypass class: chaining/substitution through device sh.
        # adb shell receives the whole payload as one trailing arg token.
        for payload in [
            "x;reboot",
            "$(reboot)",
            "x&&rm",
            "x|sh",
            "x`reboot`",
            "x>/sdcard/clobber",
            "x${IFS}reboot",
        ]:
            with self.subTest(payload=payload):
                assert_blocked(["-s", "SERIAL", "shell", "input", "text", payload])

    def test_input_text_tool_rejects_metacharacters(self):
        # The tool-level guard returns an error (not an exception) before adb.
        for bad in ["x;reboot", "$(reboot)", "a|b", "a&b", "a`b`", "a>b", "a${IFS}b"]:
            with self.subTest(bad=bad):
                out = module.input_text(text=bad, serial="SERIAL", confirm=True)
                self.assertFalse(out.get("ok"), bad)
                self.assertIn("metacharacter", out.get("error", ""))

    def test_string_false_does_not_confirm(self):
        # bool("false") is True in Python; the strict gate must treat it as preview.
        self.assertFalse(module._is_confirmed("false"))
        self.assertFalse(module._is_confirmed("False"))
        self.assertFalse(module._is_confirmed("0"))
        self.assertFalse(module._is_confirmed(""))
        self.assertFalse(module._is_confirmed(None))
        self.assertFalse(module._is_confirmed("maybe"))
        self.assertTrue(module._is_confirmed(True))
        self.assertTrue(module._is_confirmed("true"))
        self.assertTrue(module._is_confirmed("YES"))
        self.assertFalse(module._is_confirmed(False))

    def test_cmd_alias_destructive_forms_are_blocked(self):
        for command in [
            "cmd package uninstall com.example.app",
            "cmd package clear com.example.app",
            "cmd settings put global device_provisioned 0",
            "cmd settings delete secure x",
        ]:
            with self.subTest(command=command):
                assert_blocked(["-s", "SERIAL", "shell", command])

    def test_service_and_power_destruction_are_blocked(self):
        for command in [
            "svc power shutdown",
            "svc bluetooth disable",
            "svc wifi disable",
            "stop",
            "start",
            "setprop ctl.stop zygote",
            "am force-stop com.example.app",
            "am kill-all",
            "killall zygote",
            "am broadcast -a android.intent.action.MASTER_CLEAR",
        ]:
            with self.subTest(command=command):
                assert_blocked(["-s", "SERIAL", "shell", command])

    def test_destructive_shell_commands_are_blocked(self):
        for command in [
            "pm clear com.example.app",
            "pm disable-user com.example.app",
            "pm uninstall com.example.app",
            "rm /sdcard/file",
            "reboot",
            "svc power reboot",
            "settings put global device_provisioned 0",
            "setprop sys.powerctl reboot",
        ]:
            with self.subTest(command=command):
                assert_blocked(["-s", "SERIAL", "shell", command])

    def test_allowed_control_shell_commands_pass_hard_block(self):
        for command in [
            "input keyevent KEYCODE_HOME",
            "input tap 100 200",
            "input swipe 0 0 100 100 300",
            "input text hello",
            "am startservice -n com.oculus.metacam/.capture.CaptureService -a TAKE_SCREENSHOT",
            "monkey -p com.oculus.browser -c android.intent.category.LAUNCHER 1",
            "dumpsys power",
        ]:
            with self.subTest(command=command):
                assert_allowed(["-s", "SERIAL", "shell", command])

    def test_keyevent_whitelist_rejects_unknown_keys(self):
        # unknown key is rejected before any device selection runs
        result = module.send_keyevent("KEYCODE_POWER", serial="SERIAL", confirm=False)
        self.assertFalse(result.get("ok"))
        self.assertIn("whitelist", result.get("error", ""))

    def test_preview_mode_never_executes(self):
        # Stub device selection so the test is offline/deterministic (no real adb).
        fake_device = {"serial": "FAKESERIAL", "model": "Quest_3", "state": "device"}
        original = module._select_device
        module._select_device = lambda serial=None: {"ok": True, "device": fake_device, "devices": [fake_device]}
        # Also stub _run_adb so a bug that executes anyway is caught loudly.
        module._run_adb = lambda *a, **k: (_ for _ in ()).throw(AssertionError("preview mode must not run adb"))
        try:
            for fn, args in [
                (module.send_keyevent, dict(key="HOME", serial="FAKESERIAL")),
                (module.tap, dict(x=10, y=10, serial="FAKESERIAL")),
                (module.swipe, dict(x1=0, y1=0, x2=5, y2=5, serial="FAKESERIAL")),
                (module.input_text, dict(text="hi", serial="FAKESERIAL")),
                (module.launch_app, dict(package="com.oculus.browser", serial="FAKESERIAL")),
                (module.wake_headset, dict(serial="FAKESERIAL")),
                (module.sleep_headset, dict(serial="FAKESERIAL")),
            ]:
                with self.subTest(fn=fn.__name__):
                    out = fn(**args, confirm=False)
                    self.assertTrue(out.get("requires_confirmation"), fn.__name__)
                    self.assertFalse(out.get("executed"), fn.__name__)
                    self.assertIn("would_run", out)
        finally:
            module._select_device = original


if __name__ == "__main__":
    unittest.main()
