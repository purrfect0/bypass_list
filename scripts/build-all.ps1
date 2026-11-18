[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $normalized = $Content -replace "`r`n", "`n"
    [IO.File]::WriteAllText($Path, $normalized, $Utf8NoBom)
}

function Read-CustomLines([string]$Path) {
    if (-not (Test-Path $Path)) { return @() }
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($line in ([IO.File]::ReadAllLines($Path, $Utf8NoBom))) {
        $t = $line.Trim()
        if ($t -and -not $t.StartsWith("#")) {
            [void]$items.Add($t)
        }
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

$RepoRoot = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }
$CustomDir = Join-Path $RepoRoot "custom"
$DistDir   = Join-Path $RepoRoot "dist"

$rawCustomDomains = Read-CustomLines (Join-Path $CustomDir "extra-proxy-domains.txt")
$customDomains = @(
    foreach ($d in $rawCustomDomains) {
        if ($d -match '^(geosite|domain|full|regexp|keyword|ext):') { $d } else { "domain:$d" }
    }
)

$rawCustomIps = Read-CustomLines (Join-Path $CustomDir "extra-proxy-ips.txt")
$customIps = @(
    foreach ($ip in $rawCustomIps) {
        if ($ip -match '^\d+\.\d+\.\d+\.\d+/\d+$' -or $ip -match '^geoip:') { $ip }
    }
)
$customRawCidrs = @($customIps | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+/\d+$' })

Write-Host "[1/4] Fetching Dota 2 SDR relay IPs from Steam API..." -ForegroundColor Cyan

$dotaCidrs = New-Object System.Collections.Generic.List[string]
foreach ($baseCidr in @(
    "155.133.224.0/19", "162.254.192.0/21", "146.66.152.0/21",
    "185.25.180.0/22", "103.10.124.0/23", "103.28.54.0/23",
    "45.121.184.0/23", "205.196.6.0/24"
)) {
    [void]$dotaCidrs.Add($baseCidr)
}

try {
    $sdr = Invoke-RestMethod "https://api.steampowered.com/ISteamApps/GetSDRConfig/v1/?appid=570" -TimeoutSec 12
    $extraRelays = $sdr.pops.PSObject.Properties.Value |
        Where-Object { $_.relays } |
        ForEach-Object { $_.relays.ipv4 } |
        Where-Object { $_ -and $_ -match '^\d+\.\d+\.\d+\.\d+$' -and -not (Test-InValveSupernet $_) } |
        ForEach-Object { $_ -replace '\.\d+$', '.0/24' } |
        Sort-Object -Unique
    foreach ($c in $extraRelays) {
        if (-not $dotaCidrs.Contains($c)) { [void]$dotaCidrs.Add($c) }
    }
    Write-Host "  -> Dota 2 CIDRs collected: $($dotaCidrs.Count)" -ForegroundColor Green
} catch {
    Write-Host "  -> Steam API unavailable, using fallback Valve AS32590 supernets ($($dotaCidrs.Count))." -ForegroundColor Yellow
}

$todayUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")

# ==============================================================================
# 1. Happ (PC / Android + iPhone Lite)
# ==============================================================================
Write-Host "[2/4] Building Happ profiles..." -ForegroundColor Cyan

$happDir = Join-Path $DistDir "happ"

$happPcAndroid = [ordered]@{
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
    DnsHosts          = [ordered]@{
        "cloudflare-dns.com" = "1.1.1.1"
        "dns.google"         = "8.8.8.8"
    }
    RouteOrder        = "block-direct-proxy"
    DirectSites       = @("geosite:private", "geosite:steam", "geosite:ru-available-only-inside")
    DirectIp          = @("geoip:private") + $dotaCidrs.ToArray()
    ProxySites        = @(
        "geosite:google-deepmind", "geosite:google", "geosite:youtube",
        "geosite:category-ai-!cn", "geosite:nvidia", "geosite:figma",
        "geosite:discord", "geosite:telegram", "geosite:ru-blocked"
    ) + $customDomains | Select-Object -Unique
    ProxyIp           = @(
        "geoip:ru-blocked", "geoip:ru-blocked-community", "geoip:re-filter",
        "geoip:google", "geoip:telegram", "66.22.192.0/18"
    ) + $customIps | Select-Object -Unique
    BlockSites        = @()
    BlockIp           = @()
    DomainStrategy    = "IPIfNonMatch"
    FakeDNS           = "false"
}

$happIosCustomDomains = @($customDomains | Where-Object { $_ -notmatch '^geosite:' })
$happIosCustomIps     = @($customIps     | Where-Object { $_ -notmatch '^geoip:' })

$happIphoneLite = [ordered]@{
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
    DnsHosts          = [ordered]@{
        "cloudflare-dns.com" = "1.1.1.1"
    }
    RouteOrder        = "block-direct-proxy"
    DirectSites       = @("geosite:private", "geosite:ru-core", "geosite:apple-core", "geosite:google-play")
    DirectIp          = @("geoip:private")
    ProxySites        = @(
        "geosite:google-deepmind", "geosite:ai", "geosite:youtube",
        "geosite:discord", "geosite:telegram", "geosite:whatsapp", "geosite:github",
        "geosite:banned-ru", "geosite:category-geoblock-ru",
        "domain:google.com", "domain:googleapis.com", "domain:gstatic.com"
    ) + $happIosCustomDomains | Select-Object -Unique
    ProxyIp           = @("geoip:blocked-ru", "geoip:telegram", "66.22.192.0/18") + $happIosCustomIps | Select-Object -Unique
    BlockSites        = @()
    BlockIp           = @()
    DomainStrategy    = "IPIfNonMatch"
    FakeDNS           = "false"
}

$pcCompactJson  = $happPcAndroid  | ConvertTo-Json -Depth 6 -Compress
$iosCompactJson = $happIphoneLite | ConvertTo-Json -Depth 6 -Compress

$pcDeeplink  = "happ://routing/onadd/" + [Convert]::ToBase64String($Utf8NoBom.GetBytes($pcCompactJson))
$iosDeeplink = "happ://routing/onadd/" + [Convert]::ToBase64String($Utf8NoBom.GetBytes($iosCompactJson))

Write-Utf8NoBom (Join-Path $happDir "pc_android.json")          ($happPcAndroid  | ConvertTo-Json -Depth 6)
Write-Utf8NoBom (Join-Path $happDir "pc_android_deeplink.txt")   $pcDeeplink
Write-Utf8NoBom (Join-Path $happDir "iphone_lite.json")         ($happIphoneLite | ConvertTo-Json -Depth 6)
Write-Utf8NoBom (Join-Path $happDir "iphone_lite_deeplink.txt")  $iosDeeplink

Write-Host "  -> Happ PC/Android deeplink length: $($pcDeeplink.Length) chars" -ForegroundColor Green

# ==============================================================================
# 2. v2RayTun
# ==============================================================================
Write-Host "[3/4] Building v2RayTun profiles..." -ForegroundColor Cyan

$v2tDir = Join-Path $DistDir "v2raytun"

$commIps = @()
$commDomains = @()
try {
    $commIps = (Invoke-WebRequest "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/community_ips.lst" -UseBasicParsing -TimeoutSec 12).Content -split "`n" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+/\d+$' }
    $commDomains = (Invoke-WebRequest "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/community.lst" -UseBasicParsing -TimeoutSec 12).Content -split "`n" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") } |
        ForEach-Object { "domain:$_" }
    Write-Host "  -> Re:filter community loaded: $($commDomains.Count) domains, $($commIps.Count) CIDRs" -ForegroundColor Green
} catch {
    Write-Host "  -> Re:filter community fetch failed, continuing with core rules." -ForegroundColor Yellow
}

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

$compactDomains = @($coreProxyDomains + $customDomains | Select-Object -Unique)
$fullDomains    = @($coreProxyDomains + $commDomains + $customDomains | Select-Object -Unique)

$proxyIpPool = @(
    "66.22.192.0/18",
    "91.108.4.0/22", "91.108.8.0/22", "91.108.12.0/22", "91.108.16.0/22",
    "91.108.20.0/22", "91.108.56.0/22", "149.154.160.0/20", "185.76.151.0/24"
) + $commIps + $customIps | Select-Object -Unique

function New-V2RayTunRouting([string[]]$domainList) {
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

$v2tCompactObj = New-V2RayTunRouting $compactDomains
$v2tFullObj    = New-V2RayTunRouting $fullDomains

$v2tCompactMin = $v2tCompactObj | ConvertTo-Json -Depth 6 -Compress
$v2tDeeplink   = "v2rayTun://import_route/" + [Convert]::ToBase64String($Utf8NoBom.GetBytes($v2tCompactMin))

Write-Utf8NoBom (Join-Path $v2tDir "routing_compact.json") ($v2tCompactObj | ConvertTo-Json -Depth 6)
Write-Utf8NoBom (Join-Path $v2tDir "routing_full.json")    ($v2tFullObj    | ConvertTo-Json -Depth 6)
Write-Utf8NoBom (Join-Path $v2tDir "deeplink.txt")         $v2tDeeplink

# ==============================================================================
# 3. AmneziaVPN
# ==============================================================================
Write-Host "[4/4] Building AmneziaVPN IP list..." -ForegroundColor Cyan

$amneziaDir = Join-Path $DistDir "amnezia"

$amneziaUrls = @(
    "https://cdn.jsdelivr.net/gh/runetfreedom/russia-blocked-geoip@release/text/ru-blocked-community.txt",
    "https://cdn.jsdelivr.net/gh/runetfreedom/russia-blocked-geoip@release/text/telegram.txt",
    "https://cdn.jsdelivr.net/gh/runetfreedom/russia-blocked-geoip@release/text/twitter.txt",
    "https://cdn.jsdelivr.net/gh/runetfreedom/russia-blocked-geoip@release/text/facebook.txt",
    "https://cdn.jsdelivr.net/gh/runetfreedom/russia-blocked-geoip@release/text/netflix.txt",
    "https://cdn.jsdelivr.net/gh/runetfreedom/russia-blocked-geoip@release/text/fastly.txt",
    "https://www.cloudflare.com/ips-v4",
    "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/community_ips.lst"
)

$amneziaSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($u in $amneziaUrls) {
    try {
        $lines = (Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 12).Content -split "`n"
        foreach ($l in $lines) {
            $t = $l.Trim()
            if ($t -match '^\d+\.\d+\.\d+\.\d+/\d+$') {
                $ipPart = ($t -split '/')[0]
                if (-not (Test-InValveSupernet $ipPart)) {
                    [void]$amneziaSet.Add($t)
                }
            }
        }
    } catch {
        Write-Host "  [!] Skipped unreachable source: $u" -ForegroundColor Yellow
    }
}

try {
    $googPrefixes = (Invoke-RestMethod "https://www.gstatic.com/ipranges/goog.json" -TimeoutSec 12).prefixes |
        Where-Object { $_.ipv4Prefix } |
        ForEach-Object { $_.ipv4Prefix }
    foreach ($g in $googPrefixes) {
        $ipPart = ($g -split '/')[0]
        if (-not (Test-InValveSupernet $ipPart)) {
            [void]$amneziaSet.Add($g)
        }
    }
} catch {
    Write-Host "  [!] Failed to fetch Google IP ranges." -ForegroundColor Yellow
}

foreach ($fixed in @("66.22.192.0/18", "1.1.1.1/32", "1.0.0.1/32", "8.8.8.8/32", "8.8.4.4/32")) {
    [void]$amneziaSet.Add($fixed)
}
foreach ($c in $customRawCidrs) {
    [void]$amneziaSet.Add($c)
}

$sortedCidrs = @($amneziaSet | Sort-Object)
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("`n")
$sb.Clear() | Out-Null
[void]$sb.Append("[`n")
for ($i = 0; $i -lt $sortedCidrs.Count; $i++) {
    $comma = if ($i -lt ($sortedCidrs.Count - 1)) { "," } else { "" }
    [void]$sb.Append("  {`"hostname`": `"$($sortedCidrs[$i])`", `"ip`": `"`"}$comma`n")
}
[void]$sb.Append("]")

Write-Utf8NoBom (Join-Path $amneziaDir "amnezia_blocked_ips.json") $sb.ToString()
Write-Utf8NoBom (Join-Path $amneziaDir "amnezia_blocked_ips.txt")  ($sortedCidrs -join "`n")

Write-Host "  -> AmneziaVPN CIDRs built: $($sortedCidrs.Count)" -ForegroundColor Green
Write-Host "DONE! All outputs written to $DistDir" -ForegroundColor Green
