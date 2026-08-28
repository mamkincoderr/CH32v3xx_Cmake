# CH32v3xx_Cmake — Hello World для CH32V303 / CH32V307

Автор: [mamkincoderr](https://github.com/mamkincoderr) · [Telegram](https://t.me/oDeXteRo)

Минимальный CMake-шаблон прошивки: `printf("Hello World")` по USART1 (PB6 remap, 115200). Собирается и из консоли, и из **MRS 1.92**.
Сборка и прошивка — как в `DCDC_Cmake` (CMake + Ninja + GCC 15 из MRS2 + OpenOCD/WCH-Link-E).
Выбор кристалла — по официальному EVT [openwch/ch32v307](https://github.com/openwch/ch32v307).

> Файл заметок проекта. Корневой `README.md` на GitHub намеренно не выкладывается.

## Какой кристалл

| `CHIP` | Макрос (официальный `ch32v30x.h`) | Стартап | Линкер |
|---|---|---|---|
| **CH32V303** (по умолчанию, эта плата) | `CH32V30x_D8` | `startup_ch32v30x_D8.S` | FLASH 128K + RAM 32K |
| **CH32V307** | `CH32V30x_D8C` | `startup_ch32v30x_D8C.S` | FLASH 288K + RAM 32K |

Источники WCH:

- Список стартапов: [EVT/CH32V30x_List_EN.txt](https://github.com/openwch/ch32v307/blob/main/EVT/CH32V30x_List_EN.txt) — D8 = CH32V303, D8C = CH32V307/305/317.
- Карта памяти: [EVT/EXAM/SRC/Ld/Link.ld](https://github.com/openwch/ch32v307/blob/main/EVT/EXAM/SRC/Ld/Link.ld) (варианты SRAM/Flash — Table 32-3 в CH32FV2x_V3xRM).
- Hello World: [EVT/EXAM/USART/USART_Printf](https://github.com/openwch/ch32v307/blob/main/EVT/EXAM/USART/USART_Printf/User/main.c) — USART1_Tx(PA9).

**Не заливать образ V307 на плату V303.**

## Сборка из консоли

```bat
build.bat                 :: CH32V303 → obj\CH32V303.elf/.hex
build.bat CH32V307        :: → obj\CH32V307\CH32V307.elf/.hex
build.bat clean
build.bat CH32V307 clean
```

V303 пишется в `obj\` (так MRS 1.92 ищет артефакт). V307 — в `obj\CH32V307\`.

## MRS 1.92 (как в DCDC_Cmake)

MRS 1.92 здесь **только IDE**: редактор, Project Explorer, молоток Build, кнопка Download, отладчик. **Managed Build выключен** (`managedBuildOn="false"` в `.cproject`). Молоток запускает `build.bat` в корне проекта. Настройки компилятора в Properties → C/C++ Build на реальную сборку не влияют.

Открыть: `CH32v3xx_Cmake.wvproj` (или File → Open Projects from File System на эту папку).

| Действие MRS | Что происходит |
|---|---|
| Build (молоток) | `build.bat` → CMake+Ninja, GCC 15 из **MRS2**, образ `obj\CH32V303.hex` |
| Clean | `build.bat clean` |
| Download | `.template` → `Target Path=obj\CH32V303.hex`, MCU=CH32V303CBT6 |
| Debug | `CH32v3xx_Cmake.launch` → `obj\CH32V303.elf`, стоп на `main` |

Нужны те же утилиты, что для DCDC: MRS2 (GCC15), CMake ≥3.20, Ninja. MRS 1.92 своего cmake/ninja не содержит. `build.bat` сам ищет их, даже если IDE запущена со старым PATH.

Eclipse может передать лишние аргументы (`-j24 all` / `-j24 clean`) — `build.bat` ищет слово `clean` среди всех аргументов, не только в первом.

CH32V307 из MRS по умолчанию **не собирается** (Download заточен под эту плату V303). Вариант 307: `build.bat CH32V307` из консоли.

Тактование: 144 МГц от HSI+PLL (`SYSCLK_FREQ_144MHz_HSI` в `User/system_ch32v30x.c`) — как на плате `DCDC_Cmake`, без внешнего кварца. Официальные EVT чаще включают HSE 8 МГц.

## Прошивка и отладка

```powershell
.\flash.ps1                # program + verify + reset, образ V303
.\flash.ps1 probe
.\flash.ps1 gdb
.\flash.ps1 CH32V307       # только если на столе CH32V307
```

USART: **PB6** (USART1 remap), 115200 8N1 — так разведён WCH-Link SERIAL на этой плате (`DCDC_Cmake` uart_pgc). Официальный EVT USART_Printf сидит на PA9; для шаблона оставлен remap под эту плату.

## Что внутри, чего нет

Есть: `Core/`, `Peripheral/` (SPL WCH), официальные `Debug/debug.c` (delay + USART printf), `User/main.c`.

Нет: ШИМ, АЦП, CAN, PowerGraph, LVGL, загрузчик. Это точка старта нового проекта, не копия DCDC.

## MCP (сборка / прошивка / отладка для ИИ)

В комплекте stdio-сервер `ch32-wch`: `mcp/server.py`. Подключение — `mcp/README.md`.
Claude Code: `.mcp.json` + `.claude.json` + `.claude/skills/ch32-wch/SKILL.md`.
Claude Desktop: `mcp/claude_desktop_config.example.json` → `%APPDATA%\Claude\claude_desktop_config.json`.
Grok: `.grok/config.toml` + `.grok/skills/ch32-wch/SKILL.md`. GitHub этот MCP не обслуживает.
