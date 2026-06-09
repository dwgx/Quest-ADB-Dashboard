param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
$enc = New-Object System.Text.UTF8Encoding($false)

$src = Join-Path $Root 'src\QuestAdbWebUi.cs'
$html = Join-Path $Root 'src\QuestAdbWebUi.html'
$buildDir = Join-Path $Root 'build'
$buildCs = Join-Path $buildDir 'QuestAdbWebUi.build.cs'
$exe = Join-Path $buildDir 'QuestAdbWebUi.exe'
$bat = Join-Path $Root 'dist\Quest_ADB_Tools.bat'
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'

if (!(Test-Path -LiteralPath $src)) { throw "Missing source: $src" }
if (!(Test-Path -LiteralPath $html)) { throw "Missing HTML: $html" }
if (!(Test-Path -LiteralPath $bat)) { throw "Missing BAT: $bat" }
if (!(Test-Path -LiteralPath $csc)) { throw "Missing compiler: $csc" }

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

$template = [IO.File]::ReadAllText($src, $enc)
$htmlBytes = [IO.File]::ReadAllBytes($html)
$htmlB64 = [Convert]::ToBase64String($htmlBytes)
$chunks = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $htmlB64.Length; $i += 100) {
  $len = [Math]::Min(100, $htmlB64.Length - $i)
  $chunks.Add('"' + $htmlB64.Substring($i, $len) + '"')
}

$buildText = $template.Replace('__HTML_BASE64_LINES__', ($chunks -join " +`r`n"))
[IO.File]::WriteAllText($buildCs, $buildText, $enc)

& $csc /nologo /codepage:65001 /target:exe /out:$exe $buildCs
if ($LASTEXITCODE -ne 0) { throw "csc failed with exit code $LASTEXITCODE" }

$batText = [IO.File]::ReadAllText($bat, $enc)
$label = [regex]::Match($batText, '(?m)^:write_webui_payload\s*$')
if (!$label.Success) { throw 'BAT payload label not found: :write_webui_payload' }

$prefix = $batText.Substring(0, $label.Index)
$exeB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($exe))
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append($prefix)
[void]$sb.AppendLine(':write_webui_payload')
[void]$sb.AppendLine('break > "%~1"')
[void]$sb.AppendLine('>> "%~1" echo -----BEGIN CERTIFICATE-----')
for ($i = 0; $i -lt $exeB64.Length; $i += 64) {
  $len = [Math]::Min(64, $exeB64.Length - $i)
  [void]$sb.AppendLine('>> "%~1" echo ' + $exeB64.Substring($i, $len))
}
[void]$sb.AppendLine('>> "%~1" echo -----END CERTIFICATE-----')
[void]$sb.AppendLine('exit /b 0')

$newBat = ($sb.ToString()) -replace "`r?`n", "`r`n"
[IO.File]::WriteAllText($bat, $newBat, $enc)

Get-FileHash -Algorithm SHA256 -LiteralPath $bat
