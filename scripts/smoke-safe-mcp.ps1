param(
  [string]$Python = 'python',
  [switch]$LiveAdb,
  [int]$TimeoutSeconds = 45
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$server = Join-Path $root 'mcp\quest_adb_safe_mcp.py'
$venv = Join-Path $root '.venv-mcp'
$pythonExe = Join-Path $venv 'Scripts\python.exe'

if (!(Test-Path -LiteralPath $pythonExe)) {
  & $Python -m venv $venv
}

$needInstall = $false
& $pythonExe -c "import mcp, mcp.client.stdio, mcp.server.fastmcp" >$null 2>$null
if ($LASTEXITCODE -ne 0) {
  $needInstall = $true
}
if ($needInstall) {
  $pipOut = Join-Path $env:TEMP ('quest_adb_safe_mcp_pip_' + [guid]::NewGuid().ToString('N') + '.out')
  $pipErr = Join-Path $env:TEMP ('quest_adb_safe_mcp_pip_' + [guid]::NewGuid().ToString('N') + '.err')
  try {
    $pip = Start-Process -FilePath $pythonExe -ArgumentList @('-m', 'pip', 'install', '--disable-pip-version-check', '-q', '-r', (Join-Path $root 'mcp\requirements.txt')) -NoNewWindow -RedirectStandardOutput $pipOut -RedirectStandardError $pipErr -PassThru
    if (!$pip.WaitForExit([Math]::Max(30, $TimeoutSeconds) * 1000)) {
      try { $pip.Kill($true) } catch { try { $pip.Kill() } catch {} }
      $outText = if (Test-Path -LiteralPath $pipOut) { Get-Content -LiteralPath $pipOut -Raw -ErrorAction SilentlyContinue } else { '' }
      $errText = if (Test-Path -LiteralPath $pipErr) { Get-Content -LiteralPath $pipErr -Raw -ErrorAction SilentlyContinue } else { '' }
      throw "pip install for Safe MCP timed out after $([Math]::Max(30, $TimeoutSeconds)) seconds.`nSTDOUT:`n$outText`nSTDERR:`n$errText"
    }
    if ($pip.ExitCode -ne 0) {
      $errText = if (Test-Path -LiteralPath $pipErr) { Get-Content -LiteralPath $pipErr -Raw -ErrorAction SilentlyContinue } else { '' }
      throw "pip install for Safe MCP failed with exit code $($pip.ExitCode).`nSTDERR:`n$errText"
    }
  }
  finally {
    Remove-Item -LiteralPath $pipOut,$pipErr -Force -ErrorAction SilentlyContinue
  }
}

$test = @'
import asyncio
import json
import os
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

server = Path(sys.argv[1])
live = sys.argv[2].lower() == "true"
python = sys.executable

async def main():
    params = StdioServerParameters(
        command=python,
        args=[str(server)],
        env={**os.environ, "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8"},
    )
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            names = sorted(t.name for t in tools.tools)
            required = {
                "safety_policy",
                "find_adb",
                "list_devices",
                "read_device_status",
                "run_safe_capture",
                "export_readonly_snapshot",
            }
            missing = sorted(required.difference(names))
            if missing:
                raise SystemExit(f"Missing MCP tools: {missing}")
            policy = await session.call_tool("safety_policy", {})
            devices = await session.call_tool("list_devices", {})
            result = {
                "tool_count": len(names),
                "tools": names,
                "policy_ok": not getattr(policy, "isError", False),
                "devices_ok": not getattr(devices, "isError", False),
            }
            if live:
                status = await session.call_tool("read_device_status", {})
                result["live_status_ok"] = not getattr(status, "isError", False)
            print(json.dumps(result, ensure_ascii=False, indent=2))

asyncio.run(main())
'@

$tmp = Join-Path $env:TEMP ('quest_adb_safe_mcp_smoke_' + [guid]::NewGuid().ToString('N') + '.py')
$stdout = $null
$stderr = $null
try {
  Set-Content -LiteralPath $tmp -Value $test -Encoding UTF8
  $stdout = Join-Path $env:TEMP ('quest_adb_safe_mcp_smoke_' + [guid]::NewGuid().ToString('N') + '.out')
  $stderr = Join-Path $env:TEMP ('quest_adb_safe_mcp_smoke_' + [guid]::NewGuid().ToString('N') + '.err')
  $proc = Start-Process -FilePath $pythonExe -ArgumentList @($tmp, $server, ([bool]$LiveAdb).ToString().ToLowerInvariant()) -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
  if (!$proc.WaitForExit([Math]::Max(5, $TimeoutSeconds) * 1000)) {
    try { $proc.Kill($true) } catch { try { $proc.Kill() } catch {} }
    $outText = if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue } else { '' }
    $errText = if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue } else { '' }
    throw "Safe MCP smoke timed out after $TimeoutSeconds seconds.`nSTDOUT:`n$outText`nSTDERR:`n$errText"
  }
  $proc.Refresh()
  if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Raw }
  $exitCode = if ($null -eq $proc.ExitCode) { 0 } else { $proc.ExitCode }
  if ($exitCode -ne 0) {
    $errText = if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue } else { '' }
    throw "Safe MCP smoke failed with exit code $exitCode.`nSTDERR:`n$errText"
  }
}
finally {
  Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  if ($stdout) { Remove-Item -LiteralPath $stdout -Force -ErrorAction SilentlyContinue }
  if ($stderr) { Remove-Item -LiteralPath $stderr -Force -ErrorAction SilentlyContinue }
}
