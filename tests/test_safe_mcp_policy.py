import importlib.util
import sys
import types
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "mcp" / "quest_adb_safe_mcp.py"

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

spec = importlib.util.spec_from_file_location("quest_adb_safe_mcp", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


def assert_refused(args):
    try:
        module._refuse_if_dangerous(["adb.exe"] + args)
    except ValueError:
        return
    raise AssertionError(f"command was not refused: {args}")


def assert_allowed(args):
    module._refuse_if_dangerous(["adb.exe"] + args)


class SafeMcpPolicyTests(unittest.TestCase):
    def test_state_changing_adb_commands_are_refused(self):
        for args in [
            ["install", "app.apk"],
            ["-s", "SERIAL", "install", "app.apk"],
            ["uninstall", "com.example.app"],
            ["-s", "SERIAL", "uninstall", "com.example.app"],
            ["push", "a", "/sdcard/a"],
            ["-s", "SERIAL", "push", "a", "/sdcard/a"],
            ["pull", "/sdcard/a", "a"],
            ["reboot"],
            ["tcpip", "5555"],
            ["-s", "SERIAL", "tcpip", "5555"],
            ["usb"],
            ["-s", "SERIAL", "usb"],
            ["root"],
            ["remount"],
        ]:
            with self.subTest(args=args):
                assert_refused(args)

    def test_state_changing_shell_commands_are_refused(self):
        for command in [
            "settings put system screen_off_timeout 300000",
            "settings delete secure sleep_timeout",
            "input keyevent KEYCODE_SLEEP",
            "am broadcast -a com.oculus.vrpowermanager.prox_open",
            "pm clear com.example.app",
            "pm disable-user com.example.app",
            "cmd activity start-activity anything",
            "logcat -c",
            "rm /sdcard/file",
        ]:
            with self.subTest(command=command):
                assert_refused(["-s", "SERIAL", "shell", command])

    def test_read_only_commands_are_allowed(self):
        for command in [
            "dumpsys usb",
            "dumpsys battery",
            "settings list global",
            "pm list packages -f -i",
            "cmd package list libraries",
            "logcat -d -t 3000",
            "cat /proc/meminfo",
            "ip addr",
        ]:
            with self.subTest(command=command):
                assert_allowed(["-s", "SERIAL", "shell", command])


if __name__ == "__main__":
    unittest.main()
