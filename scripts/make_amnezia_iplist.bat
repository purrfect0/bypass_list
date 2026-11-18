@echo off
cls
chcp 65001 >nul
set "SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding=[Text.Encoding]::UTF8; $raw=[IO.File]::ReadAllText($env:SELF,[Text.Encoding]::UTF8); Invoke-Expression ($raw -split ('#PS'+'_START'),2)[1]"
pause
exit /b
#PS_START

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$dir = Split-Path -Parent $env:SELF
$parentDir = Split-Path -Parent $dir
$customDir = if ($parentDir) { Join-Path $parentDir "custom" } else { "" }

function Read-CustomLines([string]$Path) {
    if (-not $Path -or -not (Test-Path $Path)) { return @() }
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($line in ([IO.File]::ReadAllLines($Path, $Utf8NoBom))) {
        $t = $line.Trim()
        if ($t -and -not $t.StartsWith("#")) { [void]$items.Add($t) }
    }
    return $items.ToArray()
}

Write-Host "[1/2] Скачиваем и объединяем пулы подсетей для AmneziaVPN..." -ForegroundColor Cyan

$urls = @(
    "https://cdn.jsdelivr.net/gh/runetfreedom/russia-blocked-geoip@release/text/ru-blocked-community.txt",
    "https://cdn.jsdelivr.net/gh/runetfreedom/russia-blocked-geoip@release/text/telegram.txt",
    "https://cdn.jsdelivr.net/gh/runetfreedom/russia-blocked-geoip@release/text/twitter.txt",
    "https://cdn.jsdelivr.net/gh/runetfreedom/russia-blocked-geoip@release/text/facebook.txt",
    "https://cdn.jsdelivr.net/gh/runetfreedom/russia-blocked-geoip@release/text/netflix.txt",
    "https://cdn.jsdelivr.net/gh/runetfreedom/russia-blocked-geoip@release/text/fastly.txt",
    "https://www.cloudflare.com/ips-v4",
    "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/community_ips.lst"
)

function Test-IsValveIp([string]$cidr) {
    $ip = ($cidr -split '/')[0]
    $o = $ip.Split('.') | ForEach-Object { [int]$_ }
    if ($o[0] -eq 155 -and $o[1] -eq 133 -and $o[2] -ge 224 -and $o[2] -le 255) { return $true }
    if ($o[0] -eq 162 -and $o[1] -eq 254 -and $o[2] -ge 192 -and $o[2] -le 199) { return $true }
    if ($o[0] -eq 146 -and $o[1] -eq 66  -and $o[2] -ge 152 -and $o[2] -le 159) { return $true }
    if ($o[0] -eq 185 -and $o[1] -eq 25  -and $o[2] -ge 180 -and $o[2] -le 183) { return $true }
    if ($o[0] -eq 103 -and $o[1] -eq 10  -and $o[2] -ge 124 -and $o[2] -le 125) { return $true }
    if ($o[0] -eq 103 -and $o[1] -eq 28  -and $o[2] -ge 54  -and $o[2] -le 55)  { return $true }
    if ($o[0] -eq 45  -and $o[1] -eq 121 -and $o[2] -ge 184 -and $o[2] -le 185) { return $true }
    if ($o[0] -eq 205 -and $o[1] -eq 196 -and $o[2] -eq 6)                      { return $true }
    return $false
}

$cidrs = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($u in $urls) {
    try {
        $lines = (Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 12).Content -split "`n"
        foreach ($l in $lines) {
            $t = $l.Trim()
            if ($t -match '^\d+\.\d+\.\d+\.\d+/\d+$' -and -not (Test-IsValveIp $t)) {
                [void]$cidrs.Add($t)
            }
        }
    } catch {
        Write-Host "  [!] Пропущен недоступный источник: $u" -ForegroundColor Yellow
    }
}

try {
    $goog = (Invoke-RestMethod "https://www.gstatic.com/ipranges/goog.json" -TimeoutSec 12).prefixes |
        Where-Object { $_.ipv4Prefix } | ForEach-Object { $_.ipv4Prefix }
    foreach ($g in $goog) {
        if (-not (Test-IsValveIp $g)) { [void]$cidrs.Add($g) }
    }
} catch {}

foreach ($fixed in @("66.22.192.0/18", "1.1.1.1/32", "1.0.0.1/32", "8.8.8.8/32", "8.8.4.4/32")) {
    [void]$cidrs.Add($fixed)
}
if ($customDir) {
    foreach ($c in (Read-CustomLines (Join-Path $customDir "extra-proxy-ips.txt"))) {
        if ($c -match '^\d+\.\d+\.\d+\.\d+/\d+$') { [void]$cidrs.Add($c) }
    }
}

Write-Host "[2/2] Сохраняем JSON в формате AmneziaVPN ($($cidrs.Count) подсетей)..." -ForegroundColor Cyan

$sorted = @($cidrs | Sort-Object)
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("[`n")
for ($i = 0; $i -lt $sorted.Count; $i++) {
    $comma = if ($i -lt $sorted.Count - 1) { "," } else { "" }
    [void]$sb.Append("  {`"hostname`": `"$($sorted[$i])`", `"ip`": `"`"}$comma`n")
}
[void]$sb.Append("]")

$outJson = Join-Path $dir "amnezia_blocked_ips.json"
$outTxt  = Join-Path $dir "amnezia_blocked_ips.txt"
[IO.File]::WriteAllText($outJson, $sb.ToString(), $Utf8NoBom)
[IO.File]::WriteAllText($outTxt, ($sorted -join "`n"), $Utf8NoBom)

Write-Host "ГОТОВО! Создан файл: $outJson ($($sorted.Count) подсетей)" -ForegroundColor Green
Write-Host "Также рядом сохранен обычный текстовый список: $outTxt" -ForegroundColor DarkGray
