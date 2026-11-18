# bypass-lists — Списки для умного обхода блокировок (Smart RU)

Готовые списки маршрутизации, автообновляемые конфиги и одноразовые `.bat`-скрипты для **Happ**, **v2RayTun** и **AmneziaVPN**.

## Как это работает

* **Через VPN (`Proxy`):**
  * **ИИ и разработка:** Gemini / AI Studio / NotebookLM (`geosite:google-deepmind`), весь Google, ChatGPT, Claude, Copilot, Perplexity, Cursor, Midjourney (`geosite:category-ai-!cn`), Figma, NVIDIA, GitHub, JetBrains, Canva, Notion, Adobe, Autodesk.
  * **Заблокированные в РФ и соцсети:** YouTube, Discord (включая голосовые UDP-серверы `66.22.192.0/18`), Telegram, Instagram, X (Twitter), TikTok, Spotify, Netflix, Patreon и реестр РКН + `re:filter` / `antifilter`.
* **Напрямую мимо VPN (`Direct`):**
  * **Dota 2 и Steam:** свежий пул игровых релеев Valve (`ISteamApps/GetSDRConfig/v1/?appid=570` + суперсети `AS32590`) и `geosite:steam` — пинг остаётся родным даже в режиме `TUN`.
  * **Весь остальной интернет:** российские сайты, банки, Госуслуги, торренты и любой обычный трафик идут напрямую без просадки скорости.

---

## Быстрый старт (готовые файлы в `dist/`)

Если ничего не хочется запускать — просто бери уже собранные файлы из папки [`dist/`](dist/):

| Клиент | Устройство | Готовый файл / ссылка |
|---|---|---|
| **Happ** | ПК (Windows) и Android | [`dist/happ/pc_android_deeplink.txt`](dist/happ/pc_android_deeplink.txt) / [`pc_android.json`](dist/happ/pc_android.json) |
| **Happ** | iPhone (iOS, облегчённый) | [`dist/happ/iphone_lite_deeplink.txt`](dist/happ/iphone_lite_deeplink.txt) / [`iphone_lite.json`](dist/happ/iphone_lite.json) |
| **v2RayTun** | ПК / Android / iPhone (диплинк) | [`dist/v2raytun/deeplink.txt`](dist/v2raytun/deeplink.txt) |
| **v2RayTun** | ПК / Android / iPhone (полный JSON) | [`dist/v2raytun/routing_full.json`](dist/v2raytun/routing_full.json) (компактный: [`routing_compact.json`](dist/v2raytun/routing_compact.json)) |
| **AmneziaVPN** | ПК / Android / iPhone (JSON) | [`dist/amnezia/amnezia_blocked_ips.json`](dist/amnezia/amnezia_blocked_ips.json) (текст: [`amnezia_blocked_ips.txt`](dist/amnezia/amnezia_blocked_ips.txt)) |

---

## Однокликовые батники для ПК (можно кидать другу в Telegram по одному)

Все `.bat`-файлы в [`scripts/`](scripts/) **полностью автономны** — внутри них зашит собственный PowerShell-код, так что другу можно переслать даже один конкретный `.bat` без остального репозитория:

* [`scripts/setup_happ.bat`](scripts/setup_happ.bat) — собирает свежие релеи Dota 2, копирует ссылку в буфер, запускает **Happ** с авто-активацией профиля (`happ://routing/onadd/...`) и сохраняет рядом ссылки для ПК/Android и iPhone.
* [`scripts/setup_v2raytun.bat`](scripts/setup_v2raytun.bat) — собирает пул Dota 2 + `re:filter community`, импортирует правила в **v2RayTun** через `v2rayTun://import_route/...` и копирует полный JSON в буфер обмена.
* [`scripts/make_amnezia_iplist.bat`](scripts/make_amnezia_iplist.bat) — собирает оптимизированный `amnezia_blocked_ips.json` (~1 160+ подсетей без Valve `AS32590`) для быстрого импорта в **AmneziaVPN** без зависаний.
* [`update_all.bat`](update_all.bat) — запускает [`scripts/build-all.ps1`](scripts/build-all.ps1) и одним кликом пересобирает все файлы в `dist/` с учётом твоих правок в `custom/`.

---

## Инструкции по клиентам

