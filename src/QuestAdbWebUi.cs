using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

class QuestAdbWebUi
{
    static string AdbPath = "adb.exe";
    static string Token = Guid.NewGuid().ToString("N");
    static int Port = 8765;
    static string RootDir = "";
    static string LogDir = "";
    static string LogFile = "";
    static readonly object LogLock = new object();
    static readonly Encoding Utf8NoBom = new UTF8Encoding(false);

    class CmdResult
    {
        public string Output = "";
        public string Error = "";
        public int ExitCode = -1;
        public bool TimedOut = false;
        public string Text { get { return Output.Length > 0 ? Output : Error; } }
    }

    class Capture
    {
        public string Name = "";
        public string Command = "";
        public string Output = "";
        public string Error = "";
        public int ExitCode = -1;
        public bool TimedOut = false;
        public long DurationMs = 0;
        public string Text { get { return Output.Length > 0 ? Output : Error; } }
    }

    class Snapshot
    {
        public string Created = "";
        public string Serial = "";
        public string DeviceLine = "";
        public Dictionary<string, string> Fields = new Dictionary<string, string>();
        public List<Capture> Captures = new List<Capture>();
        public List<string> Warnings = new List<string>();
    }

    static void Main(string[] args)
    {
        try { Console.OutputEncoding = Encoding.UTF8; } catch { }
        if (args.Length > 0 && args[0] == "--self-test") { Environment.Exit(SelfTest()); return; }
        if (args.Length > 0) AdbPath = args[0];
        InitLog(args.Length > 1 ? args[1] : AppDomain.CurrentDomain.BaseDirectory);

        TcpListener listener = null;
        for (int p = 8765; p <= 8785; p++)
        {
            try { listener = new TcpListener(IPAddress.Parse("127.0.0.1"), p); listener.Start(); Port = p; break; }
            catch { listener = null; }
        }
        if (listener == null) { Console.WriteLine("Quest ADB WebUI 启动失败：8765-8785 端口都不可用。"); Log("启动失败：8765-8785 端口都不可用。"); Console.ReadKey(); return; }

        string url = "http://127.0.0.1:" + Port + "/?token=" + Token;
        Console.WriteLine("Quest ADB WebUI 服务已启动：" + url);
        Console.WriteLine("只监听 127.0.0.1；关闭本窗口后 WebUI 停止。");
        Console.WriteLine("ADB: " + AdbPath);
        Console.WriteLine("日志: " + LogFile);
        Log("服务启动：http://127.0.0.1:" + Port + "/");
        Log("ADB: " + AdbPath);
        try { string initialLine, initialHint; Log("初始连接状态：" + SelectDevice(out initialLine, out initialHint) + " " + Clean(initialLine) + " " + initialHint); } catch { }
        if (!"1".Equals(Environment.GetEnvironmentVariable("QUEST_ADB_WEBUI_NO_BROWSER"), StringComparison.OrdinalIgnoreCase))
        {
            try { Process.Start(url); } catch { }
        }

        while (true)
        {
            try
            {
                TcpClient c = listener.AcceptTcpClient();
                ThreadPool.QueueUserWorkItem(delegate(object o)
                {
                    try { Serve((TcpClient)o); }
                    catch (Exception ex)
                    {
                        try { ((TcpClient)o).Close(); } catch { }
                        Log("请求线程异常：" + ex.Message);
                    }
                }, c);
            }
            catch (Exception ex) { Console.WriteLine("请求处理失败：" + ex.Message); Log("请求处理失败：" + ex.Message); }
        }
    }

    static int SelfTest()
    {
        List<string> failures = new List<string>();
        string sensor = "{\\\"Device\\\":{\\\"BuildType\\\":\\\"PVT1.1\\\",\\\"DeviceType\\\":\\\"Eureka\\\"},\\\"FileFormat\\\":{\\\"Timestamp\\\":\\\"2025-11-15T08:15:45\\\"},\\\"Metadata\\\":{\\\"NamedTags\\\":{\\\"location_id\\\":\\\"gtk\\\",\\\"station_id\\\":\\\"wf-eureka-iot-2up-41\\\",\\\"calibration_type\\\":\\\"IOT\\\"}}}";
        Expect(failures, "DeviceType", "Eureka", ExtractJsonish(sensor, "DeviceType"));
        Expect(failures, "BuildType", "PVT1.1", ExtractJsonish(sensor, "BuildType"));
        Expect(failures, "Timestamp", "2025-11-15T08:15:45", ExtractJsonish(sensor, "Timestamp"));
        Expect(failures, "location_id", "gtk", ExtractJsonish(sensor, "location_id"));
        Expect(failures, "station_id", "wf-eureka-iot-2up-41", ExtractJsonish(sensor, "station_id"));
        ExpectContains(failures, "FactorySummary", FactorySummary(sensor), "Eureka", "PVT1.1", "loc gtk", "station wf-eureka-iot-2up-41");

        string cameras = "{\\\"SensorType\\\":\\\"OG01A\\\"}{\\\"SensorType\\\":\\\"OV7251\\\"}{\\\"SensorType\\\":\\\"IMX471\\\"}";
        ExpectContains(failures, "CameraSummary", CameraSummary("", cameras), "OG01A 1", "OV7251 1", "IMX471 1");

        if (failures.Count == 0) { Console.WriteLine("QuestAdbWebUi self-test PASS"); return 0; }
        foreach (string failure in failures) Console.Error.WriteLine(failure);
        return 1;
    }

    static void Expect(List<string> failures, string name, string expected, string actual)
    {
        if (actual != expected) failures.Add(name + ": expected [" + expected + "] but got [" + actual + "]");
    }

    static void ExpectContains(List<string> failures, string name, string actual, params string[] needles)
    {
        foreach (string needle in needles)
        {
            if ((actual ?? "").IndexOf(needle, StringComparison.OrdinalIgnoreCase) < 0) failures.Add(name + ": missing [" + needle + "] in [" + Clean(actual) + "]");
        }
    }

