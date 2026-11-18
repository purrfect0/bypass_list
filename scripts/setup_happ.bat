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

$ExtraProxyDomains = @(
    "geosite:category-ai-!cn",
    "geosite:nvidia",
    "geosite:figma"
)
if ($customDir) {
    foreach ($d in (Read-CustomLines (Join-Path $customDir "extra-proxy-domains.txt"))) {
        $rule = if ($d -match '^(geosite|domain|full|regexp|keyword|ext):') { $d } else { "domain:$d" }
        $ExtraProxyDomains += $rule
    }
}

$ExtraProxyIps = @()
if ($customDir) {
    foreach ($ip in (Read-CustomLines (Join-Path $customDir "extra-proxy-ips.txt"))) {
        if ($ip -match '^\d+\.\d+\.\d+\.\d+/\d+$' -or $ip -match '^geoip:') {
            $ExtraProxyIps += $ip
        }
    }
}

Write-Host "[1/3] Собираем актуальные подсети релеев Dota 2 из API Steam..." -ForegroundColor Cyan

function Test-InValveSupernet([string]$ip) {
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

$dotaCidrs = New-Object System.Collections.Generic.List[string]
foreach ($baseCidr in @(
    "155.133.224.0/19", "162.254.192.0/21", "146.66.152.0/21",
    "185.25.180.0/22", "103.10.124.0/23", "103.28.54.0/23",
    "45.121.184.0/23", "205.196.6.0/24"
)) { [void]$dotaCidrs.Add($baseCidr) }

try {
    $sdr = Invoke-RestMethod "https://api.steampowered.com/ISteamApps/GetSDRConfig/v1/?appid=570" -TimeoutSec 12
    $extra = $sdr.pops.PSObject.Properties.Value |
        Where-Object { $_.relays } | ForEach-Object { $_.relays.ipv4 } |
        Where-Object { $_ -and $_ -match '^\d+\.\d+\.\d+\.\d+$' -and -not (Test-InValveSupernet $_) } |
        ForEach-Object { $_ -replace '\.\d+$', '.0/24' } | Sort-Object -Unique
    foreach ($c in $extra) { if (-not $dotaCidrs.Contains($c)) { [void]$dotaCidrs.Add($c) } }
    Write-Host "  -> Собрано подсетей Dota 2: $($dotaCidrs.Count)" -ForegroundColor Green
} catch {
    Write-Host "  -> API Steam недоступен, используем встроенный пул подсетей Valve ($($dotaCidrs.Count))." -ForegroundColor Yellow
}

Write-Host "[2/3] Собираем профили для ПК/Android и для iPhone..." -ForegroundColor Cyan
$todayUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")

$pcProfile = [ordered]@{
    Name              = "Gemini + Dota2 (PC & Android)"
    GlobalProxy       = "false"
    UseChunkFiles     = "true"
    RemoteDNSType     = "DoH"
    RemoteDNSDomain   = "https://cloudflare-dns.com/dns-query"
    RemoteDNSIP       = "1.1.1.1"
    DomesticDNSType   = "DoH"
    DomesticDNSDomain = "https://common.dot.dns.yandex.net/dns-query"
    DomesticDNSIP     = "77.88.8.8"
    Geoipurl          = "https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat"
    Geositeurl        = "https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat"
    LastUpdated       = $todayUtc
    DnsHosts          = [ordered]@{ "cloudflare-dns.com" = "1.1.1.1"; "dns.google" = "8.8.8.8" }
    RouteOrder        = "block-direct-proxy"
    DirectSites       = @("geosite:private", "geosite:steam", "geosite:ru-available-only-inside")
    DirectIp          = @("geoip:private") + $dotaCidrs.ToArray()
    ProxySites        = @(
        "geosite:google-deepmind", "geosite:google", "geosite:youtube",
        "geosite:discord", "geosite:telegram", "geosite:ru-blocked"
    ) + $ExtraProxyDomains | Select-Object -Unique
    ProxyIp           = @(
        "geoip:ru-blocked", "geoip:ru-blocked-community", "geoip:re-filter",
        "geoip:google", "geoip:telegram", "66.22.192.0/18"
    ) + $ExtraProxyIps | Select-Object -Unique
    BlockSites        = @()
    BlockIp           = @()
    DomainStrategy    = "IPIfNonMatch"
    FakeDNS           = "false"
}

$iosCustomDomains = @($ExtraProxyDomains | Where-Object { $_ -notmatch '^geosite:' })
$iosCustomIps     = @($ExtraProxyIps     | Where-Object { $_ -notmatch '^geoip:' })

$iosProfile = [ordered]@{
    Name              = "Gemini + Smart RU (iPhone)"
    GlobalProxy       = "false"
    UseChunkFiles     = "false"
    RemoteDNSType     = "DoH"
    RemoteDNSDomain   = "https://cloudflare-dns.com/dns-query"
    RemoteDNSIP       = "1.1.1.1"
    DomesticDNSType   = "DoH"
    DomesticDNSDomain = "https://common.dot.dns.yandex.net/dns-query"
    DomesticDNSIP     = "77.88.8.8"
    Geoipurl          = "https://cdn.jsdelivr.net/gh/DigneZzZ/routing@main/v2ray/geoip.dat"
    Geositeurl        = "https://cdn.jsdelivr.net/gh/DigneZzZ/routing@main/v2ray/geosite.dat"
    LastUpdated       = $todayUtc
    DnsHosts          = [ordered]@{ "cloudflare-dns.com" = "1.1.1.1" }
    RouteOrder        = "block-direct-proxy"
    DirectSites       = @("geosite:private", "geosite:ru-core", "geosite:apple-core", "geosite:google-play")
    DirectIp          = @("geoip:private")
    ProxySites        = @(
        "geosite:google-deepmind", "geosite:ai", "geosite:youtube",
        "geosite:discord", "geosite:telegram", "geosite:whatsapp", "geosite:github",
        "geosite:banned-ru", "geosite:category-geoblock-ru",
        "domain:google.com", "domain:googleapis.com", "domain:gstatic.com"
    ) + $iosCustomDomains | Select-Object -Unique
    ProxyIp           = @("geoip:blocked-ru", "geoip:telegram", "66.22.192.0/18") + $iosCustomIps | Select-Object -Unique
    BlockSites        = @()
    BlockIp           = @()
    DomainStrategy    = "IPIfNonMatch"
    FakeDNS           = "false"
}

$pcLink  = "happ://routing/onadd/" + [Convert]::ToBase64String($Utf8NoBom.GetBytes(($pcProfile  | ConvertTo-Json -Depth 6 -Compress)))
$iosLink = "happ://routing/onadd/" + [Convert]::ToBase64String($Utf8NoBom.GetBytes(($iosProfile | ConvertTo-Json -Depth 6 -Compress)))

[IO.File]::WriteAllText((Join-Path $dir "happ_pc_android_link.txt"), $pcLink,  $Utf8NoBom)
[IO.File]::WriteAllText((Join-Path $dir "happ_iphone_lite_link.txt"), $iosLink, $Utf8NoBom)
try { Set-Clipboard -Value $pcLink } catch { $pcLink | clip }

Write-Host "[3/3] Применяем профиль в Happ на этом ПК..." -ForegroundColor Cyan
try {
    Start-Process $pcLink
    Write-Host "ГОТОВО! Переподключи VPN (Выкл/Вкл) в Happ." -ForegroundColor Green
} catch {
    Write-Host "Ссылка уже в буфере обмена! Открой Happ -> '+' -> Вставить из буфера обмена." -ForegroundColor Yellow
}
Write-Host "Ссылки сохранены рядом: happ_pc_android_link.txt и happ_iphone_lite_link.txt" -ForegroundColor DarkGray
