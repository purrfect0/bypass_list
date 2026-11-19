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

function Resolve-V2RayTunExe {
    try {
        $cmd = (Get-ItemProperty -LiteralPath "Registry::HKEY_CLASSES_ROOT\v2raytun\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
        if ($cmd) {
            if ($cmd -match '^\s*"([^"]+)"') {
                if (Test-Path $matches[1]) { return $matches[1] }
            } elseif ($cmd -match '^\s*([^\s]+)') {
                if (Test-Path $matches[1]) { return $matches[1] }
            }
        }
    } catch {}
    foreach ($cand in @(
        (Join-Path ${env:ProgramFiles(x86)} "v2RayTun\v2RayTun.exe"),
        (Join-Path $env:ProgramFiles "v2RayTun\v2RayTun.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\v2RayTun\v2RayTun.exe")
    )) {
        if ($cand -and (Test-Path $cand)) { return $cand }
    }
    return $null
}

function Update-V2RayTunSharedPreferences {
    param(
        [Parameter(Mandatory = $true)][string]$SharedPrefsPath,
        [Parameter(Mandatory = $true)][string]$PresetId,
        [Parameter(Mandatory = $true)]$PresetObject
    )
    $parent = Split-Path -Parent $SharedPrefsPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $sp = [PSCustomObject]@{}
    if (Test-Path $SharedPrefsPath) {
        $rawText = [IO.File]::ReadAllText($SharedPrefsPath, $Utf8NoBom)
        if ($rawText.Trim()) {
            $sp = $rawText | ConvertFrom-Json
            [IO.File]::WriteAllText(($SharedPrefsPath + ".bak"), $rawText, $Utf8NoBom)
        }
    }

    $presetIds = New-Object 'System.Collections.Generic.List[string]'
    $existingProp = $sp.PSObject.Properties["flutter.presets"]
    if ($existingProp -and $existingProp.Value) {
        $parsedIds = if ($existingProp.Value -is [string]) {
            $existingProp.Value | ConvertFrom-Json
        } else {
            $existingProp.Value
        }
        foreach ($idItem in @($parsedIds)) {
            $idStr = [string]$idItem
            if ($idStr -and -not $presetIds.Contains($idStr)) {
                [void]$presetIds.Add($idStr)
            }
        }
    }
    if (-not $presetIds.Contains($PresetId)) {
        [void]$presetIds.Add($PresetId)
    }

    $presetsJsonStr = ConvertTo-Json -InputObject @($presetIds.ToArray()) -Compress
    $presetJsonStr  = ConvertTo-Json -InputObject $PresetObject -Depth 6 -Compress

    $sp | Add-Member -NotePropertyName "flutter.presets"                               -NotePropertyValue $presetsJsonStr -Force
    $sp | Add-Member -NotePropertyName ("flutter.preset_" + $PresetId)                 -NotePropertyValue $presetJsonStr  -Force
    $sp | Add-Member -NotePropertyName "flutter.selected_preset"                       -NotePropertyValue $PresetId       -Force
    $sp | Add-Member -NotePropertyName "flutter.settings_pref_routing_preset_enabled"  -NotePropertyValue $true           -Force
    $sp | Add-Member -NotePropertyName "flutter.settings_pref_routing_domain_strategy" -NotePropertyValue "IPIfNonMatch"  -Force

    $outJson = ConvertTo-Json -InputObject $sp -Depth 10 -Compress
    [IO.File]::WriteAllText($SharedPrefsPath, $outJson, $Utf8NoBom)
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
        Where-Object { $_.relays -and ($_.desc -notmatch '\(China\)') } | ForEach-Object { $_.relays.ipv4 } |
        Where-Object { $_ -and $_ -match '^\d+\.\d+\.\d+\.\d+$' -and -not (Test-InValveSupernet $_) } |
        ForEach-Object { $_ -replace '\.\d+$', '.0/24' } | Sort-Object -Unique
    foreach ($c in $extra) { if (-not $dotaCidrs.Contains($c)) { [void]$dotaCidrs.Add($c) } }
    Write-Host "  -> Собрано подсетей Dota 2: $($dotaCidrs.Count)" -ForegroundColor Green
} catch {
    Write-Host "  -> API Steam недоступен, используем встроенный пул Valve ($($dotaCidrs.Count))." -ForegroundColor Yellow
}

$commIps = @()
$commDomains = @()
try {
    $commIps = (Invoke-WebRequest "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/community_ips.lst" -UseBasicParsing -TimeoutSec 12).Content -split "`n" |
        ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+/\d+$' }
    $commDomains = (Invoke-WebRequest "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/community.lst" -UseBasicParsing -TimeoutSec 12).Content -split "`n" |
        ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") } |
        ForEach-Object { "domain:$_" }
    Write-Host "  -> Re:filter загружен: $($commDomains.Count) доменов, $($commIps.Count) подсетей" -ForegroundColor Green
} catch {
    Write-Host "  -> Re:filter недоступен, используем встроенные категории." -ForegroundColor Yellow
}

Write-Host "[2/3] Формируем пресет и файлы маршрутизации v2RayTun..." -ForegroundColor Cyan

$coreProxyDomains = @(
    "geosite:google-gemini", "geosite:google-deepmind", "geosite:google", "geosite:youtube", "geosite:category-ai-!cn",
    "geosite:discord", "geosite:telegram", "geosite:whatsapp",
    "geosite:instagram", "geosite:facebook", "geosite:twitter", "geosite:tiktok",
    "geosite:spotify", "geosite:netflix", "geosite:patreon", "geosite:reddit", "geosite:linkedin", "geosite:github",
    "geosite:notion", "geosite:jetbrains", "geosite:figma", "geosite:nvidia", "geosite:intel", "geosite:adobe", "geosite:autodesk",
    "domain:canva.com", "domain:canva.cn", "domain:canva-static.com",
    "domain:rutracker.org", "domain:rutor.info", "domain:nnmclub.to", "domain:flibusta.is", "domain:ficbook.net",
    "domain:jut.su", "domain:rezka.ag", "domain:hdrezka.ag", "domain:lostfilm.tv", "domain:anilibria.tv", "domain:shikimori.one",
    "domain:kemono.su", "domain:meduza.io", "domain:theins.ru", "domain:tvrain.ru", "domain:novayagazeta.ru", "domain:moscowtimes.ru",
    "domain:seasonvar.ru", "domain:4pda.to", "domain:prostovpn.org", "domain:ntc.party", "domain:x.ai", "domain:grok.com"
)

$proxyIpPool = Unique-List (@(
    "66.22.192.0/18",
    "91.108.4.0/22", "91.108.8.0/22", "91.108.12.0/22", "91.108.16.0/22",
    "91.108.20.0/22", "91.108.56.0/22", "149.154.160.0/20", "185.76.151.0/24"
) + $commIps + $customIps)

$v2tDirectDomains = @(
    "geosite:private", "geosite:steam",
    "domain:gosuslugi.ru", "domain:nalog.ru", "domain:mos.ru",
    "domain:sberbank.ru", "domain:tbank.ru", "domain:vtb.ru", "domain:alfabank.ru"
)

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
                ip          = Unique-List (@("geoip:private") + $dotaCidrs.ToArray())
                outboundTag = "direct"
            },
            [ordered]@{
                type          = "field"
                id            = "10000000-0000-4000-8000-000000000002"
                __name__      = "Direct Private & Steam Domains"
                domainMatcher = "hybrid"
                domain        = $v2tDirectDomains
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
                domain        = @($domainList)
                outboundTag   = "proxy"
            },
            [ordered]@{
                type        = "field"
                id          = "10000000-0000-4000-8000-000000000005"
                __name__    = "Proxy Discord Voice, TG & Blocked IPs"
                ip          = @($proxyIpPool)
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

$compactDomains = Unique-List ($coreProxyDomains + $customDomains)
$fullDomains    = Unique-List ($coreProxyDomains + $commDomains + $customDomains)

$presetId  = "b1ba55115700400080000000000d07a2"
$presetObj = [ordered]@{
    id          = ""
    name        = "Gemini + Dota2 (Smart RU)"
    iconUrl     = ""
    creatorName = "bypass_list"
    description = "Gemini, AI and blocked services via Proxy; Dota 2 SDR relays, Steam, RU banks and LAN via Direct."
    verified    = $false
    status      = "AVAILABLE"
    settings    = [ordered]@{
        globalProxyServerEnabled = $false
        bypassLan                = $true
        directDomains            = Unique-List (@("geoip:private") + $dotaCidrs.ToArray() + $v2tDirectDomains)
        proxyDomains             = Unique-List ($fullDomains + $proxyIpPool)
        blockDomains             = @()
    }
    isLocal     = $true
}

$compactJson   = (Build-V2RayTunObj $compactDomains) | ConvertTo-Json -Depth 6 -Compress
$fullJson      = (Build-V2RayTunObj $fullDomains)    | ConvertTo-Json -Depth 6
$presetPretty  = $presetObj | ConvertTo-Json -Depth 6
$routingHeader = 'routing: "' + [Convert]::ToBase64String($Utf8NoBom.GetBytes($compactJson)) + '"'

[IO.File]::WriteAllText((Join-Path $dir "v2raytun_preset.json"),         ($presetPretty -replace "`r`n", "`n"), $Utf8NoBom)
[IO.File]::WriteAllText((Join-Path $dir "v2raytun_routing.json"),        ($fullJson     -replace "`r`n", "`n"), $Utf8NoBom)
[IO.File]::WriteAllText((Join-Path $dir "v2raytun_routing_header.txt"), $routingHeader, $Utf8NoBom)
try { Set-Clipboard -Value $fullJson } catch { $fullJson | clip }

Write-Host "[3/3] Устанавливаем пресет 'Gemini + Dota2 (Smart RU)' в v2RayTun..." -ForegroundColor Cyan

$spPath = Join-Path $env:APPDATA "v2RayTun.net\v2RayTun\shared_preferences.json"
$v2tExe = Resolve-V2RayTunExe

$procNames = @("v2RayTun", "xraycore", "libhost")
$running = @(Get-Process -Name $procNames -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
    Write-Host "  -> Закрываем v2RayTun перед записью конфигурации..." -ForegroundColor DarkGray
    try {
        $running | Stop-Process -Force -ErrorAction Stop
        Start-Sleep -Milliseconds 900
    } catch {
        Write-Host ""
        Write-Host "[!] Не удалось закрыть v2RayTun автоматически (запущен от имени Администратора / TUN)." -ForegroundColor Yellow
        Read-Host "Закрой v2RayTun вручную (ПКМ по иконке в трее -> Выход) и нажми Enter для продолжения"
    }
}

$stillRunning = @(Get-Process -Name "v2RayTun" -ErrorAction SilentlyContinue)
if ($stillRunning.Count -gt 0) {
    Write-Host "[!] v2RayTun всё ещё запущен — запись отклонена, чтобы клиент не перезаписал файл. Закрой v2RayTun или запусти скрипт от Администратора." -ForegroundColor Red
} else {
    Update-V2RayTunSharedPreferences -SharedPrefsPath $spPath -PresetId $presetId -PresetObject $presetObj
    Write-Host "  -> Пресет записан и активирован: $spPath" -ForegroundColor Green
    if (Test-Path ($spPath + ".bak")) {
        Write-Host "  -> Резервная копия настроек: $spPath.bak" -ForegroundColor DarkGray
    }
    if ($v2tExe) {
        try {
            Start-Process -FilePath $v2tExe
            Write-Host "  -> Запущен v2RayTun: $v2tExe" -ForegroundColor DarkGray
        } catch {
            Write-Host "  -> Открой v2RayTun вручную." -ForegroundColor Yellow
        }
    }
    Write-Host ""
    Write-Host "ГОТОВО! Пресет 'Gemini + Dota2 (Smart RU)' включён в v2RayTun." -ForegroundColor Green
    Write-Host "Нажми кнопку переподключения (Выкл / Вкл) в v2RayTun, чтобы правила применились к туннелю." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Рядом сохранены: v2raytun_preset.json, v2raytun_routing.json (в буфере), v2raytun_routing_header.txt" -ForegroundColor DarkGray
