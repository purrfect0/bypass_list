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

$customDomains = @(
    if ($customDir) {
        foreach ($d in (Read-CustomLines (Join-Path $customDir "extra-proxy-domains.txt"))) {
            if ($d -match '^(geosite|domain|full|regexp|keyword|ext):') { $d } else { "domain:$d" }
        }
    }
)
$customIps = @(
    if ($customDir) {
        foreach ($ip in (Read-CustomLines (Join-Path $customDir "extra-proxy-ips.txt"))) {
            if ($ip -match '^\d+\.\d+\.\d+\.\d+/\d+$' -or $ip -match '^geoip:') { $ip }
        }
    }
)

Write-Host "[1/3] Получаем подсети серверов Dota 2 и заблокированных сервисов..." -ForegroundColor Cyan

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
} catch {}

$commIps = @()
$commDomains = @()
try {
    $commIps = (Invoke-WebRequest "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/community_ips.lst" -UseBasicParsing -TimeoutSec 12).Content -split "`n" |
        ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+/\d+$' }
    $commDomains = (Invoke-WebRequest "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/community.lst" -UseBasicParsing -TimeoutSec 12).Content -split "`n" |
        ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") } |
        ForEach-Object { "domain:$_" }
} catch {}

Write-Host "[2/3] Собираем маршрутизацию для v2RayTun..." -ForegroundColor Cyan

$coreProxyDomains = @(
    "geosite:google-deepmind", "geosite:google", "geosite:youtube", "geosite:category-ai-!cn",
    "geosite:discord", "geosite:telegram", "geosite:whatsapp",
    "geosite:instagram", "geosite:facebook", "geosite:twitter", "geosite:tiktok",
    "geosite:spotify", "geosite:netflix", "geosite:patreon", "geosite:reddit", "geosite:linkedin", "geosite:github",
    "geosite:canva", "geosite:notion", "geosite:jetbrains", "geosite:figma", "geosite:nvidia", "geosite:intel", "geosite:adobe", "geosite:autodesk",
    "domain:rutracker.org", "domain:rutor.info", "domain:nnmclub.to", "domain:flibusta.is", "domain:ficbook.net",
    "domain:jut.su", "domain:rezka.ag", "domain:hdrezka.ag", "domain:lostfilm.tv", "domain:anilibria.tv", "domain:shikimori.one",
    "domain:kemono.su", "domain:meduza.io", "domain:theins.ru", "domain:tvrain.ru", "domain:novayagazeta.ru", "domain:moscowtimes.ru",
    "domain:seasonvar.ru", "domain:4pda.to", "domain:prostovpn.org", "domain:ntc.party", "domain:x.ai", "domain:grok.com"
)

$proxyIpPool = @(
    "66.22.192.0/18",
    "91.108.4.0/22", "91.108.8.0/22", "91.108.12.0/22", "91.108.16.0/22",
    "91.108.20.0/22", "91.108.56.0/22", "149.154.160.0/20", "185.76.151.0/24"
) + $commIps + $customIps | Select-Object -Unique

function Build-V2RayTunObj([string[]]$domainList) {
    return [ordered]@{
        domainStrategy = "IPIfNonMatch"
        domainMatcher  = "hybrid"
        id             = "A1B2C3D4-1111-4444-8888-0000000D07A2"
        name           = "Gemini + Dota2 (Smart RU)"
        balancers      = @()
        rules          = @(
            [ordered]@{
                type        = "field"
                id          = "10000000-0000-4000-8000-000000000001"
                __name__    = "Direct Private & Dota2 IPs"
                ip          = @("geoip:private") + $dotaCidrs.ToArray()
                outboundTag = "direct"
            },
            [ordered]@{
                type          = "field"
                id            = "10000000-0000-4000-8000-000000000002"
                __name__      = "Direct Private & Steam Domains"
                domainMatcher = "hybrid"
                domain        = @(
                    "geosite:private", "geosite:steam",
                    "domain:gosuslugi.ru", "domain:nalog.ru", "domain:mos.ru",
                    "domain:sberbank.ru", "domain:tbank.ru", "domain:vtb.ru", "domain:alfabank.ru"
                )
                outboundTag   = "direct"
            },
            [ordered]@{
                type        = "field"
                id          = "10000000-0000-4000-8000-000000000003"
                __name__    = "Direct BitTorrent"
                protocol    = @("bittorrent")
                outboundTag = "direct"
            },
            [ordered]@{
                type          = "field"
                id            = "10000000-0000-4000-8000-000000000004"
                __name__      = "Proxy Gemini, AI & Geoblocked"
                domainMatcher = "hybrid"
                domain        = $domainList
                outboundTag   = "proxy"
            },
            [ordered]@{
                type        = "field"
                id          = "10000000-0000-4000-8000-000000000005"
                __name__    = "Proxy Discord Voice, TG & Blocked IPs"
                ip          = $proxyIpPool
                outboundTag = "proxy"
            },
            [ordered]@{
                type        = "field"
                id          = "10000000-0000-4000-8000-000000000006"
                __name__    = "Direct All Other Traffic"
                port        = "0-65535"
                outboundTag = "direct"
            }
        )
    }
}

$compactDomains = @($coreProxyDomains + $customDomains | Select-Object -Unique)
$fullDomains    = @($coreProxyDomains + $commDomains + $customDomains | Select-Object -Unique)

$compactJson = (Build-V2RayTunObj $compactDomains) | ConvertTo-Json -Depth 6 -Compress
$fullJson    = (Build-V2RayTunObj $fullDomains)    | ConvertTo-Json -Depth 6

$deeplink = "v2rayTun://import_route/" + [Convert]::ToBase64String($Utf8NoBom.GetBytes($compactJson))

[IO.File]::WriteAllText((Join-Path $dir "v2raytun_deeplink.txt"), $deeplink, $Utf8NoBom)
[IO.File]::WriteAllText((Join-Path $dir "v2raytun_routing.json"), ($fullJson -replace "`r`n", "`n"), $Utf8NoBom)
try { Set-Clipboard -Value $fullJson } catch { $fullJson | clip }

Write-Host "[3/3] Импортируем правила в v2RayTun..." -ForegroundColor Cyan
try {
    Start-Process $deeplink
    Write-Host "ГОТОВО! Подтверди импорт в открывшемся окне v2RayTun и переподключи VPN." -ForegroundColor Green
} catch {
    Write-Host "Полный JSON уже в буфере! В v2RayTun зайди в: Настройки -> Маршрутизация -> три точки -> Импорт из буфера." -ForegroundColor Yellow
}
Write-Host "Рядом сохранены: v2raytun_deeplink.txt и v2raytun_routing.json" -ForegroundColor DarkGray
