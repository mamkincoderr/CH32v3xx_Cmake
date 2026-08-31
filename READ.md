# CH32v3xx_Cmake — Hello World для CH32V303 / CH32V307

Автор: [mamkincoderr](https://github.com/mamkincoderr) · [Telegram](https://t.me/oDeXteRo)

Минимальный CMake-шаблон прошивки: `printf("Hello World")` по USART1 (303: PB6 remap, 307: PA9), 115200. Собирается и из консоли, и из **MRS 1.92**.
Сборка и прошивка — как в `DCDC_Cmake` (CMake + Ninja + GCC 15 из MRS2 + OpenOCD/WCH-Link-E).
Выбор кристалла — по официальному EVT [openwch/ch32v307](https://github.com/openwch/ch32v307).

> Файл заметок проекта. Корневой `README.md` на GitHub намеренно не выкладывается.

## Какой кристалл

Чип выбирается **руками, одной строкой в `User/chip_select.h`**:

```c
#define CH32v3xx_CHIP   303   /* или 307 */
```

Это единственное место выбора — не аргумент `build.bat`, не CMake-кэш. Один `build.bat`, одна конфигурация MRS, один `obj\`.

| `CH32v3xx_CHIP` | Макрос (официальный `ch32v30x.h`) | Стартап | Линкер |
|---|---|---|---|
| **303** (по умолчанию, эта плата) | `CH32V30x_D8` | `startup_ch32v30x_D8.S` | FLASH 128K (R0WAIT) + SLOWFLASH 352K. Нет RAM_CODE_MOD. |
| **307** | `CH32V30x_D8C` | `startup_ch32v30x_D8C.S` | 4 режима CODE/RAM; карта из `CH32V307_MEM` в `User/ch32v307_mem.h` |

CodeFlash семейства — до 480K: нулевые ожидания (R0WAIT, в таблице DS графа Flash) и **SLOWFLASH** (non-zero wait data). У 303CB/RB R0WAIT = 128K, SLOWFLASH с `0x20000` длиной 352K (как `Master16A`). У 307 граница SLOWFLASH сдвигается вместе с окном CODE (`RAM_CODE_MOD`).

`chip_select.h` — обычный `#include`, не CMake-генерируемый файл и не `-D` через командную строку. Именно поэтому редактор MRS 1.92 корректно подсвечивает неактивные `#if`/`#elif` в `main.c` — индексатор Eclipse CDT видит значение так же, как реальный компилятор, без знания про `-include`/`-D`.

## Режим флеша CH32V307

У CH32V307 option byte `RAM_CODE_MOD` (2 бита, окно CODE+SRAM = 320K, физическая флеш 480K). У CH32V303CB/RB этого option byte нет: R0WAIT всегда 128K.

Выбор — одна строка в `User/ch32v307_mem.h` (ignored, если `CH32v3xx_CHIP` = 303):

```c
#define CH32V307_MEM  MEM288_32
```

| `CH32V307_MEM` | CODE | RAM | SLOWFLASH (после окна CODE) |
|---|---|---|---|
| `MEM288_32` (по умолчанию, EVT) | 288K | 32K | 192K с `0x48000` |
| `MEM256_64` | 256K | 64K | 224K с `0x40000` |
| `MEM224_96` | 224K | 96K | 256K с `0x38000` |
| `MEM192_128` | 192K | 128K | 288K с `0x30000` |

CMake читает эту строку (`file(READ) + regex`, тем же способом, каким читает `CH32v3xx_CHIP` из `chip_select.h`) и собирает `Link_ch32v307.ld`. `MemConfig()` вызывается из `startup_ch32v30x_D8C.S` до копирования `.data` (временный SP `0x20004000`, внутри 32K). Если option byte не совпал — программируется USER и идёт reset.

`SLOWFLASH` — wait-state флеш. Туда кладутся `.rodata` и `section(".SLOWFLASH")` на обоих кристаллах.

Стартап D8 (303) не тронут. В D8C добавлены только `jal MemConfig` и временный стек.

Источники WCH:

- Список стартапов: [EVT/CH32V30x_List_EN.txt](https://github.com/openwch/ch32v307/blob/main/EVT/CH32V30x_List_EN.txt) — D8 = CH32V303, D8C = CH32V307/305/317.
- Карта памяти: [EVT/EXAM/SRC/Ld/Link.ld](https://github.com/openwch/ch32v307/blob/main/EVT/EXAM/SRC/Ld/Link.ld) (варианты SRAM/Flash — Table 32-3 в CH32FV2x_V3xRM).
- Hello World: [EVT/EXAM/USART/USART_Printf](https://github.com/openwch/ch32v307/blob/main/EVT/EXAM/USART/USART_Printf/User/main.c) — USART1_Tx(PA9).

**Не заливать образ V307 на плату V303.**

## Сборка из консоли

```bat
build.bat                 :: obj\CH32v3xx_Cmake.elf/.hex, чип берётся из User\chip_select.h
build.bat clean
```

Чтобы собрать другой чип — правите `User\chip_select.h`, снова `build.bat`. Один `obj\`, старый бинарник того же имени перезаписывается (не путаются два артефакта под разными именами).

## MRS 1.92 (как в DCDC_Cmake)

MRS 1.92 здесь **только IDE**: редактор, Project Explorer, молоток Build, кнопка Download, отладчик. **Managed Build выключен** (`managedBuildOn="false"` в `.cproject`). Одна конфигурация сборки (**Default**), один `.project`/`.template`, один `.launch`. Чип не завязан на конфигурацию MRS — он в `User/chip_select.h`.

Открыть: `CH32v3xx_Cmake.wvproj` (или File → Open Projects from File System на эту папку).

Молоток вызывает `build.bat` без аргументов — чип он узнаёт из `chip_config.h`, вернее теперь из `User/chip_select.h` (CMake сам туда заглядывает). В прошивке печатается `Built as CH32V303` или `Built as CH32V307`.

| Действие MRS | Что делает |
|---|---|
| Build (молоток) | `build.bat` → `obj\CH32v3xx_Cmake.hex/.elf`, чип — какой сейчас в `chip_select.h` |
| Clean | `build.bat clean` |
| Download | `.template` → `obj\CH32v3xx_Cmake.hex`. MCU-поле в `.template` статично (`CH32V303CBT6`) — это только подпись в диалоге MRS, на сам процесс прошивки через OpenOCD не влияет |
| Debug | `CH32v3xx_Cmake.launch` → `obj\CH32v3xx_Cmake.elf`, стоп на `main` |

**Известное ограничение:** SVD в `CH32v3xx_Cmake.launch` (`com.mounriver.debug.gdbjtag.openocd.svdPath`) статично указывает на `CH32V303xx.svd`. Если переключили `chip_select.h` на 307 и хотите видеть верную карту периферии в отладчике — поправьте `svdPath` в этом launch-файле на `CH32V307xx.svd` вручную (загрузка ELF и сама отладка работают правильно независимо от SVD, это касается только окна регистров).

Нужны те же утилиты, что для DCDC: MRS2 (GCC15), CMake ≥3.20, Ninja. MRS 1.92 своего cmake/ninja не содержит. `build.bat` сам ищет их, даже если IDE запущена со старым PATH.

Eclipse может передать лишние аргументы (`-j24 all` / `-j24 clean`) — `build.bat` их просто игнорирует, кроме `clean`.

Тактование: 144 МГц от HSI+PLL (`SYSCLK_FREQ_144MHz_HSI` в `User/system_ch32v30x.c`) — как на плате `DCDC_Cmake`, без внешнего кварца. Официальные EVT чаще включают HSE 8 МГц.

## Прошивка и отладка

```powershell
.\flash.ps1                # program + verify + reset, образ из obj\CH32v3xx_Cmake.hex
.\flash.ps1 probe
.\flash.ps1 gdb
```

Чип для `flash.ps1` — какой был собран последним (см. `obj\built_as.txt`). Скрипт не сверяет прошивку с реальным кристаллом на плате.

USART: 115200 8N1, WCH-Link SERIAL. **CH32V303** — remap **PB6** (плата DCDC). **CH32V307** — **PA9**, без remap (EVT USART_Printf).

## Что внутри, чего нет

Есть: `Core/`, `Peripheral/` (SPL WCH), официальные `Debug/debug.c` (delay + USART printf), `User/main.c`.

Нет: ШИМ, АЦП, CAN, PowerGraph, LVGL, загрузчик. Это точка старта нового проекта, не копия DCDC.

## MCP (сборка / прошивка / отладка для ИИ)

В комплекте stdio-сервер `ch32-wch`: `mcp/server.py`. Подключение — `mcp/README.md`.
Инструменты `build`/`flash`/`debug_start`/`debug_exec` больше не принимают параметр `chip` — чип определяется `User/chip_select.h`, как и в консоли. `build()` возвращает содержимое `obj/built_as.txt`, чтобы агент видел, что реально собралось.

`flash(mode="probe")` определяет подключённый чип: `device_id`, `flash_kb` (и `rom_kb`/`ram_kb`, когда лог их даёт). Новые режимы `lock`/`unlock` (снять/поставить read-protect через `wch_riscv`-драйвер OpenOCD, `flash protect 0 0 last on/off`) требуют `confirm=true` — без него отказ ещё до обращения к железу. `unlock` — необратимый mass erase всей прошивки, `lock` может временно заблокировать программирование/отладку до `unlock`. Проверено вживую на подключённом CH32V303 (`unlock` → `Success to Disable Read-Protect`, `lock` → `Success to Enable Read-Protect`, чип оставался доступен, прошивка залита обратно).
Claude Code: `.mcp.json` + `.claude.json` + `.claude/skills/ch32-wch/SKILL.md`.
Claude Desktop: `mcp/claude_desktop_config.example.json` → `%APPDATA%\Claude\claude_desktop_config.json`.
Grok: `.grok/config.toml` + `.grok/skills/ch32-wch/SKILL.md`. GitHub этот MCP не обслуживает.
