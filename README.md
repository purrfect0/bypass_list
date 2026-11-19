<div align="center">

# 🛡️ bypass_list

Автообновляемые списки и однокликовые скрипты умной маршрутизации (**Split Tunneling**) для **Happ**, **v2RayTun** и **AmneziaVPN**:<br>
**Gemini, зарубежные ИИ и заблокированные сайты — через VPN; Dota 2, Steam, банки и весь остальной интернет — напрямую без потери скорости и пинга.**

[![Update Bypass Lists](https://github.com/purrfect0/bypass_list/actions/workflows/update-lists.yml/badge.svg)](https://github.com/purrfect0/bypass_list/actions/workflows/update-lists.yml)
![Clients](https://img.shields.io/badge/Clients-Happ%20%7C%20v2RayTun%20%7C%20AmneziaVPN-6E56CF?style=flat-square)
![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20Android%20%7C%20iOS-0078D4?style=flat-square)
![Auto Update](https://img.shields.io/badge/Auto--Update-Every%2012h-2EA043?style=flat-square)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

</div>

---

## ⚡ Установка на Windows в 1 команду

Для самого ленивого друга — **без ручного скачивания и предупреждений SmartScreen**. Открой PowerShell (`Win + X` → **Терминал / PowerShell**), скопируй нужную команду и нажми `Enter`:

* **Happ (ПК):**
  ```powershell
  $p="$env:TEMP\setup_happ.bat"; irm "https://raw.githubusercontent.com/purrfect0/bypass_list/main/scripts/setup_happ.bat" -OutFile $p; & $p
  ```
* **v2RayTun (ПК):**
  ```powershell
  $p="$env:TEMP\setup_v2raytun.bat"; irm "https://raw.githubusercontent.com/purrfect0/bypass_list/main/scripts/setup_v2raytun.bat" -OutFile $p; & $p
  ```

> **Важно:** после завершения скрипта нажми кнопку переподключения (**Выкл / Вкл**) в клиенте. Если в **Happ** используешь **подписку** (SwagaVPN и т.п.), диплинк в десктопе не выбирает её сам — нажми **`+` → Вставить из буфера обмена** и выбери свою подписку (ссылка уже скопирована).

---

## 📦 Готовые ссылки, списки и `.bat`-файлы

| Клиент | Устройство / примечание | Готовые ссылки и файлы |
|---|---|---|
| **Happ** | ПК (Windows) и Android (быстрые базы ~1.4 МБ через JSDelivr) | [🔗 Диплинк (.txt)](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/happ/pc_android_deeplink.txt) · [📄 JSON](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/happ/pc_android.json) · [📥 setup_happ.bat](https://raw.githubusercontent.com/purrfect0/bypass_list/main/scripts/setup_happ.bat) |
| **Happ Full RKN** | ПК / Android (опционально: полная база РКН `106 МБ` с GitHub) | [🔗 Диплинк (.txt)](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/happ/pc_full_rkn_deeplink.txt) · [📄 JSON](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/happ/pc_full_rkn.json) |
| **Happ Lite** | iPhone / iOS (лёгкие базы ~1.4 МБ под лимит 50 МБ RAM) | [🔗 Диплинк (.txt)](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/happ/iphone_lite_deeplink.txt) · [📄 JSON](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/happ/iphone_lite.json) |
| **v2RayTun** | ПК (нативный пресет) / Android / iPhone | [📄 Пресет (.json)](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/v2raytun/preset.json) · [📄 Полный JSON](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/v2raytun/routing_full.json) · [🏷️ Header (`routing:`)](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/v2raytun/routing_header.txt) · [📥 setup_v2raytun.bat](https://raw.githubusercontent.com/purrfect0/bypass_list/main/scripts/setup_v2raytun.bat) |
| **AmneziaVPN** | ПК / Android / iPhone | [📄 amnezia_blocked_ips.json](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/amnezia/amnezia_blocked_ips.json) · [📝 Список CIDR (.txt)](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/amnezia/amnezia_blocked_ips.txt) · [📥 make_amnezia_iplist.bat](https://raw.githubusercontent.com/purrfect0/bypass_list/main/scripts/make_amnezia_iplist.bat) |

> 💡 **Подсказка:** чтобы сохранить `.bat` или `.json` в браузере из открывшейся вкладки — нажми `Ctrl + S` и убедись, что в конце имени файла не дописалось `.txt`. Любой `.bat` из [`scripts/`](scripts/) полностью автономен — его можно переслать другу в Telegram одним файлом.

---

## 🧭 Как распределяется трафик

| Категория | Примеры сервисов | Маршрут |
|---|---|---|
| 🤖 **ИИ и разработка** | Gemini, AI Studio, NotebookLM, ChatGPT, Claude, Cursor, Perplexity, Copilot, Midjourney, Figma, NVIDIA, JetBrains, GitHub, Canva, Notion, Adobe | `🛡️ Через VPN (Proxy)` |
| 🌐 **Заблокированные ресурсы и соцсети** | YouTube, Discord (сайт + голосовой UDP `66.22.192.0/18`), Instagram, Facebook, X/Twitter, TikTok, Spotify, Netflix, Patreon, Rutracker + базы РКН (`runetfreedom`, `re:filter`, `antifilter`) | `🛡️ Через VPN (Proxy)` |
| 🎮 **Dota 2 и Steam** | Игровые релеи Valve SDR (автосбор из API Steam `GetSDRConfig` + `AS32590`) и `geosite:steam` | `⚡ Напрямую (Direct)` |
| 🏦 **Весь остальной интернет** | Российские сайты, банки, Госуслуги, маркетплейсы, торренты и обычные игры | `⚡ Напрямую (Direct)` |

---

## 📱 Подробные инструкции по настройке

<details open>
<summary><b>💻 Настройка на ПК (Windows) — Happ, v2RayTun, AmneziaVPN</b></summary>

* **Happ:** запусти команду из раздела выше или [`scripts/setup_happ.bat`](scripts/setup_happ.bat). Скрипт запускает `Happ.exe` напрямую и копирует диплинк в буфер:
  * Если сервер добавлен вручную (**Список серверов** / `vless://`), профиль `Gemini Dota2 Smart RU` применится сразу — достаточно нажать **Выкл / Вкл (Reconnect)** и подождать 3–5 секунд скачивания лёгких баз (~1.4 МБ через JSDelivr).
  * Если пользуешься **Подпиской** (`SwagaVPN` и др.): десктопный Happ не выбирает подписку по диплинку → нажми в Happ **`+` → Вставить из буфера обмена** и выбери свою подписку.
  * Для браузера (Gemini, YouTube) и Dota 2 достаточно режима **System Proxy**. Для десктопного **Discord с голосом** включи **`TUN`** (запуск от Администратора) — Dota 2 всё равно пойдёт напрямую через подсети Valve (`AS32590`).
  * Если нужен полный список РКН (`106 МБ`, медленнее без VPN) — используй [`pc_full_rkn_deeplink.txt`](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/happ/pc_full_rkn_deeplink.txt).
* **v2RayTun:** запусти команду из раздела выше или [`scripts/setup_v2raytun.bat`](scripts/setup_v2raytun.bat). Скрипт сам остановит клиент (делая `.bak`-бэкап), запишет и активирует нативный пресет **`Gemini + Dota2 (Smart RU)`** в `shared_preferences.json`, после чего запустит v2RayTun обратно — останется нажать **Выкл / Вкл**. *(Также в буфер копируется [`routing_full.json`](dist/v2raytun/routing_full.json) для ручного импорта через **Настройки ⚙️ → Маршрутизация → `⋮` → Импорт из буфера**; если v2RayTun запущен от Администратора в режиме TUN, закрой его из трея перед применением или запусти `.bat` от Администратора).*
* **AmneziaVPN:**
  1. Отключи активное VPN-соединение в AmneziaVPN.
  2. Открой **Настройки ⚙️ → Соединение → Раздельное туннелирование сайтов**.
  3. Включи тумблер и выбери режим **«Только адреса из списка должны открываться через VPN»**.
  4. Нажми **Импорт → Заменить список сайтов** и выбери [`amnezia_blocked_ips.json`](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/amnezia/amnezia_blocked_ips.json) (или сгенерируй свежий через [`make_amnezia_iplist.bat`](scripts/make_amnezia_iplist.bat)).
  5. Проверь, что в **Настройки ⚙️ → DNS** указаны `1.1.1.1` и `8.8.8.8`, и подключись.

</details>

<details>
<summary><b>📱 Настройка на Android и iPhone (iOS)</b></summary>

Проще всего переслать нужную ссылку или файл в **Избранное Telegram**:

* **Happ (Android):** скопируй строку `happ://routing/onadd/...` из [pc_android_deeplink.txt](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/happ/pc_android_deeplink.txt) → открой **Happ** → **`+` → Вставить из буфера обмена** → выбери подписку/профиль → переподключи VPN.
* **Happ (iPhone / iOS):** у iOS жёсткий лимит **50 МБ оперативной памяти** на сетевой туннель. Для iPhone копируй строку из [iphone_lite_deeplink.txt](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/happ/iphone_lite_deeplink.txt) (`~1.4 МБ` базы через JSDelivr) → в **Happ** нажми **`+` → Вставить из буфера обмена** → переподключи VPN.
* **v2RayTun (Android и iPhone):** у v2RayTun нет диплинка для правил маршрутизации, поэтому скопируй содержимое [routing_full.json](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/v2raytun/routing_full.json) (или компактный [routing_compact.json](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/v2raytun/routing_compact.json)) → открой **v2RayTun → Настройки ⚙️ → Маршрутизация → `⋮` → Импорт из буфера обмена** → включи правило и переподключи VPN. *(Владельцы серверов/подписок также могут отдавать [`routing_header.txt`](dist/v2raytun/routing_header.txt) в HTTP-заголовках подписки).*
* **AmneziaVPN (Android и iPhone):** сохрани [amnezia_blocked_ips.json](https://raw.githubusercontent.com/purrfect0/bypass_list/main/dist/amnezia/amnezia_blocked_ips.json) на телефон *(на iPhone следи, чтобы в конце не добавилось `.txt`)* → при выключенном VPN зайди в **Настройки ⚙️ → Соединение → Раздельное туннелирование сайтов** → режим **«Только адреса из списка должны открываться через VPN»** → **Импорт**.
* **Лайфхак для Android (банки и такси):** некоторые приложения на Android проверяют сам факт включённого значка `VPN` в шторке. В **Happ**, **v2RayTun** и **AmneziaVPN** открой **Раздельное туннелирование приложений (Per-App Proxy)** и добавь нужный банк в исключения (**Обход / Bypass**).

</details>

<details>
<summary><b>⚙️ Добавление своих доменов и IP + структура репозитория</b></summary>

1. Допиши нужные домены или теги в [`custom/extra-proxy-domains.txt`](custom/extra-proxy-domains.txt) (по одному на строку, например `example.com` или `geosite:openai`).
2. Допиши нужные подсети в [`custom/extra-proxy-ips.txt`](custom/extra-proxy-ips.txt) (например `1.2.3.0/24`).
3. Запусти [`update_all.bat`](update_all.bat) — скрипт [`scripts/build-all.ps1`](scripts/build-all.ps1) пересоберёт все файлы в [`dist/`](dist/).
   * На GitHub также настроен [`.github/workflows/update-lists.yml`](.github/workflows/update-lists.yml), который автоматически обновляет `dist/` каждые **12 часов** (и по кнопке **Run workflow**).

```text
bypass_list/
├── .github/workflows/update-lists.yml   # Автообновление dist/ каждые 12 часов
├── custom/
│   ├── extra-proxy-domains.txt          # Твои дополнительные домены для VPN
│   └── extra-proxy-ips.txt              # Твои дополнительные IP/CIDR для VPN
├── dist/
│   ├── amnezia/                         # Готовый JSON и список CIDR для AmneziaVPN
│   ├── happ/                            # Диплинки и JSON для Happ (Smart RU, iPhone Lite, Full RKN)
│   └── v2raytun/                        # Нативный пресет preset.json, routing JSON и routing_header.txt
├── scripts/
│   ├── build-all.ps1                    # Кроссплатформенный сборщик (Windows/Linux)
│   ├── make_amnezia_iplist.bat          # Автономный батник для AmneziaVPN
│   ├── setup_happ.bat                   # Автономный батник для Happ
│   └── setup_v2raytun.bat               # Автономный батник для v2RayTun
├── LICENSE                              # Лицензия MIT
├── README.md
└── update_all.bat                       # Пересобрать весь dist/ локально в 1 клик
```

</details>