    static void Serve(TcpClient client)
    {
        using (client)
        {
            client.ReceiveTimeout = 10000;
            client.SendTimeout = 10000;
            Stream stream = client.GetStream();
            StreamReader reader = new StreamReader(stream, Encoding.UTF8);
            string first = reader.ReadLine();
            if (string.IsNullOrEmpty(first)) return;
            string[] parts = first.Split(' ');
            if (parts.Length < 2) return;
            string method = parts[0].ToUpperInvariant();
            string target = parts[1];
            string line;
            do { line = reader.ReadLine(); } while (!string.IsNullOrEmpty(line));

            Uri uri = new Uri("http://127.0.0.1:" + Port + target);
            if (uri.AbsolutePath == "/api/status")
            {
                if (!CheckToken(uri.Query)) { WriteJson(stream, Error("token 无效")); return; }
                WriteJson(stream, Status());
                return;
            }
            if (uri.AbsolutePath == "/api/action")
            {
                if (!CheckToken(uri.Query)) { WriteJson(stream, Error("token 无效")); return; }
                if (method != "POST") { WriteJson(stream, Error("修改操作必须使用 POST 请求。")); return; }
                string action = Query(uri.Query, "action");
                if (DangerousAction(action) && Query(uri.Query, "confirm") != "YES")
                {
                    WriteJson(stream, Error("危险操作需要二次确认。"));
                    return;
                }
                WriteJson(stream, Action(action, uri.Query));
                return;
            }
            if (uri.AbsolutePath == "/api/logs")
            {
                if (!CheckToken(uri.Query)) { WriteJson(stream, Error("token 无效")); return; }
                WriteJson(stream, Logs());
                return;
            }
            if (uri.AbsolutePath == "/api/export")
            {
                if (!CheckToken(uri.Query)) { WriteJson(stream, Error("token 无效")); return; }
                if (method != "POST") { WriteJson(stream, Error("导出必须使用 POST 请求。")); return; }
                WriteJson(stream, ExportReport());
                return;
            }
            if (uri.AbsolutePath.StartsWith("/exports/", StringComparison.OrdinalIgnoreCase))
            {
                if (!CheckToken(uri.Query)) { WriteBytes(stream, "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("token 无效")); return; }
                ServeExport(stream, uri.AbsolutePath);
                return;
            }
            if (uri.AbsolutePath == "/favicon.ico")
            {
                WriteBytes(stream, "image/svg+xml", Encoding.UTF8.GetBytes("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='#2563eb' stroke-width='2'><path d='M6 9h12a3 3 0 0 1 3 3v3a3 3 0 0 1-3 3h-1.5l-2.5-3h-4l-2.5 3H6a3 3 0 0 1-3-3v-3a3 3 0 0 1 3-3z'/></svg>"));
                return;
            }
            WriteBytes(stream, "text/html; charset=utf-8", Encoding.UTF8.GetBytes(Html()));
        }
    }

    static Dictionary<string, string> Status()
    {
        Dictionary<string, string> d = Ok();
        d["service"] = "127.0.0.1:" + Port;
        d["adbPath"] = AdbPath;
        d["logFile"] = LogFile;

        string deviceLine, hint;
        string state = SelectDevice(out deviceLine, out hint);
        d["deviceState"] = state;
        d["deviceLine"] = Clean(deviceLine);
        d["hint"] = hint;
        d["connected"] = state == "device" ? "true" : "false";
        if (state != "device") { Log("状态读取：" + state + " " + Clean(deviceLine) + " " + hint); return d; }

        string serial = deviceLine.Split(' ')[0];
        d["serial"] = serial;
        d["model"] = Prop(serial, "ro.product.model");
        d["android"] = Prop(serial, "ro.build.version.release");
        d["sdk"] = Prop(serial, "ro.build.version.sdk");
        d["securityPatch"] = Prop(serial, "ro.build.version.security_patch");
        d["manufacturer"] = Prop(serial, "ro.product.manufacturer");
        d["brand"] = Prop(serial, "ro.product.brand");
        d["productName"] = Prop(serial, "ro.product.name");
        d["productDevice"] = Prop(serial, "ro.product.device");
        d["board"] = Prop(serial, "ro.product.board");
        d["soc"] = JoinNonEmpty(Prop(serial, "ro.soc.manufacturer"), Prop(serial, "ro.soc.model"));
        d["buildId"] = Prop(serial, "ro.build.display.id");
        d["buildBranch"] = Prop(serial, "ro.build.branch");
        d["buildIncremental"] = Prop(serial, "ro.build.version.incremental");
        d["vendorPatch"] = Prop(serial, "ro.vendor.build.security_patch");
        d["abi"] = Prop(serial, "ro.product.cpu.abi");
        d["wifiIp"] = WifiIp(serial);
        d["adbEnabled"] = Setting(serial, "global", "adb_enabled");
        d["adbWifi"] = Setting(serial, "global", "adb_wifi_enabled");
        d["stayOn"] = Setting(serial, "global", "stay_on_while_plugged_in");
        d["wifiSleep"] = Setting(serial, "global", "wifi_sleep_policy");
        d["screenOff"] = Setting(serial, "system", "screen_off_timeout");
        d["sleepTimeout"] = Setting(serial, "secure", "sleep_timeout");
        d["lowPower"] = Setting(serial, "global", "low_power");
        FillBattery(d, serial);
        FillPower(d, serial);
        FillControllersFast(d, serial);
        FillResources(d, serial);
        FillVirtualDesktop(d, serial);
        FillDisplayLite(d, serial);
        FillThermalLite(d, serial);
        FillFactoryLite(d, serial);
        Log("状态读取：device " + d["model"] + " battery=" + d["batteryLevel"] + "% temp=" + d["batteryTemp"] + "C wake=" + d["wakefulness"] + " stayOn=" + d["stayOn"] + " adbWifi=" + d["adbWifi"]);
        return d;
    }

    static Dictionary<string, string> Action(string action, string query)
    {
        Dictionary<string, string> d = Ok();
        d["action"] = Clean(action);
        string serial = CurrentSerial();
        Log("操作开始：" + Clean(action) + " serial=" + serial);
        try
        {
            if (action == "restart_adb") { MustA(4000, "kill-server"); Thread.Sleep(350); MustA(4000, "start-server"); d["result"] = "已重启电脑端 ADB 服务。"; }
            else
            {
                if (serial == "-") throw new Exception("没有在线且已授权的 Quest。");
                if (action == "safe_sleep") { Conservative(serial); Thread.Sleep(250); MustSh(serial, 3500, "input keyevent KEYCODE_SLEEP"); d["result"] = "已恢复保守值并发送 prox_open + KEYCODE_SLEEP。"; }
                else if (action == "keep_awake") { DebugMode(serial); d["result"] = "已应用短时保活。"; }
                else if (action == "debug_mode") { DebugMode(serial); d["result"] = "已启用调试工作模式：USB/AC 保持唤醒、Wi-Fi 不休眠、屏幕 24 小时、模拟佩戴靠近。结束后请执行“恢复休眠超时”。"; }
                else if (action == "restore_sleep") { Conservative(serial); d["result"] = "已恢复正常休眠与 5 分钟屏幕超时。"; }
                else if (action == "conservative") { Conservative(serial); d["result"] = "已恢复保守默认值。"; }
                else if (action == "restore_backup") { RestoreBackup(serial); d["result"] = "已从备份恢复设置，并发送 prox_open。"; }
                else if (action == "prox_open") { MustSh(serial, 3500, "am broadcast -a com.oculus.vrpowermanager.prox_open"); d["result"] = "已发送 prox_open。"; }
                else if (action == "prox_close") { MustSh(serial, 3500, "am broadcast -a com.oculus.vrpowermanager.prox_close"); d["result"] = "已发送 prox_close。"; }
                else if (action == "wireless") { MustA(5000, "-s", serial, "tcpip", "5555"); d["result"] = "已请求开启无线 ADB 5555。"; }
                else if (action == "wireless_off") { MustSh(serial, 3500, "settings put global adb_wifi_enabled 0"); MustA(5000, "-s", serial, "usb"); d["result"] = "已请求关闭无线 ADB，adbd 已切回 USB 模式。若当前是无线连接，断开属于正常现象。"; }
                else if (action == "key_sleep") { MustSh(serial, 3500, "input keyevent KEYCODE_SLEEP"); d["result"] = "已发送 KEYCODE_SLEEP。"; }
                else if (action == "key_wakeup") { MustSh(serial, 3500, "input keyevent KEYCODE_WAKEUP"); d["result"] = "已发送 KEYCODE_WAKEUP。仅在 ADB 仍在线时有效。"; }
                else if (action == "screen_5m") { MustSh(serial, 3500, "settings put system screen_off_timeout 300000"); d["result"] = "screen_off_timeout = 300000。"; }
                else if (action == "screen_24h") { EnsureBackup(serial); MustSh(serial, 3500, "settings put system screen_off_timeout 86400000"); d["result"] = "screen_off_timeout = 86400000。"; }
                else if (action == "stay_off") { MustSh(serial, 3500, "settings put global stay_on_while_plugged_in 0"); d["result"] = "stay_on_while_plugged_in = 0。"; }
                else if (action == "stay_usb_ac") { EnsureBackup(serial); MustSh(serial, 3500, "settings put global stay_on_while_plugged_in 3"); d["result"] = "stay_on_while_plugged_in = 3。"; }
                else if (action == "reset_screen_off") { MustSh(serial, 3500, "settings put system screen_off_timeout 300000"); d["result"] = "已重置 screen_off_timeout = 300000。"; }
                else if (action == "reset_stay_on") { MustSh(serial, 3500, "settings put global stay_on_while_plugged_in 0"); d["result"] = "已重置 stay_on_while_plugged_in = 0。"; }
                else if (action == "reset_wifi_sleep") { MustSh(serial, 3500, "settings put global wifi_sleep_policy 1"); d["result"] = "已重置 wifi_sleep_policy = 1。"; }
                else if (action == "reset_sleep_timeout") { MustSh(serial, 3500, "settings delete secure sleep_timeout"); MustSh(serial, 3500, "am broadcast -a com.oculus.vrpowermanager.prox_open"); d["result"] = "已删除 sleep_timeout 并发送 prox_open。"; }
                else if (action == "custom_setting")
                {
                    string ns = Query(query, "ns"), key = Query(query, "key"), val = Query(query, "value");
                    if (!ValidNs(ns) || !SafeName(key)) throw new Exception("namespace 或键名不合法。");
                    if (DeniedSetting(key)) throw new Exception("该键名属于高风险系统键，已阻止自定义写入。");
                    EnsureBackup(serial);
                    MustSh(serial, 3500, "settings put " + ns + " " + key + " " + ShellQuote(val));
                    d["result"] = ns + "." + key + " = " + val;
                }
                else if (action == "custom_broadcast")
                {
                    string name = Query(query, "name");
                    if (!SafeName(name)) throw new Exception("广播名称不合法。");
                    MustSh(serial, 3500, "am broadcast -a " + name);
                    d["result"] = "已发送广播：" + name;
                }
                else throw new Exception("未知操作。");
            }
            Log("操作完成：" + Clean(action) + " result=" + (d.ContainsKey("result") ? d["result"] : "-"));
        }
        catch (Exception ex) { d["ok"] = "false"; d["error"] = ex.Message; Log("操作失败：" + Clean(action) + " error=" + ex.Message); }
        return d;
    }

    static Dictionary<string, string> Logs()
    {
        Dictionary<string, string> d = Ok();
        d["logFile"] = LogFile;
        d["text"] = ReadLogTail();
        return d;
    }

    static Dictionary<string, string> ExportReport()
    {
        Dictionary<string, string> d = Ok();
        DateTime started = DateTime.Now;
        Log("导出开始：只读完整设备信息 HTML");
        try
        {
            string deviceLine, hint;
            string state = SelectDevice(out deviceLine, out hint);
            if (state != "device") throw new Exception(hint);
            string serial = deviceLine.Split(' ')[0];
            Snapshot snap = CollectSnapshot(serial, deviceLine);
            string stamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            string root = Path.Combine(LogDir, "exports", stamp);
            Directory.CreateDirectory(root);
            string privateName = "Quest3_device_private_full_" + stamp + ".html";
            string safeName = "Quest3_device_share_safe_" + stamp + ".html";
            string privatePath = Path.Combine(root, privateName);
            string safePath = Path.Combine(root, safeName);
            File.WriteAllText(privatePath, BuildReportHtml(snap, false), Utf8NoBom);
            File.WriteAllText(safePath, BuildReportHtml(snap, true), Utf8NoBom);
            TimeSpan elapsed = DateTime.Now - started;
            d["privatePath"] = privatePath;
            d["safePath"] = safePath;
            d["privateUrl"] = ExportUrl(stamp, privateName);
            d["safeUrl"] = ExportUrl(stamp, safeName);
            d["durationMs"] = ((long)elapsed.TotalMilliseconds).ToString(CultureInfo.InvariantCulture);
            d["sectionCount"] = snap.Captures.Count.ToString(CultureInfo.InvariantCulture);
            d["warnings"] = snap.Warnings.Count == 0 ? "-" : string.Join(" | ", snap.Warnings.ToArray());
            d["result"] = "已生成私有完整版和分享安全版 HTML。";
            Log("导出完成：" + privatePath + " / " + safePath);
        }
        catch (Exception ex)
        {
            d["ok"] = "false";
            d["error"] = ex.Message;
            Log("导出失败：" + ex.Message);
        }
        return d;
    }

    static string ExportUrl(string stamp, string name)
    {
        return "/exports/" + Uri.EscapeDataString(stamp) + "/" + Uri.EscapeDataString(name) + "?token=" + Uri.EscapeDataString(Token);
    }

    static void ServeExport(Stream stream, string path)
    {
        try
        {
            string rel = Uri.UnescapeDataString(path.Substring("/exports/".Length)).Replace('/', Path.DirectorySeparatorChar);
            if (rel.IndexOf("..", StringComparison.Ordinal) >= 0 || rel.IndexOf(':') >= 0 || !rel.EndsWith(".html", StringComparison.OrdinalIgnoreCase))
            {
                WriteBytes(stream, "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("非法报告路径"));
                return;
            }
            string root = Path.GetFullPath(Path.Combine(LogDir, "exports"));
            string file = Path.GetFullPath(Path.Combine(root, rel));
            if (!file.StartsWith(root, StringComparison.OrdinalIgnoreCase) || !File.Exists(file))
            {
                WriteBytes(stream, "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("报告不存在"));
                return;
            }
            WriteBytes(stream, "text/html; charset=utf-8", File.ReadAllBytes(file));
        }
        catch (Exception ex)
        {
            WriteBytes(stream, "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("读取报告失败：" + ex.Message));
        }
    }

    static void DebugMode(string serial)
    {
        EnsureBackup(serial);
        MustSh(serial, 3500, "settings put global stay_on_while_plugged_in 3");
        MustSh(serial, 3500, "settings put global wifi_sleep_policy 2");
        MustSh(serial, 3500, "settings put system screen_off_timeout 86400000");
        MustSh(serial, 3500, "settings put secure sleep_timeout -1");
        MustSh(serial, 3500, "am broadcast -a com.oculus.vrpowermanager.prox_close");
    }

    static void Conservative(string serial)
    {
        MustSh(serial, 3500, "settings put global stay_on_while_plugged_in 0");
        MustSh(serial, 3500, "settings put global wifi_sleep_policy 1");
        MustSh(serial, 3500, "settings put system screen_off_timeout 300000");
        MustSh(serial, 3500, "settings delete secure sleep_timeout");
        MustSh(serial, 3500, "am broadcast -a com.oculus.vrpowermanager.prox_open");
    }

    static string CurrentSerial()
    {
        string line, hint;
        return SelectDevice(out line, out hint) == "device" ? line.Split(' ')[0] : "-";
    }

    static void InitLog(string baseDir)
    {
        try
        {
            string root = string.IsNullOrEmpty(baseDir) ? AppDomain.CurrentDomain.BaseDirectory : baseDir;
            root = root.Trim('"');
            root = Path.GetFullPath(root);
            if (!Directory.Exists(root)) Directory.CreateDirectory(root);
            RootDir = root;
            LogDir = Path.Combine(root, "Quest_ADB_Logs");
            Directory.CreateDirectory(LogDir);
            LogFile = Path.Combine(LogDir, "webui_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".log");
            File.AppendAllText(LogFile, "", Utf8NoBom);
        }
        catch
        {
            RootDir = AppDomain.CurrentDomain.BaseDirectory;
            LogDir = RootDir;
            LogFile = Path.Combine(LogDir, "Quest_ADB_WebUI.log");
        }
    }

    static void Log(string text)
    {
        try
        {
            lock (LogLock)
            {
                File.AppendAllText(LogFile, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + "  " + text + Environment.NewLine, Utf8NoBom);
            }
        }
        catch { }
    }

    static string ReadLogTail()
    {
        try
        {
            if (string.IsNullOrEmpty(LogFile) || !File.Exists(LogFile)) return "日志文件尚未创建。";
            byte[] bytes = File.ReadAllBytes(LogFile);
            int max = 18000;
            int start = bytes.Length > max ? bytes.Length - max : 0;
            string text = Encoding.UTF8.GetString(bytes, start, bytes.Length - start);
            int firstLine = text.IndexOf('\n');
            if (start > 0 && firstLine >= 0) text = text.Substring(firstLine + 1);
            return Clean(text);
        }
        catch (Exception ex) { return "读取日志失败：" + ex.Message; }
    }

    static string SelectDevice(out string deviceLine, out string hint)
    {
        deviceLine = "";
        hint = "未发现 ADB 设备。检查开发者模式、USB 调试授权、数据线和 Windows 驱动。";
        string unauthorized = "", offline = "", other = "", firstDevice = "", questDevice = "", questUsbDevice = "";
        foreach (string raw in Lines(A(3000, "devices", "-l")))
        {
            string l = raw.Trim();
            if (l.Length == 0 || l.StartsWith("List of", StringComparison.OrdinalIgnoreCase)) continue;
            string[] p = l.Split(new char[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            if (p.Length < 2) continue;
            if (p[1] == "device")
            {
                if (firstDevice.Length == 0) firstDevice = l;
                bool isQuest = l.IndexOf("model:Quest", StringComparison.OrdinalIgnoreCase) >= 0 ||
                               l.IndexOf("product:eureka", StringComparison.OrdinalIgnoreCase) >= 0 ||
                               l.IndexOf("device:eureka", StringComparison.OrdinalIgnoreCase) >= 0;
                if (isQuest && questDevice.Length == 0) questDevice = l;
                if (isQuest && p[0].IndexOf(':') < 0 && questUsbDevice.Length == 0) questUsbDevice = l;
                continue;
            }
            if (p[1] == "unauthorized" && unauthorized.Length == 0) unauthorized = l;
            else if (p[1] == "offline" && offline.Length == 0) offline = l;
            else if (other.Length == 0) other = l;
        }
        if (questUsbDevice.Length > 0) { deviceLine = questUsbDevice; hint = "已连接并已授权，已优先选择 USB Quest。"; return "device"; }
        if (questDevice.Length > 0) { deviceLine = questDevice; hint = "已连接并已授权，已选择 Quest。"; return "device"; }
        if (firstDevice.Length > 0) { deviceLine = firstDevice; hint = "已连接并已授权。注意：未识别到 Quest 型号，已选择第一个 ADB 设备。"; return "device"; }
        if (unauthorized.Length > 0) { deviceLine = unauthorized; hint = "设备未授权：戴上头显，在 USB 调试授权弹窗里选择允许。"; return "unauthorized"; }
        if (offline.Length > 0) { deviceLine = offline; hint = "设备离线：重启 ADB 服务、重插 USB 或更换数据线。"; return "offline"; }
        if (other.Length > 0) { deviceLine = other; hint = "发现设备但状态异常：" + other; return "unknown"; }
        return "none";
    }

    static string Prop(string serial, string name) { return Clean(Sh(serial, 2500, "getprop " + name)); }
    static string Setting(string serial, string ns, string key) { string v = Clean(Sh(serial, 2500, "settings get " + ns + " " + key)); return v == "null" ? "null" : v; }
    static string Sh(string serial, int timeout, string command) { return Clean(A(timeout, "-s", serial, "shell", command)); }
    static string A(int timeout, params string[] args) { return Run(AdbPath, args, timeout); }
    static string MustSh(string serial, int timeout, string command) { return Clean(MustA(timeout, "-s", serial, "shell", command)); }
    static string MustA(int timeout, params string[] args)
    {
        CmdResult r = RunResult(AdbPath, args, timeout);
        string text = Clean(r.Text);
        if (r.TimedOut) throw new Exception("ADB 命令超时：" + JoinArgs(args));
        if (r.ExitCode != 0) throw new Exception("ADB 命令失败(" + r.ExitCode + ")：" + text);
        return text;
    }

    static void EnsureBackup(string serial)
    {
        string file = BackupFile(serial);
        if (File.Exists(file)) return;
        StringBuilder sb = new StringBuilder();
        sb.AppendLine("# Quest ADB 工具设置备份");
        sb.AppendLine("# device=" + serial);
        sb.AppendLine("# created=" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
        WriteBackupLine(sb, serial, "global", "stay_on_while_plugged_in");
        WriteBackupLine(sb, serial, "global", "wifi_sleep_policy");
        WriteBackupLine(sb, serial, "system", "screen_off_timeout");
        WriteBackupLine(sb, serial, "secure", "sleep_timeout");
        File.WriteAllText(file, sb.ToString(), Utf8NoBom);
        Log("已创建设置备份：" + file);
    }

    static void WriteBackupLine(StringBuilder sb, string serial, string ns, string key)
    {
        string value = MustSh(serial, 3500, "settings get " + ns + " " + key);
        if (value == "-") throw new Exception("读取备份值失败：" + ns + "." + key);
        sb.Append(ns).Append(' ').Append(key).Append(' ').AppendLine(value);
    }

    static void RestoreBackup(string serial)
    {
        string file = BackupFile(serial);
        if (!File.Exists(file)) throw new Exception("没有找到备份文件：" + file);
        foreach (string raw in File.ReadAllLines(file, Encoding.UTF8))
        {
            string line = raw.Trim();
            if (line.Length == 0 || line.StartsWith("#", StringComparison.Ordinal)) continue;
            string[] p = line.Split(new char[] { ' ' }, 3);
            if (p.Length < 3 || !ValidNs(p[0]) || !SafeName(p[1])) continue;
            if (p[2] == "null") MustSh(serial, 3500, "settings delete " + p[0] + " " + p[1]);
            else MustSh(serial, 3500, "settings put " + p[0] + " " + p[1] + " " + ShellQuote(p[2]));
        }
        MustSh(serial, 3500, "am broadcast -a com.oculus.vrpowermanager.prox_open");
        Log("已从备份恢复：" + file);
    }

    static string BackupFile(string serial)
    {
        string safe = serial ?? "device";
        safe = safe.Replace(":", "_").Replace(".", "_").Replace("\\", "_").Replace("/", "_");
        string root = string.IsNullOrEmpty(RootDir) ? AppDomain.CurrentDomain.BaseDirectory : RootDir;
        return Path.Combine(root, "quest_adb_settings_" + safe + ".bak");
    }

    static void FillBattery(Dictionary<string, string> d, string serial)
    {
        string s = Sh(serial, 2500, "dumpsys battery");
        d["batteryLevel"] = AfterColon(s, "level");
        string temp = AfterColon(s, "temperature");
        double n;
        if (double.TryParse(temp, NumberStyles.Any, CultureInfo.InvariantCulture, out n) && n > 100) temp = (n / 10.0).ToString("0.#", CultureInfo.InvariantCulture);
        d["batteryTemp"] = temp;
        d["batteryStatus"] = BatteryStatus(AfterColon(s, "status"));
        d["batteryHealth"] = BatteryHealth(AfterColon(s, "health"));
        d["powerSource"] = PowerSource(s);
    }

    static void FillPower(Dictionary<string, string> d, string serial)
    {
        string s = Sh(serial, 5000, "dumpsys power");
        d["wakefulness"] = AfterEquals(s, "mWakefulness");
        d["mStayOn"] = AfterEquals(s, "mStayOn");
        d["mProximityPositive"] = AfterEquals(s, "mProximityPositive");
        d["mStayOnSetting"] = AfterEquals(s, "mStayOnWhilePluggedInSetting");
        d["powerSleepLine"] = FindLine(s, "Sleep timeout:");
    }

    static void FillControllersFast(Dictionary<string, string> d, string serial)
    {
        d["controllerLeftBattery"] = "-";
        d["controllerRightBattery"] = "-";
        d["controllerLeftStatus"] = "-";
        d["controllerRightStatus"] = "-";
        d["controllerHint"] = "未读取到手柄电量。";
        string s = Sh(serial, 5000, "dumpsys OVRRemoteService");
        List<string> hits = new List<string>();
        foreach (string raw in Lines(s))
        {
            string l = raw.Trim();
            if (l.IndexOf("Battery:", StringComparison.OrdinalIgnoreCase) < 0 || l.IndexOf("Type:", StringComparison.OrdinalIgnoreCase) < 0) continue;
            string type = Field(l, "Type"), battery = Field(l, "Battery"), status = Field(l, "Status");
            if (type.Equals("Left", StringComparison.OrdinalIgnoreCase)) { d["controllerLeftBattery"] = battery; d["controllerLeftStatus"] = status; }
            if (type.Equals("Right", StringComparison.OrdinalIgnoreCase)) { d["controllerRightBattery"] = battery; d["controllerRightStatus"] = status; }
            hits.Add(l.Length > 140 ? l.Substring(0, 140) : l);
        }
        if (hits.Count > 0) d["controllerHint"] = string.Join(" | ", hits.ToArray());
    }

    static void FillResources(Dictionary<string, string> d, string serial)
    {
        d["storage"] = "-";
        d["memory"] = "-";
        string df = Sh(serial, 3500, "df -h /sdcard");
        foreach (string raw in Lines(df))
        {
            string l = raw.Trim();
            if (l.Length == 0 || l.StartsWith("Filesystem", StringComparison.OrdinalIgnoreCase)) continue;
            string[] p = l.Split(new char[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            if (p.Length >= 5) { d["storage"] = p[2] + " / " + p[1] + " 已用 " + p[4]; break; }
        }
        string mem = Sh(serial, 3500, "cat /proc/meminfo");
        string total = MemGb(mem, "MemTotal:"), available = MemGb(mem, "MemAvailable:");
        if (total != "-" && available != "-") d["memory"] = "可用 " + available + " / 总计 " + total;
    }

    static void FillVirtualDesktop(Dictionary<string, string> d, string serial)
    {
        d["vdPackage"] = "-";
        d["vdVersion"] = "-";
        string pkg = "VirtualDesktop.Android";
        string s = Sh(serial, 5000, "dumpsys package " + pkg);
        if (s.IndexOf("Package [" + pkg + "]", StringComparison.OrdinalIgnoreCase) < 0) return;
        d["vdPackage"] = pkg;
        string version = FindPackageField(s, "versionName=");
        if (version != "-") d["vdVersion"] = version;
    }

    static void FillDisplayLite(Dictionary<string, string> d, string serial)
    {
        d["displaySummary"] = "-";
        string s = Sh(serial, 5000, "dumpsys display");
        string line = FindLine(s, "DisplayDeviceInfo");
        if (line == "-") return;
        string res = RegexValue(line, @"(\d{3,5}\s*x\s*\d{3,5})");
        string fps = RegexValue(line, @"renderFrameRate\s+([0-9.]+)");
        string density = RegexValue(line, @"density\s+([0-9]+)");
        string panel = Between(line, "DeviceProductInfo{name=", ",");
        List<string> parts = new List<string>();
        if (res != "-") parts.Add(res.Replace(" ", ""));
        if (fps != "-") parts.Add(fps + "Hz");
        if (density != "-") parts.Add("density " + density);
        if (panel != "-") parts.Add(panel);
        d["displaySummary"] = parts.Count == 0 ? "-" : string.Join(" / ", parts.ToArray());
    }

    static void FillThermalLite(Dictionary<string, string> d, string serial)
    {
        d["thermalSummary"] = "-";
        string s = Sh(serial, 5000, "dumpsys thermalservice");
        string status = AfterColon(s, "Thermal Status");
        string battery = FirstRegex(s, @"mName=battery,\s*mValue=([0-9.]+)");
        if (battery == "-") battery = FirstRegex(s, @"battery[^0-9]+([0-9]+\.[0-9]+)");
        if (status != "-" || battery != "-") d["thermalSummary"] = "status " + status + (battery != "-" ? " / battery " + battery + "C" : "");
    }

    static void FillFactoryLite(Dictionary<string, string> d, string serial)
    {
        d["factorySummary"] = "-";
        string s = Sh(serial, 6000, "dumpsys sensorservice");
        string build = ExtractJsonish(s, "BuildType");
        string device = ExtractJsonish(s, "DeviceType");
        string factoryTs = ExtractJsonish(s, "Timestamp");
        string location = ExtractJsonish(s, "location_id");
        string station = ExtractJsonish(s, "station_id");
        List<string> parts = new List<string>();
        if (device != "-") parts.Add(device);
        if (build != "-") parts.Add(build);
        if (factoryTs != "-") parts.Add("Factory " + factoryTs);
        if (location != "-") parts.Add("loc " + location);
        if (station != "-") parts.Add("station " + station);
        d["factorySummary"] = parts.Count == 0 ? "-" : string.Join(" / ", parts.ToArray());
    }

    static Snapshot CollectSnapshot(string serial, string deviceLine)
    {
        Snapshot snap = new Snapshot();
        snap.Created = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
        snap.Serial = serial;
        snap.DeviceLine = deviceLine;

        AddCapture(snap, "adb_devices", 4000, false, "devices", "-l");
        AddShellCapture(snap, "id", serial, 3000, "id");
        AddShellCapture(snap, "getprop", serial, 6000, "getprop");
        AddShellCapture(snap, "settings_global", serial, 6000, "settings list global");
        AddShellCapture(snap, "settings_system", serial, 6000, "settings list system");
        AddShellCapture(snap, "settings_secure", serial, 6000, "settings list secure");
        AddShellCapture(snap, "battery", serial, 5000, "dumpsys battery");
        AddShellCapture(snap, "power", serial, 7000, "dumpsys power");
        AddShellCapture(snap, "display", serial, 9000, "dumpsys display");
        AddShellCapture(snap, "usb", serial, 7000, "dumpsys usb");
        AddShellCapture(snap, "wifi", serial, 9000, "dumpsys wifi");
        AddShellCapture(snap, "connectivity", serial, 8000, "dumpsys connectivity");
        AddShellCapture(snap, "bluetooth", serial, 7000, "dumpsys bluetooth_manager");
        AddShellCapture(snap, "camera", serial, 8000, "dumpsys media.camera");
        AddShellCapture(snap, "sensorservice", serial, 12000, "dumpsys sensorservice");
        AddShellCapture(snap, "thermal", serial, 7000, "dumpsys thermalservice");
        AddShellCapture(snap, "input", serial, 7000, "dumpsys input");
        AddShellCapture(snap, "packages", serial, 12000, "pm list packages -f -i");
        AddShellCapture(snap, "features", serial, 8000, "pm list features");
        AddShellCapture(snap, "libraries", serial, 8000, "cmd package list libraries");
        AddShellCapture(snap, "df", serial, 5000, "df -h /data /sdcard");
        AddShellCapture(snap, "meminfo", serial, 5000, "cat /proc/meminfo");
        AddShellCapture(snap, "cpuinfo", serial, 5000, "cat /proc/cpuinfo");
        AddShellCapture(snap, "uname", serial, 3000, "uname -a");
        AddShellCapture(snap, "ip_addr", serial, 5000, "ip addr");
        AddShellCapture(snap, "ip_route", serial, 5000, "ip route");
        AddShellCapture(snap, "virtualdesktop", serial, 8000, "dumpsys package VirtualDesktop.Android");
        AddShellCapture(snap, "oculus_packages", serial, 10000, "dumpsys package com.oculus");
        AddShellCapture(snap, "logcat_tail_private", serial, 10000, "logcat -d -t 3000");

        FillSnapshotFields(snap);
        return snap;
    }

    static void AddShellCapture(Snapshot snap, string name, string serial, int timeout, string command)
    {
        AddCapture(snap, name, timeout, false, "-s", serial, "shell", command);
    }

    static void AddCapture(Snapshot snap, string name, int timeout, bool required, params string[] args)
    {
        Stopwatch sw = Stopwatch.StartNew();
        CmdResult r = RunResult(AdbPath, args, timeout);
        sw.Stop();
        Capture c = new Capture();
        c.Name = name;
        c.Command = "adb " + JoinArgs(args);
        c.Output = Clean(r.Output);
        c.Error = Clean(r.Error);
        c.ExitCode = r.ExitCode;
        c.TimedOut = r.TimedOut;
        c.DurationMs = sw.ElapsedMilliseconds;
        snap.Captures.Add(c);
        if (r.TimedOut) snap.Warnings.Add(name + " 超时");
        else if (r.ExitCode != 0 && required) snap.Warnings.Add(name + " 失败：" + Clean(r.Text));
        else if (r.ExitCode != 0) snap.Warnings.Add(name + " 受限或无输出");
    }

    static Capture Cap(Snapshot snap, string name)
    {
        foreach (Capture c in snap.Captures) if (c.Name == name) return c;
        return new Capture();
    }

    static void FillSnapshotFields(Snapshot snap)
    {
        Dictionary<string, string> f = snap.Fields;
        string prop = Cap(snap, "getprop").Text;
        string battery = Cap(snap, "battery").Text;
        string power = Cap(snap, "power").Text;
        string display = Cap(snap, "display").Text;
        string thermal = Cap(snap, "thermal").Text;
        string sensor = Cap(snap, "sensorservice").Text;
        string wifi = Cap(snap, "wifi").Text;
        string bt = Cap(snap, "bluetooth").Text;
        string usb = Cap(snap, "usb").Text;
        string cam = Cap(snap, "camera").Text;
        string packages = Cap(snap, "packages").Text;
        string features = Cap(snap, "features").Text;

        f["serial"] = snap.Serial;
        f["deviceLine"] = snap.DeviceLine;
        f["created"] = snap.Created;
        f["model"] = PropFrom(prop, "ro.product.model");
        f["manufacturer"] = PropFrom(prop, "ro.product.manufacturer");
        f["brand"] = PropFrom(prop, "ro.product.brand");
        f["product"] = PropFrom(prop, "ro.product.name");
        f["device"] = PropFrom(prop, "ro.product.device");
        f["board"] = PropFrom(prop, "ro.product.board");
        f["soc"] = JoinNonEmpty(PropFrom(prop, "ro.soc.manufacturer"), PropFrom(prop, "ro.soc.model"));
        f["android"] = PropFrom(prop, "ro.build.version.release");
        f["sdk"] = PropFrom(prop, "ro.build.version.sdk");
        f["securityPatch"] = PropFrom(prop, "ro.build.version.security_patch");
        f["vendorPatch"] = PropFrom(prop, "ro.vendor.build.security_patch");
        f["buildId"] = PropFrom(prop, "ro.build.display.id");
        f["buildIncremental"] = PropFrom(prop, "ro.build.version.incremental");
        f["buildBranch"] = PropFrom(prop, "ro.build.branch");
        f["fingerprint"] = PropFrom(prop, "ro.build.fingerprint");
        f["abi"] = PropFrom(prop, "ro.product.cpu.abi");
        f["kernel"] = FirstLine(Cap(snap, "uname").Text);
        f["batteryLevel"] = AfterColon(battery, "level") + "%";
        string temp = AfterColon(battery, "temperature");
        double n;
        if (double.TryParse(temp, NumberStyles.Any, CultureInfo.InvariantCulture, out n) && n > 100) temp = (n / 10.0).ToString("0.#", CultureInfo.InvariantCulture);
        f["batteryTemp"] = temp == "-" ? "-" : temp + "C";
        f["batteryHealth"] = BatteryHealth(AfterColon(battery, "health"));
        f["powerSource"] = PowerSource(battery);
        f["wakefulness"] = AfterEquals(power, "mWakefulness");
        f["stayOn"] = AfterEquals(power, "mStayOn");
        f["proximity"] = AfterEquals(power, "mProximityPositive");
        f["storage"] = StorageSummary(Cap(snap, "df").Text);
        f["memory"] = MemorySummary(Cap(snap, "meminfo").Text);
        f["cpu"] = CpuSummary(Cap(snap, "cpuinfo").Text);
        f["display"] = DisplaySummary(display);
        f["panel"] = Between(FindLine(display, "DeviceProductInfo"), "DeviceProductInfo{name=", ",");
        f["thermal"] = ThermalSummary(thermal);
        f["usb"] = UsbSummary(usb);
        f["wifi"] = WifiSummary(wifi, Cap(snap, "ip_addr").Text);
        f["bluetooth"] = BluetoothSummary(bt);
        f["camera"] = CameraSummary(cam, sensor);
        f["factory"] = FactorySummary(sensor);
        f["factoryDevice"] = ExtractJsonish(sensor, "DeviceType");
        f["factoryBuild"] = ExtractJsonish(sensor, "BuildType");
        f["factoryTime"] = ExtractJsonish(sensor, "Timestamp");
        f["factoryLocation"] = ExtractJsonish(sensor, "location_id");
        f["factoryStation"] = ExtractJsonish(sensor, "station_id");
        f["factoryStationType"] = ExtractJsonish(sensor, "station_type");
        f["factoryTest"] = ExtractJsonish(sensor, "cal_test_id");
        f["factoryOperator"] = ExtractJsonish(sensor, "operator_id");
        f["factoryCalibration"] = ExtractJsonish(sensor, "calibration_type");
        f["onlineCalibration"] = sensor.IndexOf("vega_online_calibration", StringComparison.OrdinalIgnoreCase) >= 0 ? "检测到 vega_online_calibration" : "-";
        f["packages"] = CountPackageLines(packages).ToString(CultureInfo.InvariantCulture);
        f["features"] = CountPrefixLines(features, "feature:").ToString(CultureInfo.InvariantCulture);
        f["vd"] = VirtualDesktopSummary(Cap(snap, "virtualdesktop").Text);
        f["warnings"] = snap.Warnings.Count == 0 ? "-" : string.Join(" | ", snap.Warnings.ToArray());
    }

    static string BuildReportHtml(Snapshot snap, bool safe)
    {
        Dictionary<string, string> f = snap.Fields;
        string title = safe ? "Quest ADB 设备审计报告 - 分享安全版" : "Quest ADB 设备审计报告 - 私有完整版";
        string privacy = safe ? "SHARE-SAFE" : "PRIVATE FULL";
        string reportNo = "QADB-" + DateTime.Now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
        string serial = Privacy(V(f, "serial"), safe);

        StringBuilder sb = new StringBuilder();
        sb.AppendLine("<!doctype html><html lang=\"zh-CN\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>" + H(title) + "</title>");
        sb.AppendLine("<style>");
        sb.AppendLine(":root{--page:#eef1f5;--paper:#fff;--ink:#182033;--muted:#667085;--line:#d8e0eb;--line2:#edf1f6;--soft:#f7f9fc;--accent:#1d4ed8;--accent2:#0f172a;--ok:#118447;--warn:#9a5b00;--shadow:0 18px 48px rgba(15,23,42,.13)}*{box-sizing:border-box}html,body{margin:0;background:var(--page);color:var(--ink);font:14px/1.52 \"Segoe UI\",\"Microsoft YaHei\",Arial,sans-serif;letter-spacing:0}.sheet{width:min(1120px,calc(100% - 40px));margin:30px auto;background:var(--paper);border:1px solid #dfe6f0;box-shadow:var(--shadow)}.pad{padding:38px 44px}.actions{position:sticky;top:0;z-index:3;display:flex;justify-content:flex-end;gap:8px;width:min(1120px,calc(100% - 40px));margin:18px auto -16px}.btn{border:1px solid #cbd5e1;background:#fff;color:#0f172a;border-radius:6px;padding:8px 12px;font-weight:800;cursor:pointer}.btn.primary{background:var(--accent);border-color:var(--accent);color:#fff}.doc-head{display:grid;grid-template-columns:1fr 340px;gap:28px;border-bottom:3px solid var(--accent2);padding-bottom:24px}.kicker{display:inline-block;color:var(--accent);font-size:12px;font-weight:900;letter-spacing:.08em;text-transform:uppercase;margin-bottom:10px}h1{font-size:32px;line-height:1.12;margin:0 0 10px;font-weight:900;color:#0f172a}.sub{color:var(--muted);max-width:680px;margin:0}.meta{border:1px solid var(--line);align-self:start;min-width:0}.meta-row{display:grid;grid-template-columns:118px minmax(0,1fr);border-bottom:1px solid var(--line2);min-height:38px}.meta-row:last-child{border-bottom:0}.meta-row span{background:var(--soft);color:var(--muted);font-weight:800;padding:9px 12px;border-right:1px solid var(--line2)}.meta-row b{padding:9px 12px;min-width:0;overflow-wrap:anywhere;word-break:break-word}.stamp{display:inline-block;border:2px solid " + (safe ? "var(--ok)" : "var(--warn)") + ";color:" + (safe ? "var(--ok)" : "var(--warn)") + ";font-weight:900;padding:4px 8px;border-radius:4px;transform:rotate(-1deg)}.party-grid{display:grid;grid-template-columns:1fr 1fr;gap:18px;margin:26px 0}.box{border:1px solid var(--line);background:#fff;min-width:0}.box h2,.section h2{font-size:13px;text-transform:uppercase;letter-spacing:.08em;color:#344054;margin:0;background:var(--soft);border-bottom:1px solid var(--line);padding:10px 12px}.box-body{padding:13px 14px}.big{font-size:22px;font-weight:900;margin-bottom:6px}.muted{color:var(--muted)}.chips{display:flex;flex-wrap:wrap;gap:7px;margin-top:12px}.chip{border:1px solid var(--line);background:var(--soft);border-radius:999px;padding:5px 9px;font-weight:800}.summary{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));border:1px solid var(--line);margin:20px 0 24px}.sum-cell{padding:13px 14px;border-right:1px solid var(--line2);min-width:0}.sum-cell:last-child{border-right:0}.sum-cell span{display:block;color:var(--muted);font-size:12px;font-weight:800;text-transform:uppercase}.sum-cell b{display:block;font-size:18px;margin-top:5px;overflow-wrap:anywhere;word-break:break-word}.section{margin-top:22px}.audit-table{width:100%;border-collapse:collapse;border:1px solid var(--line);table-layout:fixed}.audit-table th{background:#f2f5f9;color:#344054;text-align:left;font-size:12px;text-transform:uppercase;letter-spacing:.06em;border-bottom:2px solid #111827;padding:10px 12px}.audit-table td{border-top:1px solid var(--line2);padding:10px 12px;vertical-align:top;overflow-wrap:anywhere;word-break:break-word}.audit-table td:nth-child(1){width:22%;color:#475467;font-weight:800}.audit-table td:nth-child(2){width:44%;font-weight:800;color:#101828}.audit-table td:nth-child(3){width:34%;color:#667085}.note{border-left:4px solid var(--warn);background:#fff8eb;border-top:1px solid #f3d19c;border-right:1px solid #f3d19c;border-bottom:1px solid #f3d19c;padding:13px 14px;margin-top:18px}.raw details{border:1px solid var(--line);margin:10px 0;background:#fff}.raw summary{cursor:pointer;background:var(--soft);padding:10px 12px;font-weight:900}.raw pre{margin:0;max-height:420px;overflow:auto;white-space:pre-wrap;overflow-wrap:anywhere;word-break:break-word;color:#475467;padding:12px;font:12px/1.5 Consolas,\"Microsoft YaHei\",monospace}.foot{display:grid;grid-template-columns:1fr auto;gap:20px;align-items:end;margin-top:28px;border-top:2px solid #111827;padding-top:16px}.foot b{font-size:12px;text-transform:uppercase;letter-spacing:.08em}.total{min-width:250px;border:1px solid var(--line)}.total div{display:grid;grid-template-columns:1fr auto;padding:9px 12px;border-bottom:1px solid var(--line2)}.total div:last-child{border-bottom:0;background:var(--soft);font-weight:900}@media(max-width:860px){.doc-head,.party-grid,.summary{grid-template-columns:1fr}.pad{padding:24px 18px}.sheet,.actions{width:calc(100% - 18px)}.summary{display:block}.sum-cell{border-right:0;border-bottom:1px solid var(--line2)}.audit-table{table-layout:auto}.audit-table th:nth-child(3),.audit-table td:nth-child(3){display:none}.foot{grid-template-columns:1fr}.total{min-width:0}}@media(max-width:520px){.meta-row{grid-template-columns:105px minmax(0,1fr)}h1{font-size:28px}.actions{justify-content:flex-start;overflow:auto}}@media print{body{background:#fff}.actions{display:none}.sheet{width:auto;margin:0;border:0;box-shadow:none}.pad{padding:0}.raw pre{max-height:none}.box,.audit-table,.raw details{break-inside:avoid}@page{size:A4;margin:13mm}}");
        sb.AppendLine("</style></head><body>");
        sb.AppendLine("<div class=\"actions\"><button class=\"btn primary\" onclick=\"window.print()\">打印 / 保存 PDF</button><button class=\"btn\" onclick=\"document.querySelectorAll('details').forEach(d=>d.open=true)\">展开附录</button></div>");
        sb.AppendLine("<main class=\"sheet\"><div class=\"pad\">");
        sb.AppendLine("<header class=\"doc-head\"><div><div class=\"kicker\">Quest ADB Tools / Read-only export</div><h1>Quest ADB 设备审计报告</h1><p class=\"sub\">基于公开 ADB 只读命令生成，用于整理 Quest 头显身份、系统、健康、工厂/校准线索、包与能力。导出流程不写入设置，不修改设备。作者测试设备版本：Quest 3。</p></div>");
        sb.AppendLine("<aside class=\"meta\"><div class=\"meta-row\"><span>报告编号</span><b>" + H(reportNo) + "</b></div><div class=\"meta-row\"><span>生成时间</span><b>" + H(V(f, "created")) + "</b></div><div class=\"meta-row\"><span>隐私级别</span><b><i class=\"stamp\">" + H(privacy) + "</i></b></div><div class=\"meta-row\"><span>ADB 来源</span><b title=\"" + H(V(f, "adbPath")) + "\">" + H(AdbSourceLabel(V(f, "adbPath"))) + "</b></div></aside></header>");
        sb.AppendLine("<section class=\"party-grid\"><div class=\"box\"><h2>设备</h2><div class=\"box-body\"><div class=\"big\">" + H(V(f, "model")) + "</div><div class=\"muted\">" + H(V(f, "manufacturer")) + " / " + H(V(f, "product")) + " / " + H(V(f, "device")) + "</div><div class=\"chips\"><span class=\"chip\">Serial " + H(serial) + "</span><span class=\"chip\">" + H(V(f, "android")) + " / SDK " + H(V(f, "sdk")) + "</span><span class=\"chip\">" + H(V(f, "soc")) + "</span></div></div></div>");
        sb.AppendLine("<div class=\"box\"><h2>采集策略</h2><div class=\"box-body\"><div class=\"big\">" + H(safe ? "分享安全版" : "私有完整版") + "</div><div class=\"muted\">" + H(safe ? "已遮蔽序列号、局域网地址、MAC/BSSID、fingerprint、session 等敏感字段；跳过 logcat 附录。" : "保留完整私有证据，适合本机留档；不要直接公开分享。") + "</div><div class=\"chips\"><span class=\"chip\">No ADB write</span><span class=\"chip\">HTML/PDF ready</span><span class=\"chip\">Quest 3 noted</span></div></div></div></section>");
        sb.AppendLine("<section class=\"summary\"><div class=\"sum-cell\"><span>电量 / 温度</span><b>" + H(V(f, "batteryLevel")) + " / " + H(V(f, "batteryTemp")) + "</b></div><div class=\"sum-cell\"><span>显示</span><b>" + H(V(f, "display")) + "</b></div><div class=\"sum-cell\"><span>存储</span><b>" + H(V(f, "storage")) + "</b></div><div class=\"sum-cell\"><span>校准</span><b>" + H(V(f, "factory")) + "</b></div></section>");
        AddInvoiceFacts(sb, "设备身份", f, safe, new string[] { "serial|序列号|adb devices / getprop", "deviceLine|ADB 设备行|adb devices -l", "manufacturer|厂商|ro.product.manufacturer", "brand|品牌|ro.product.brand", "model|型号|ro.product.model", "product|产品代号|ro.product.name", "device|设备代号|ro.product.device", "board|板级|ro.product.board", "soc|SoC|ro.soc.model", "abi|ABI|ro.product.cpu.abi" });
        AddInvoiceFacts(sb, "系统与构建", f, safe, new string[] { "android|Android|getprop", "sdk|SDK|getprop", "securityPatch|系统安全补丁|getprop", "vendorPatch|Vendor 安全补丁|getprop", "buildId|Build ID|getprop", "buildIncremental|Incremental|getprop", "buildBranch|Branch|getprop", "fingerprint|Fingerprint|getprop", "kernel|Kernel|uname -a" });
        AddInvoiceFacts(sb, "显示 / 电源 / 网络 / 热", f, safe, new string[] { "display|显示摘要|dumpsys display", "panel|面板线索|dumpsys display", "batteryLevel|电量|dumpsys battery", "batteryTemp|电池温度|dumpsys battery", "batteryHealth|电池健康|dumpsys battery", "powerSource|供电|dumpsys battery", "wakefulness|唤醒状态|dumpsys power", "stayOn|保持唤醒|settings / dumpsys power", "proximity|接近状态|dumpsys sensorservice", "thermal|热状态|dumpsys thermalservice", "usb|USB|dumpsys usb", "wifi|Wi-Fi|dumpsys wifi / ip addr", "bluetooth|蓝牙|dumpsys bluetooth_manager", "camera|相机/传感器|dumpsys media.camera / sensorservice", "storage|存储|df -h", "memory|内存|/proc/meminfo", "cpu|CPU|/proc/cpuinfo" });
        AddInvoiceFacts(sb, "Factory / Calibration 元数据", f, safe, new string[] { "factoryDevice|DeviceType|sensorservice metadata", "factoryBuild|BuildType|sensorservice metadata", "factoryTime|Factory Timestamp|sensorservice metadata", "factoryLocation|location_id|sensorservice metadata", "factoryStation|station_id|sensorservice metadata", "factoryStationType|station_type|sensorservice metadata", "factoryTest|cal_test_id|sensorservice metadata", "factoryOperator|operator_id|sensorservice metadata", "factoryCalibration|calibration_type|sensorservice metadata", "onlineCalibration|Online calibration|sensorservice metadata" });
        sb.AppendLine("<div class=\"note\"><b>推断边界：</b>可以记录设备族、硬件阶段、校准记录和工厂测试线索，例如 Quest 3 / Eureka / PVT / Factory / Online calibration。不能把 location_id、station_id、station_type 可靠翻译成国家、城市或具体工厂；Wi-Fi 国家码也不是出产地。</div>");
        AddInvoiceFacts(sb, "包与系统能力", f, safe, new string[] { "packages|包数量|pm list packages", "features|Feature 数量|pm list features", "vd|Virtual Desktop|dumpsys package VirtualDesktop.Android", "warnings|采集警告|export collector" });
        AddInvoiceRaw(sb, snap, safe);
        sb.AppendLine("<footer class=\"foot\"><div><b>Quest ADB Tools by dwgx1337</b><br><span class=\"muted\">Public repo sample must use share-safe export. Private full export is for local evidence only.</span></div><div class=\"total\"><div><span>Packages</span><b>" + H(V(f, "packages")) + "</b></div><div><span>Features</span><b>" + H(V(f, "features")) + "</b></div><div><span>Status</span><b>" + H(safe ? "Share-safe" : "Private") + "</b></div></div></footer>");
        sb.AppendLine("</div></main></body></html>");
        return sb.ToString();
    }

    static void AddInvoiceFacts(StringBuilder sb, string title, Dictionary<string, string> f, bool safe, string[] defs)
    {
        sb.AppendLine("<section class=\"section\"><h2>" + H(title) + "</h2><table class=\"audit-table\"><thead><tr><th>字段</th><th>值</th><th>证据来源</th></tr></thead><tbody>");
        foreach (string def in defs)
        {
            string[] p = def.Split(new char[] { '|' }, 3);
            string key = p[0];
            string label = p.Length > 1 ? p[1] : key;
            string source = p.Length > 2 ? p[2] : "ADB";
            string val = V(f, key);
            if (safe) val = Privacy(val, true);
            sb.AppendLine("<tr><td>" + H(label) + "</td><td>" + H(val) + "</td><td>" + H(source) + "</td></tr>");
        }
        sb.AppendLine("</tbody></table></section>");
    }

    static void AddInvoiceRaw(StringBuilder sb, Snapshot snap, bool safe)
    {
        sb.AppendLine("<section class=\"section raw\"><h2>原始 ADB 输出附录</h2>");
        foreach (Capture c in snap.Captures)
        {
            if (safe && c.Name.IndexOf("logcat", StringComparison.OrdinalIgnoreCase) >= 0) continue;
            string text = c.Text;
            if (safe) text = Redact(text, snap);
            if (text.Length > 60000) text = text.Substring(0, 60000) + "\n... 已截断，完整内容请看私有完整版 ...";
            sb.AppendLine("<details><summary>" + H(c.Name) + " · " + H(c.DurationMs.ToString(CultureInfo.InvariantCulture)) + "ms · exit " + H(c.ExitCode.ToString(CultureInfo.InvariantCulture)) + (c.TimedOut ? " · timeout" : "") + "</summary><pre>" + H(text) + "</pre></details>");
        }
        sb.AppendLine("</section>");
    }

    static string WifiIp(string serial)
    {
        string ip = Sh(serial, 2500, "getprop dhcp.wlan0.ipaddress");
        if (ip != "-" && ip != "0.0.0.0") return ip;
        foreach (string raw in Lines(Sh(serial, 2500, "ip -f inet addr show wlan0")))
        {
            string l = raw.Trim();
            int p = l.IndexOf("inet ");
            if (p >= 0) { string rest = l.Substring(p + 5).Trim(); int slash = rest.IndexOf('/'); if (slash > 0) return rest.Substring(0, slash); }
        }
        return "-";
    }

    static string Run(string file, string[] args, int timeout)
    {
        return Clean(RunResult(file, args, timeout).Text);
    }

    static CmdResult RunResult(string file, string[] args, int timeout)
    {
        CmdResult result = new CmdResult();
        try
        {
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = file;
            psi.Arguments = JoinArgs(args);
            psi.UseShellExecute = false;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.CreateNoWindow = true;
            Process p = Process.Start(psi);
            Thread outThread = new Thread(delegate() { try { result.Output = p.StandardOutput.ReadToEnd(); } catch { } });
            Thread errThread = new Thread(delegate() { try { result.Error = p.StandardError.ReadToEnd(); } catch { } });
            outThread.Start();
            errThread.Start();
            if (!p.WaitForExit(timeout)) { result.TimedOut = true; try { p.Kill(); } catch { } return result; }
            result.ExitCode = p.ExitCode;
            outThread.Join(1000);
            errThread.Join(1000);
            return result;
        }
        catch (Exception ex) { result.Error = ex.Message; return result; }
    }

    static string JoinArgs(string[] args) { StringBuilder sb = new StringBuilder(); for (int i = 0; i < args.Length; i++) { if (i > 0) sb.Append(' '); sb.Append(QuoteArg(args[i])); } return sb.ToString(); }
    static string QuoteArg(string s) { if (s == null) return "\"\""; if (s.IndexOfAny(new char[] { ' ', '\t', '"', '&', '|', '<', '>', '^' }) < 0) return s; return "\"" + s.Replace("\"", "\\\"") + "\""; }
    static string JoinNonEmpty(string a, string b) { a = Clean(a); b = Clean(b); if (a == "-") return b; if (b == "-") return a; return a + " " + b; }
    static string BatteryStatus(string v) { if (v == "2") return "充电中"; if (v == "3" || v == "4") return "未充电"; if (v == "5") return "已充满"; return Clean(v); }
    static string BatteryHealth(string v) { if (v == "2") return "正常"; if (v == "3") return "过热"; if (v == "4") return "损坏"; if (v == "5") return "过压"; if (v == "7") return "过冷"; return Clean(v); }
    static string PowerSource(string s) { if (FindLine(s, "AC powered:").EndsWith("true")) return "AC"; if (FindLine(s, "USB powered:").EndsWith("true")) return "USB"; if (FindLine(s, "Wireless powered:").EndsWith("true")) return "无线"; return "未供电"; }
    static string AfterColon(string text, string key) { foreach (string raw in Lines(text)) { string l = raw.Trim(); if (l.StartsWith(key + ":", StringComparison.OrdinalIgnoreCase)) return Clean(l.Substring(key.Length + 1)); } return "-"; }
    static string AfterEquals(string text, string key) { foreach (string raw in Lines(text)) { string l = raw.Trim(); int p = l.IndexOf(key + "=", StringComparison.Ordinal); if (p >= 0) { string rest = l.Substring(p + key.Length + 1); int comma = rest.IndexOf(','); return Clean(comma >= 0 ? rest.Substring(0, comma) : rest); } } return "-"; }
    static string FindLine(string text, string needle) { foreach (string raw in Lines(text)) { string l = raw.Trim(); if (l.IndexOf(needle, StringComparison.OrdinalIgnoreCase) >= 0) return Clean(l); } return "-"; }
    static string Field(string line, string key) { string marker = key + ":"; int p = line.IndexOf(marker, StringComparison.OrdinalIgnoreCase); if (p < 0) return "-"; string rest = line.Substring(p + marker.Length).Trim(); int comma = rest.IndexOf(','); return Clean(comma >= 0 ? rest.Substring(0, comma) : rest); }
    static string FindPackageField(string text, string key) { foreach (string raw in Lines(text)) { string l = raw.Trim(); int p = l.IndexOf(key, StringComparison.OrdinalIgnoreCase); if (p >= 0) return Clean(l.Substring(p + key.Length)); } return "-"; }
    static string MemGb(string text, string key) { foreach (string raw in Lines(text)) { string l = raw.Trim(); if (!l.StartsWith(key, StringComparison.OrdinalIgnoreCase)) continue; string[] p = l.Split(new char[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries); double kb; if (p.Length >= 2 && double.TryParse(p[1], NumberStyles.Any, CultureInfo.InvariantCulture, out kb)) return (kb / 1048576.0).ToString("0.#", CultureInfo.InvariantCulture) + " GB"; } return "-"; }
    static string PropFrom(string text, string key)
    {
        foreach (string raw in Lines(text))
        {
            string l = raw.Trim();
            string prefix = "[" + key + "]: [";
            if (l.StartsWith(prefix, StringComparison.Ordinal)) return Clean(l.Substring(prefix.Length).TrimEnd(']'));
            if (l.StartsWith(key + "=", StringComparison.Ordinal)) return Clean(l.Substring(key.Length + 1));
        }
        return "-";
    }
    static string FirstLine(string text) { foreach (string raw in Lines(text)) { string l = Clean(raw); if (l != "-") return l; } return "-"; }
    static string Between(string text, string left, string right)
    {
        int p = (text ?? "").IndexOf(left, StringComparison.OrdinalIgnoreCase);
        if (p < 0) return "-";
        p += left.Length;
        int e = text.IndexOf(right, p, StringComparison.OrdinalIgnoreCase);
        if (e < 0) return Clean(text.Substring(p));
        return Clean(text.Substring(p, e - p));
    }
    static string RegexValue(string text, string pattern)
    {
        Match m = Regex.Match(text ?? "", pattern, RegexOptions.IgnoreCase);
        return m.Success && m.Groups.Count > 1 ? Clean(m.Groups[1].Value) : "-";
    }
    static string FirstRegex(string text, string pattern) { return RegexValue(text, pattern); }
    static string ExtractJsonish(string text, string key)
    {
        string v = ExtractJsonishRaw(text, key);
        if (v != "-") return v;
        string normalized = NormalizeEmbeddedJson(text);
        if (!object.ReferenceEquals(normalized, text)) return ExtractJsonishRaw(normalized, key);
        return "-";
    }
    static string ExtractJsonishRaw(string text, string key)
    {
        Match m = Regex.Match(text ?? "", "\\\"" + Regex.Escape(key) + "\\\"\\s*:\\s*\\\"([^\\\"]*)\\\"", RegexOptions.IgnoreCase);
        if (m.Success) return Clean(m.Groups[1].Value);
        m = Regex.Match(text ?? "", "\\\"" + Regex.Escape(key) + "\\\"\\s*:\\s*([^,}\\s]+)", RegexOptions.IgnoreCase);
        return m.Success ? Clean(m.Groups[1].Value.Trim('"')) : "-";
    }
    static string NormalizeEmbeddedJson(string text)
    {
        string s = text ?? "";
        for (int i = 0; i < 2 && s.IndexOf("\\\"", StringComparison.Ordinal) >= 0; i++) s = s.Replace("\\\"", "\"");
        return s;
    }
    static string StorageSummary(string df)
    {
        foreach (string raw in Lines(df))
        {
            string l = raw.Trim();
            if (l.Length == 0 || l.StartsWith("Filesystem", StringComparison.OrdinalIgnoreCase)) continue;
            string[] p = l.Split(new char[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            if (p.Length >= 6 && (p[p.Length - 1] == "/data" || p[p.Length - 1].IndexOf("/storage", StringComparison.OrdinalIgnoreCase) >= 0)) return p[2] + " / " + p[1] + " used " + p[4];
        }
        return "-";
    }
    static string MemorySummary(string mem)
    {
        string total = MemGb(mem, "MemTotal:"), avail = MemGb(mem, "MemAvailable:");
        if (total == "-" && avail == "-") return "-";
        return "可用 " + avail + " / 总计 " + total;
    }
    static string CpuSummary(string cpu)
    {
        int processors = CountPrefixLines(cpu, "processor");
        string part = RegexValue(cpu, @"CPU part\s*:\s*(0x[0-9a-fA-F]+)");
        if (processors == 0 && part == "-") return "-";
        return processors.ToString(CultureInfo.InvariantCulture) + " cores / " + part;
    }
    static string DisplaySummary(string display)
    {
        string line = FindLine(display, "DisplayDeviceInfo");
        string res = RegexValue(line, @"(\d{3,5}\s*x\s*\d{3,5})");
        string fps = RegexValue(line, @"renderFrameRate\s+([0-9.]+)");
        string density = RegexValue(line, @"density\s+([0-9]+)");
        string modes = CountRegex(line, @"id=\d+,\s*width=").ToString(CultureInfo.InvariantCulture);
        List<string> p = new List<string>();
        if (res != "-") p.Add(res.Replace(" ", ""));
        if (fps != "-") p.Add(fps + "Hz");
        if (density != "-") p.Add("density " + density);
        if (modes != "0") p.Add(modes + " modes");
        return p.Count == 0 ? "-" : string.Join(" / ", p.ToArray());
    }
    static string ThermalSummary(string thermal)
    {
        string status = AfterColon(thermal, "Thermal Status");
        string ready = AfterColon(thermal, "HAL Ready");
        string battery = FirstRegex(thermal, @"mName=battery,\s*mValue=([0-9.]+)");
        List<string> p = new List<string>();
        if (status != "-") p.Add("status " + status);
        if (ready != "-") p.Add("HAL " + ready);
        if (battery != "-") p.Add("battery " + battery + "C");
        return p.Count == 0 ? "-" : string.Join(" / ", p.ToArray());
    }
    static string UsbSummary(string usb)
    {
        string connected = RegexValue(usb, @"connected=([a-z]+)");
        string configured = RegexValue(usb, @"configured=([a-z]+)");
        string functions = RegexValue(usb, @"mCurrentFunctions=([^\n\r]+)");
        List<string> p = new List<string>();
        if (connected != "-") p.Add("connected " + connected);
        if (configured != "-") p.Add("configured " + configured);
        if (functions != "-") p.Add(functions);
        return p.Count == 0 ? "-" : string.Join(" / ", p.ToArray());
    }
    static string WifiSummary(string wifi, string ipAddr)
    {
        string standard = RegexValue(wifi, @"standard:\s*([0-9A-Za-z ._-]+)");
        string freq = RegexValue(wifi, @"Frequency:\s*([0-9]+)");
        string speed = RegexValue(wifi, @"Link speed:\s*([0-9]+)");
        string rssi = RegexValue(wifi, @"RSSI:\s*(-?[0-9]+)");
        string ip = RegexValue(ipAddr, @"inet\s+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)");
        List<string> p = new List<string>();
        if (ip != "-") p.Add("IP " + ip);
        if (standard != "-") p.Add("standard " + standard);
        if (freq != "-") p.Add(freq + "MHz");
        if (speed != "-") p.Add(speed + "Mbps");
        if (rssi != "-") p.Add("RSSI " + rssi);
        return p.Count == 0 ? "-" : string.Join(" / ", p.ToArray());
    }
    static string BluetoothSummary(string bt)
    {
        string enabled = RegexValue(bt, @"enabled:\s*([a-z]+)");
        string state = RegexValue(bt, @"state:\s*([A-Z_]+)");
        if (enabled == "-" && state == "-") return FindLine(bt, "Bluetooth Status");
        return "enabled " + enabled + " / " + state;
    }
    static string CameraSummary(string camera, string sensor)
    {
        int devices = CountRegex(camera, @"CameraDeviceClient|Camera\s+ID|== Camera device");
        string normalizedSensor = NormalizeEmbeddedJson(sensor);
        int og = CountRegex(normalizedSensor, @"""SensorType""\s*:\s*""OG01A""");
        int ov = CountRegex(normalizedSensor, @"""SensorType""\s*:\s*""OV7251""");
        int imx = CountRegex(normalizedSensor, @"""SensorType""\s*:\s*""IMX471""");
        List<string> p = new List<string>();
        if (devices > 0) p.Add(devices + " camera entries");
        if (og + ov + imx > 0) p.Add("cal sensors OG01A " + og + " / OV7251 " + ov + " / IMX471 " + imx);
        return p.Count == 0 ? "-" : string.Join(" / ", p.ToArray());
    }
    static string FactorySummary(string sensor)
    {
        string device = ExtractJsonish(sensor, "DeviceType");
        string build = ExtractJsonish(sensor, "BuildType");
        string ts = ExtractJsonish(sensor, "Timestamp");
        string loc = ExtractJsonish(sensor, "location_id");
        string station = ExtractJsonish(sensor, "station_id");
        List<string> p = new List<string>();
        if (device != "-") p.Add(device);
        if (build != "-") p.Add(build);
        if (ts != "-") p.Add("Factory " + ts);
        if (loc != "-") p.Add("loc " + loc);
        if (station != "-") p.Add("station " + station);
        return p.Count == 0 ? "-" : string.Join(" / ", p.ToArray());
    }
    static string VirtualDesktopSummary(string text)
    {
        if (text.IndexOf("Package [VirtualDesktop.Android]", StringComparison.OrdinalIgnoreCase) < 0) return "-";
        string version = FindPackageField(text, "versionName=");
        return "VirtualDesktop.Android" + (version == "-" ? "" : " / " + version);
    }
    static int CountPackageLines(string text) { int n = 0; foreach (string raw in Lines(text)) if (raw.Trim().StartsWith("package:", StringComparison.OrdinalIgnoreCase)) n++; return n; }
    static int CountPrefixLines(string text, string prefix) { int n = 0; foreach (string raw in Lines(text)) if (raw.Trim().StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) n++; return n; }
    static int CountRegex(string text, string pattern) { return Regex.Matches(text ?? "", pattern, RegexOptions.IgnoreCase).Count; }
    static string V(Dictionary<string, string> d, string key) { return d.ContainsKey(key) ? Clean(d[key]) : "-"; }
    static string H(string s) { return WebUtility.HtmlEncode(Clean(s)); }
    static string Privacy(string text, bool safe) { return safe ? RedactLoose(text) : Clean(text); }
    static string AdbSourceLabel(string path)
    {
        string p = Clean(path);
        if (p == "-") return p;
        if (p.IndexOf("VIVE Business Streaming", StringComparison.OrdinalIgnoreCase) >= 0) return "VIVE Business Streaming ADB";
        if (p.IndexOf("Android", StringComparison.OrdinalIgnoreCase) >= 0 && p.IndexOf("platform-tools", StringComparison.OrdinalIgnoreCase) >= 0) return "Android platform-tools ADB";
        if (p.EndsWith("adb.exe", StringComparison.OrdinalIgnoreCase) || p.EndsWith("adb", StringComparison.OrdinalIgnoreCase)) return "ADB executable";
        if (p.Length <= 52) return p;
        return p;
    }
    static string RedactLoose(string text)
    {
        string s = Redact(text, null);
        s = Regex.Replace(s, @"\b[A-Z0-9]{12,20}\b", delegate(Match m)
        {
            string v = m.Value;
            if (Regex.IsMatch(v, @"[A-Z]") && Regex.IsMatch(v, @"[0-9]")) return SerialMask(v);
            return v;
        });
        return s;
    }
    static string Redact(string text, Snapshot snap)
    {
        string s = Clean(text);
        if (snap != null && !string.IsNullOrEmpty(snap.Serial) && snap.Serial != "-") s = s.Replace(snap.Serial, SerialMask(snap.Serial));
        s = Regex.Replace(s, @"\b([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b", "**:**:**:**:**:**");
        s = Regex.Replace(s, @"\b192\.168\.\d{1,3}\.\d{1,3}\b", "192.168.x.x");
        s = Regex.Replace(s, @"\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b", "10.x.x.x");
        s = Regex.Replace(s, @"\b172\.(1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3}\b", "172.x.x.x");
        s = Regex.Replace(s, @"(SSID|BSSID|WifiSsid|mWifiInfo)[^,\n\r]*", "$1=<redacted>", RegexOptions.IgnoreCase);
        s = Regex.Replace(s, @"ro\.build\.fingerprint\]: \[[^\]\n\r]+", "ro.build.fingerprint]: [<redacted>", RegexOptions.IgnoreCase);
        s = Regex.Replace(s, @"fingerprint=[^,\n\r]+", "fingerprint=<redacted>", RegexOptions.IgnoreCase);
        s = Regex.Replace(s, @"os_fingerprint[^,\n\r\\}]+", "os_fingerprint=<redacted>", RegexOptions.IgnoreCase);
        s = Regex.Replace(s, @"session_id[^,\n\r\\}]+", "session_id=<redacted>", RegexOptions.IgnoreCase);
        return s;
    }
    static string SerialMask(string serial)
    {
        if (string.IsNullOrEmpty(serial) || serial.Length < 6) return "<serial>";
        return serial.Substring(0, 3) + "***" + serial.Substring(serial.Length - 3);
    }
    static string Clean(string s) { if (s == null) return "-"; s = s.Replace("\r", "").Trim(); return s.Length == 0 ? "-" : s; }
    static string[] Lines(string s) { return (s ?? "").Replace("\r", "").Split('\n'); }
    static bool ValidNs(string ns) { return ns == "global" || ns == "system" || ns == "secure"; }
    static bool SafeName(string name) { if (string.IsNullOrEmpty(name)) return false; foreach (char c in name) if (!(char.IsLetterOrDigit(c) || c == '_' || c == '.' || c == '-')) return false; return true; }
    static bool DangerousAction(string action)
    {
        return action == "debug_mode" || action == "keep_awake" || action == "wireless" || action == "wireless_off" ||
               action == "prox_close" || action == "screen_24h" || action == "stay_usb_ac" ||
               action == "restore_backup" || action == "custom_setting" || action == "custom_broadcast";
    }
    static bool DeniedSetting(string key)
    {
        string k = (key ?? "").ToLowerInvariant();
        return k == "adb_enabled" || k == "adb_wifi_enabled" || k == "development_settings_enabled" ||
               k == "device_provisioned" || k == "user_setup_complete" || k == "wifi_on" ||
               k == "airplane_mode_on" || k == "http_proxy" || k == "global_http_proxy" ||
               k == "install_non_market_apps" || k == "verifier_verify_adb_installs";
    }
    static string ShellQuote(string value) { return "'" + (value ?? "").Replace("'", "'\\''") + "'"; }
    static Dictionary<string, string> Ok() { Dictionary<string, string> d = new Dictionary<string, string>(); d["ok"] = "true"; return d; }
    static Dictionary<string, string> Error(string msg) { Dictionary<string, string> d = Ok(); d["ok"] = "false"; d["error"] = msg; return d; }
    static bool CheckToken(string q) { return Query(q, "token") == Token; }
    static string Query(string query, string key) { if (query.StartsWith("?")) query = query.Substring(1); foreach (string part in query.Split('&')) { int eq = part.IndexOf('='); string k = eq >= 0 ? part.Substring(0, eq) : part; string v = eq >= 0 ? part.Substring(eq + 1) : ""; if (Url(k) == key) return Url(v); } return ""; }
    static string Url(string s) { return Uri.UnescapeDataString((s ?? "").Replace("+", " ")); }
    static void WriteJson(Stream s, Dictionary<string, string> d) { WriteBytes(s, "application/json; charset=utf-8", Encoding.UTF8.GetBytes(Json(d))); }
    static void WriteBytes(Stream stream, string type, byte[] body) { string head = "HTTP/1.1 200 OK\r\nContent-Type: " + type + "\r\nContent-Length: " + body.Length + "\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"; byte[] h = Encoding.ASCII.GetBytes(head); stream.Write(h, 0, h.Length); stream.Write(body, 0, body.Length); }
    static string Json(Dictionary<string, string> d) { StringBuilder sb = new StringBuilder("{"); bool first = true; foreach (KeyValuePair<string, string> kv in d) { if (!first) sb.Append(","); first = false; sb.Append("\"").Append(Esc(kv.Key)).Append("\":\"").Append(Esc(kv.Value)).Append("\""); } return sb.Append("}").ToString(); }
    static string Esc(string s) { StringBuilder sb = new StringBuilder(); foreach (char c in s ?? "") { if (c == '\\') sb.Append("\\\\"); else if (c == '"') sb.Append("\\\""); else if (c == '\n') sb.Append("\\n"); else if (c == '\r') sb.Append("\\r"); else if (c == '\t') sb.Append("\\t"); else if (c < 32) sb.Append("\\u").Append(((int)c).ToString("x4")); else sb.Append(c); } return sb.ToString(); }

    static string Html()
    {
        string b64 =
__HTML_BASE64_LINES__
        ;
        return Encoding.UTF8.GetString(Convert.FromBase64String(b64)).Replace("[[TOKEN]]", Token);
    }
}
