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
if (-not $dir) { $dir = (Get-Location).Path }
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

function Unique-List([object[]]$Items) {
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    $list = New-Object 'System.Collections.Generic.List[string]'
    foreach ($item in $Items) {
        if ($null -ne $item) {
            $s = [string]$item
            if ($s -and $set.Add($s)) { [void]$list.Add($s) }
        }
    }
    return ,($list.ToArray())
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

function Resolve-HappExe {
    try {
        $cmd = (Get-ItemProperty -LiteralPath "Registry::HKEY_CLASSES_ROOT\happ\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
        if ($cmd) {
            if ($cmd -match '^\s*"([^"]+)"') {
                if (Test-Path $matches[1]) { return $matches[1] }
            } elseif ($cmd -match '^\s*([^\s]+)') {
                if (Test-Path $matches[1]) { return $matches[1] }
            }
        }
    } catch {}
    foreach ($cand in @(
        (Join-Path $env:ProgramFiles "FlyFrogLLC\Happ\Happ.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "FlyFrogLLC\Happ\Happ.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Happ\Happ.exe"),
        (Join-Path $env:LOCALAPPDATA "Happ\Happ.exe")
    )) {
        if ($cand -and (Test-Path $cand)) { return $cand }
    }
    return $null
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

Write-Host "[1/3] Собираем актуальные подсети релеев Dota 2 из API Steam..." -ForegroundColor Cyan

$dotaCidrs = New-Object System.Collections.Generic.List[string]
foreach ($baseCidr in @(
    "155.133.224.0/19", "162.254.192.0/21", "146.66.152.0/21",
    "185.25.180.0/22", "103.10.124.0/23", "103.28.54.0/23",
    "45.121.184.0/23", "205.196.6.0/24"
)) { [void]$dotaCidrs.Add($baseCidr) }

try {
    $sdr = Invoke-RestMethod "https://api.steampowered.com/ISteamApps/GetSDRConfig/v1/?appid=570" -TimeoutSec 12
    $extra = $sdr.pops.PSObject.Properties.Value |
        Where-Object { $_.relays -and ($_.desc -notmatch '\(China\)') } | ForEach-Object { $_.relays.ipv4 } |
        Where-Object { $_ -and $_ -match '^\d+\.\d+\.\d+\.\d+$' -and -not (Test-InValveSupernet $_) } |
        ForEach-Object { $_ -replace '\.\d+$', '.0/24' } | Sort-Object -Unique
    foreach ($c in $extra) { if (-not $dotaCidrs.Contains($c)) { [void]$dotaCidrs.Add($c) } }
    Write-Host "  -> Собрано подсетей Dota 2: $($dotaCidrs.Count)" -ForegroundColor Green
} catch {
    Write-Host "  -> API Steam недоступен, используем встроенный пул подсетей Valve ($($dotaCidrs.Count))." -ForegroundColor Yellow
}

Write-Host "[2/3] Собираем быстрый профиль Happ (базы JSDelivr ~1.4 МБ) и iPhone Lite..." -ForegroundColor Cyan
$unixTs = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
$geoIpUrl   = "https://cdn.jsdelivr.net/gh/DigneZzZ/routing@main/v2ray/geoip.dat"
$geoSiteUrl = "https://cdn.jsdelivr.net/gh/DigneZzZ/routing@main/v2ray/geosite.dat"

$mandatorySites = @(
    "geosite:google-deepmind", "geosite:ai", "geosite:youtube",
    "geosite:discord", "geosite:telegram", "geosite:whatsapp", "geosite:github",
    "geosite:banned-ru",
    "domain:google.com", "domain:googleapis.com", "domain:gstatic.com",
    "domain:instagram.com", "domain:facebook.com", "domain:x.com", "domain:twitter.com",
    "domain:tiktok.com", "domain:spotify.com", "domain:netflix.com", "domain:patreon.com",
    "domain:rutracker.org", "domain:figma.com", "domain:nvidia.com", "domain:canva.com", "domain:notion.so"
)
$optionalExtras = @(
    "domain:jetbrains.com", "domain:reddit.com", "domain:linkedin.com", "domain:grok.com", "domain:x.ai"
)

$pcSites = Unique-List ($mandatorySites + $customDomains)

$pcProfile = [ordered]@{
    Name              = "Gemini Dota2 Smart RU"
    GlobalProxy       = "false"
    UseChunkFiles     = "false"
    RemoteDnsType     = "DoH"
    RemoteDnsDomain   = "https://cloudflare-dns.com/dns-query"
    RemoteDnsIp       = "1.1.1.1"
    DomesticDnsType   = "DoH"
    DomesticDnsDomain = "https://common.dot.dns.yandex.net/dns-query"
    DomesticDnsIp     = "77.88.8.8"
    GeoIpUrl          = $geoIpUrl
    GeoSiteUrl        = $geoSiteUrl
    LastUpdated       = $unixTs
    DnsHosts          = [ordered]@{ "cloudflare-dns.com" = "1.1.1.1" }
    RouteOrder        = "block-direct-proxy"
    DirectSites       = Unique-List @("geosite:private", "geosite:steam")
    DirectIp          = Unique-List (@("geoip:private") + $dotaCidrs.ToArray())
    ProxySites        = $pcSites
    ProxyIp           = Unique-List (@("geoip:blocked-ru", "geoip:telegram", "66.22.192.0/18") + $customIps)
    BlockSites        = @()
    BlockIp           = @()
    DomainStrategy    = "IPIfNonMatch"
    FakeDns           = "false"
}

$pcLink = "happ://routing/onadd/" + [Convert]::ToBase64String($Utf8NoBom.GetBytes(($pcProfile | ConvertTo-Json -Depth 6 -Compress)))
if ($pcLink.Length -ge 2083) {
    $trimmed = New-Object 'System.Collections.Generic.List[string]'
    foreach ($s in $pcSites) { [void]$trimmed.Add($s) }
    foreach ($opt in $optionalExtras) {
        if ($pcLink.Length -lt 2083) { break }
        [void]$trimmed.Remove($opt)
        $pcProfile.ProxySites = $trimmed.ToArray()
        $pcLink = "happ://routing/onadd/" + [Convert]::ToBase64String($Utf8NoBom.GetBytes(($pcProfile | ConvertTo-Json -Depth 6 -Compress)))
    }
}

$iosCustomDomains = @($customDomains | Where-Object { $_ -notmatch '^geosite:' })
$iosCustomIps     = @($customIps     | Where-Object { $_ -notmatch '^geoip:' })

$iosProfile = [ordered]@{
    Name              = "Gemini Smart RU iPhone"
    GlobalProxy       = "false"
    UseChunkFiles     = "false"
    RemoteDnsType     = "DoH"
    RemoteDnsDomain   = "https://cloudflare-dns.com/dns-query"
    RemoteDnsIp       = "1.1.1.1"
    DomesticDnsType   = "DoH"
    DomesticDnsDomain = "https://common.dot.dns.yandex.net/dns-query"
    DomesticDnsIp     = "77.88.8.8"
    GeoIpUrl          = $geoIpUrl
    GeoSiteUrl        = $geoSiteUrl
    LastUpdated       = $unixTs
    DnsHosts          = [ordered]@{ "cloudflare-dns.com" = "1.1.1.1" }
    RouteOrder        = "block-direct-proxy"
    DirectSites       = Unique-List @("geosite:private", "geosite:ru-core", "geosite:apple-core")
    DirectIp          = @("geoip:private")
    ProxySites        = Unique-List ($mandatorySites + $iosCustomDomains)
    ProxyIp           = Unique-List (@("geoip:blocked-ru", "geoip:telegram", "66.22.192.0/18") + $iosCustomIps)
    BlockSites        = @()
    BlockIp           = @()
    DomainStrategy    = "IPIfNonMatch"
    FakeDns           = "false"
}

$iosLink = "happ://routing/onadd/" + [Convert]::ToBase64String($Utf8NoBom.GetBytes(($iosProfile | ConvertTo-Json -Depth 6 -Compress)))

[IO.File]::WriteAllText((Join-Path $dir "happ_pc_android_link.txt"), $pcLink, $Utf8NoBom)
[IO.File]::WriteAllText((Join-Path $dir "happ_pc_android.json"), (($pcProfile | ConvertTo-Json -Depth 6) -replace "`r`n", "`n"), $Utf8NoBom)
[IO.File]::WriteAllText((Join-Path $dir "happ_iphone_lite_link.txt"), $iosLink, $Utf8NoBom)
try { Set-Clipboard -Value $pcLink } catch { $pcLink | clip }

Write-Host "[3/3] Передаём профиль напрямую в Happ.exe..." -ForegroundColor Cyan
$happExe = Resolve-HappExe
try {
    if ($happExe) {
        Start-Process -FilePath $happExe -ArgumentList $pcLink
        Write-Host "  -> Запущен Happ: $happExe" -ForegroundColor DarkGray
    } else {
        Start-Process $pcLink
    }
} catch {
    Write-Host "  -> Не удалось запустить Happ автоматически: $($_.Exception.Message)" -ForegroundColor Yellow
}

Start-Sleep -Seconds 2

$routingFile = Join-Path $env:LOCALAPPDATA "Happ\routing.json"
$profileFound = $false
$hasSub = $false
if (Test-Path $routingFile) {
    try {
        $rj = ([IO.File]::ReadAllText($routingFile, $Utf8NoBom)) | ConvertFrom-Json
        if ($rj.routingNames -contains "Gemini Dota2 Smart RU") { $profileFound = $true }
        elseif ($rj.routings) {
            foreach ($r in $rj.routings) {
                if ($r.name -eq "Gemini Dota2 Smart RU" -or $r.Name -eq "Gemini Dota2 Smart RU") {
                    $profileFound = $true
                    break
                }
            }
        }
        if ($rj.subConfigs) {
            foreach ($sc in $rj.subConfigs) {
                if ($sc.subscriptionId -ne 0) { $hasSub = $true }
            }
        }
    } catch {}
}

Write-Host ""
if ($profileFound) {
    Write-Host "ПРОФИЛЬ 'Gemini Dota2 Smart RU' ДОБАВЛЕН В HAPP!" -ForegroundColor Green
} else {
    Write-Host "ССЫЛКА УЖЕ СКОПИРОВАНА В БУФЕР ОБМЕНА!" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "ЧТО СДЕЛАТЬ В HAPP:" -ForegroundColor White
Write-Host "  1) Если сервер добавлен вручную (Список серверов / vless ключ):" -ForegroundColor Gray
Write-Host "     -> Профиль применяется автоматически; просто нажми Выкл / Вкл (Reconnect) и подожди 3-5 сек скачивания баз." -ForegroundColor Gray
Write-Host "  2) Если ты сидишь через ПОДПИСКУ (SwagaVPN и т.п.):" -ForegroundColor Cyan
Write-Host "     -> Десктопный Happ игнорирует выбор подписки через диплинк." -ForegroundColor Yellow
Write-Host "     -> Открой Happ -> нажми '+' (или Маршрутизация -> '+') -> Вставить из буфера обмена -> выбери свою подписку!" -ForegroundColor Yellow
if ($hasSub) {
    Write-Host "  [!] Обнаружена активная подписка в Happ: обязательно вставь ссылку из буфера через '+'!" -ForegroundColor Magenta
}
Write-Host ""
Write-Host "Рядом сохранены: happ_pc_android_link.txt, happ_pc_android.json, happ_iphone_lite_link.txt" -ForegroundColor DarkGray
