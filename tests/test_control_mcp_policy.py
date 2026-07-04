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
fake_types = types.ModuleType("mcp.types")


class FakeFastMCP:
    def __init__(self, *args, **kwargs):
        pass

    def tool(self, *args, **kwargs):
        def decorator(func):
            return func

        return decorator

    def run(self):
        raise AssertionError("Fake MCP server should not run during policy tests")


class FakeImage:
    def __init__(self, *args, **kwargs):
        self.args = args
        self.kwargs = kwargs


class FakeToolAnnotations:
    def __init__(self, **kwargs):
        self.__dict__.update(kwargs)


fake_fastmcp.FastMCP = FakeFastMCP
fake_fastmcp.Image = FakeImage
fake_types.ToolAnnotations = FakeToolAnnotations
sys.modules.setdefault("mcp", fake_mcp)
sys.modules.setdefault("mcp.server", fake_server)
sys.modules.setdefault("mcp.server.fastmcp", fake_fastmcp)
sys.modules.setdefault("mcp.types", fake_types)

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
    def test_parse_ui_nodes_extracts_centers_and_filters(self):
        # uiautomator-style XML -> compact element list with server-computed centers.
        xml = (
            "UI hierarchy dumped to: /dev/tty"
            "<?xml version='1.0' encoding='UTF-8'?>"
            "<hierarchy rotation='0'>"
            "<node text='Wi-Fi' resource-id='com.x:id/wifi' class='android.widget.TextView'"
            " content-desc='' clickable='true' bounds='[100,200][300,260]' />"
            "<node text='' resource-id='' content-desc='' clickable='false' bounds='[0,0][0,0]' />"
            "<node text='' resource-id='' content-desc='Settings icon' clickable='true' bounds='[10,10][50,50]' />"
            "</hierarchy>"
        )
        nodes = module._parse_ui_nodes(xml)
        # the empty zero-size non-clickable node is dropped; two remain
        self.assertEqual(len(nodes), 2)
        wifi = nodes[0]
        self.assertEqual(wifi["text"], "Wi-Fi")
        self.assertEqual(wifi["center"], [200, 230])  # midpoint of [100,200]-[300,260]
        self.assertTrue(wifi["clickable"])
        self.assertEqual(wifi["resource_id"], "wifi")
        self.assertEqual(nodes[1]["desc"], "Settings icon")

    def test_parse_ui_nodes_bad_xml_returns_empty(self):
        self.assertEqual(module._parse_ui_nodes("not xml at all"), [])
        self.assertEqual(module._parse_ui_nodes(""), [])

    def test_tap_element_unknown_id_is_helpful(self):
        module._LAST_OBSERVATION["SERIAL"] = [{"id": 0, "center": [5, 5]}]
        orig = module._select_device
        module._select_device = lambda serial=None: {"ok": True, "device": {"serial": "SERIAL"}}
        try:
            out = module.tap_element(element_id=99, serial="SERIAL", confirm=False)
        finally:
            module._select_device = orig
        self.assertFalse(out.get("ok"))
        self.assertIn("observe_screen", out.get("error", ""))
        self.assertEqual(out.get("available_ids"), [0])

    def test_tap_accepts_display_id_in_preview(self):
        orig = module._select_device
        module._select_device = lambda serial=None: {"ok": True, "device": {"serial": "SERIAL"}}
        try:
            out = module.tap(x=640, y=400, display_id=7, serial="SERIAL", confirm=False)
        finally:
            module._select_device = orig
        # preview must include the -d 7 targeting in the would_run string
        self.assertTrue(out.get("requires_confirmation"))
        self.assertIn("input -d 7 tap 640 400", out.get("would_run", ""))

    def test_state_changing_tools_carry_reversible_annotation(self):
        # Annotations are advisory but should be present and correctly shaped.
        self.assertTrue(getattr(module.READ_ONLY, "readOnlyHint", False))
        self.assertFalse(getattr(module.REVERSIBLE, "readOnlyHint", True))
        self.assertFalse(getattr(module.REVERSIBLE, "destructiveHint", True))

    def test_keyevent_accepts_short_and_full_forms(self):
        # send_keyevent should accept both "HOME" and "KEYCODE_HOME" (the form
        # adb uses and the one LLMs reach for first). Verified live on hardware.
        for key in ["HOME", "KEYCODE_HOME", "keycode_home", "  Home  ", "VOLUME_UP", "KEYCODE_VOLUME_UP"]:
            with self.subTest(key=key):
                out = module.send_keyevent(key=key, serial="SERIAL", confirm=False)
                # preview path: not whitelisted -> ok False with whitelist error
                self.assertNotEqual(out.get("error", ""), f"key not in whitelist: {key}", key)
        # a genuinely non-whitelisted key (e.g. POWER) must still be rejected
        bad = module.send_keyevent(key="KEYCODE_POWER", serial="SERIAL", confirm=False)
        self.assertFalse(bad.get("ok"))
        self.assertIn("whitelist", bad.get("error", ""))

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

    def test_input_text_tool_rejects_bare_percent(self):
        # A literal `%` conflicts with `adb shell input text` %s escaping.
        for bad in ["100%", "%s", "a%b"]:
            with self.subTest(bad=bad):
                out = module.input_text(text=bad, serial="SERIAL", confirm=True)
                self.assertFalse(out.get("ok"), bad)
                self.assertIn("%", out.get("error", ""))

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

    def test_exec_out_metacharacters_are_refused(self):
        # exec-out also runs on the device via sh; a planted screenshot filename
        # like `$(reboot).png` must not slip through the exec-out path.
        for path in [
            "/sdcard/Oculus/Screenshots/$(reboot).png",
            "/sdcard/Oculus/Screenshots/`reboot`.png",
            "/sdcard/x;reboot.png",
        ]:
            with self.subTest(path=path):
                assert_blocked(["-s", "SERIAL", "exec-out", "cat", path])

    def test_exec_out_clean_path_is_allowed(self):
        assert_allowed(["-s", "SERIAL", "exec-out", "cat", "/sdcard/Oculus/Screenshots/IMG_001.png"])

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

    def test_control_policy_matches_enforced_sets(self):
        # The published policy must be derived from the enforced constants so
        # the two cannot silently drift apart.
        policy = module.control_policy()
        self.assertEqual(
            policy["hard_blocked_adb"],
            sorted(module.BLOCKED_ADB_COMMANDS),
        )
        self.assertEqual(
            policy["hard_blocked_shell_prefixes"],
            [" ".join(p) for p in module.BLOCKED_SHELL_PREFIXES],
        )

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