### ПК (Windows)
* **Happ:** запусти [`scripts/setup_happ.bat`](scripts/setup_happ.bat) и в самом Happ нажми **Выкл/Вкл (Reconnect)**.
  * Для браузера (Gemini, YouTube) и Dota 2 достаточно режима **System Proxy**.
  * Для десктопного **Discord с голосом** переключи Happ в режим **`TUN`** (от имени Администратора) — Дота всё равно пойдёт напрямую через правила `DirectIp`.
* **v2RayTun:** запусти [`scripts/setup_v2raytun.bat`](scripts/setup_v2raytun.bat) и подтверди импорт (или в v2RayTun: **Настройки → Маршрутизация → `⋮` → Импорт из буфера**).
* **AmneziaVPN:**
  1. Отключи VPN в AmneziaVPN.
  2. Открой **Настройки ⚙️ → Соединение → Раздельное туннелирование сайтов**.
  3. Включи тумблер и выбери **«Только адреса из списка должны открываться через VPN»**.
  4. Нажми **Импорт → Заменить список сайтов** и выбери [`dist/amnezia/amnezia_blocked_ips.json`](dist/amnezia/amnezia_blocked_ips.json) (или сгенерированный через [`scripts/make_amnezia_iplist.bat`](scripts/make_amnezia_iplist.bat)).
  5. Убедись, что в **Настройки ⚙️ → DNS** стоят `1.1.1.1` и `8.8.8.8`, и подключись.

### Телефоны (Android и iPhone)
Удобнее всего переслать нужное содержимое из `dist/` себе или другу в **Избранное Telegram**:

* **Happ (Android):** скопируй строку `happ://routing/onadd/...` из [`dist/happ/pc_android_deeplink.txt`](dist/happ/pc_android_deeplink.txt) → в Happ нажми **`+` → Вставить из буфера обмена** → переподключи VPN.
* **Happ (iPhone):** у iOS жёсткий системный лимит **50 МБ ОЗУ** на сетевой туннель, поэтому используй именно облегчённую ссылку из [`dist/happ/iphone_lite_deeplink.txt`](dist/happ/iphone_lite_deeplink.txt) (она тянет лёгкие базы `~1.4 МБ` с JSDelivr вместо полной 88 МБ базы).
* **v2RayTun (Android и iPhone):** скопируй содержимое [`dist/v2raytun/deeplink.txt`](dist/v2raytun/deeplink.txt) (или JSON из [`dist/v2raytun/routing_full.json`](dist/v2raytun/routing_full.json)) → в v2RayTun перейди в **Настройки ⚙️ → Маршрутизация → `⋮` → Импорт из буфера обмена** → проверь, что правила включены, и переподключи VPN.
* **AmneziaVPN (Android и iPhone):** сохрани [`dist/amnezia/amnezia_blocked_ips.json`](dist/amnezia/amnezia_blocked_ips.json) на телефон *(на iPhone следи, чтобы не добавилось `.txt` в конце)* → при выключенном VPN зайди в **Настройки ⚙️ → Раздельное туннелирование сайтов** → режим **«Только адреса из списка должны открываться через VPN»** → **Импорт**.
* **Совет для Android (банки и такси):** если какое-то банковское приложение ругается просто на сам значок VPN в шторке Android, в **Happ / v2RayTun / AmneziaVPN** открой **Раздельное туннелирование приложений (Per-App Proxy)** и добавь это приложение в исключения (**Обход / Bypass**).

---

## Свои домены и IP

1. Допиши нужные домены или теги в [`custom/extra-proxy-domains.txt`](custom/extra-proxy-domains.txt) (по одному на строку, можно просто `example.com` или `geosite:...`).
2. Допиши нужные подсети в [`custom/extra-proxy-ips.txt`](custom/extra-proxy-ips.txt) (например `1.2.3.0/24`).
3. Запусти [`update_all.bat`](update_all.bat) — пересоберутся все файлы в `dist/`.
   *(Также батники из `scripts/` автоматически подхватывают `custom/`, если лежат в структуре репозитория).*

## Автообновление на GitHub

Встроенный workflow [`.github/workflows/update-lists.yml`](.github/workflows/update-lists.yml) раз в 12 часов (и по кнопке **Run workflow**) сам обновляет `dist/` на GitHub.

Чтобы залить этот репозиторий на свой GitHub (создай пустой репо на GitHub, например `bypass-lists`, без README/gitignore):

```bash
git remote add origin https://github.com/<ТВОЙ_НИК>/bypass-lists.git
git branch -M main
git push -u origin main
```
