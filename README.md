# CH32v3xx_Cmake

[![visits](https://hits.sh/github.com/mamkincoderr/CH32v3xx_Cmake.svg?view=today-total&label=visits)](https://hits.sh/github.com/mamkincoderr/CH32v3xx_Cmake/)

Демонстрационная прошивка и шаблон рабочего проекта для микроконтроллеров **WCH CH32V303** и **CH32V307** (ядро RISC-V QingKe V4F).

**Назначение.** Единое дерево исходных текстов обслуживает оба кристалла семейства CH32V30x. Основная среда работы инженера — **MounRiver Studio 1.92**: редактирование, сборка, загрузка во flash и отладка. Компиляция выполняется не встроенным генератором makefile этой IDE, а воспроизводимой цепочкой CMake / Ninja и **RISC-V GCC 15** из комплекта **MounRiver Studio 2**; Studio 1.92 вызывает её командой Build (`build.bat`) и программирует полученный hex. Для программных агентов (**Claude**, **Grok**, **Cursor**) в репозитории поставляется MCP-сервер `ch32-wch`, выполняющий те же операции сборки, программирования и отладки.

`#WCH` `#CH32V303` `#CH32V307` `#CH32V30x` `#MRS` `#Claude` `#Grok` `#Cursor`

## Выбор кристалла — руками, в одном файле

Чип не выбирается ключом командной строки и не завязан на конфигурацию IDE — это одна строка в `User/chip_select.h`:

```c
#define CH32v3xx_CHIP   303   /* или 307 */
```

Поправили значение — пересобрали (`build.bat` в консоли или молоток в MRS, без аргументов). Один `obj/`, один артефакт `CH32v3xx_Cmake.elf/.hex`, одна конфигурация MRS. Это же — обычный `#include`, не CMake-генерируемый заголовок и не флаг `-D`, поэтому редактор MRS 1.92 корректно подсвечивает неактивные ветки `#if`/`#elif` в исходниках: индексатор Eclipse CDT видит значение так же, как реальный компилятор.

Для CH32V307 отдельно, в `User/ch32v307_mem.h`, тем же способом выбирается разбивка Flash/RAM (`RAM_CODE_MOD`): `MEM288_32` / `MEM256_64` / `MEM224_96` / `MEM192_128`.

## Системные требования

- **Windows**

- **MounRiver Studio 1.92** — основная среда разработки: исходники, Build, Download, отладчик.

  <details>
  <summary>Где взять</summary>

  Дистрибутив — на сайте разработчика: [mounriver.com/download](http://www.mounriver.com/download). Установить Studio 1.9.x (ветка 1.92). Открыть в IDE файл `CH32v3xx_Cmake.wvproj` этого репозитория.

  В проекте одна конфигурация сборки (**Default**). Молоток вызывает `build.bat` без аргументов — чип он берёт из `User/chip_select.h`. Отладка — Run → Debug Configurations → **CH32v3xx_Cmake** (ELF `obj\CH32v3xx_Cmake.elf`). Кнопка Download программирует `obj\CH32v3xx_Cmake.hex` (файл `.template`).

  CodeFlash до 480K: R0WAIT (нулевые ожидания) и SLOWFLASH (non-zero wait). У CH32V303CB/RB R0WAIT = 128K, SLOWFLASH = 352K с адреса `0x20000`. CH32V307 имеет 4 режима окна CODE/RAM (`RAM_CODE_MOD`), режим задаётся в `User/ch32v307_mem.h` макросом `CH32V307_MEM`. CMake подставляет карту в линкер; `MemConfig()` в стартапе D8C записывает option byte.
  </details>

- **MounRiver Studio 2** — компилятор GCC 15 (`riscv32-wch-elf-gcc`) и OpenOCD с конфигурацией `wch-riscv.cfg`. Их использует `build.bat` при сборке из Studio 1.92 и из MCP.

  <details>
  <summary>Где взять</summary>

  Отдельный установщик Studio 2 — там же: [mounriver.com/download](http://www.mounriver.com/download). После установки в каталоге тулчейна **всегда** лежит архив, а не готовая папка:

  `C:\MounRiver\MounRiver_Studio2\resources\app\resources\win32\components\WCH\Toolchain\RISC-V Embedded GCC15.zip`

  Распаковать архив **в тот же каталог** `Toolchain` (в проводнике: «Извлечь всё…», путь назначения — папка `Toolchain`, без создания дополнительного уровня вложенности). Должен получиться компилятор:

  `C:\MounRiver\MounRiver_Studio2\resources\app\resources\win32\components\WCH\Toolchain\RISC-V Embedded GCC15\bin\riscv32-wch-elf-gcc.exe`

  Архив после распаковки можно оставить рядом.
  </details>

- **CMake** версии 3.20 или новее.

  <details>
  <summary>Установка из PowerShell</summary>

  ```powershell
  winget install --id Kitware.CMake --exact
  ```

  Проверка: `cmake --version`. При необходимости перезапустить MounRiver Studio 1.92, чтобы IDE увидела обновлённый PATH; `build.bat` ищет `cmake.exe` в стандартных каталогах и без этого.
  </details>

- **Ninja**.

  <details>
  <summary>Установка из PowerShell</summary>

  ```powershell
  winget install --id Ninja-build.Ninja --exact
  ```

  Проверка: `ninja --version`.
  </details>

- **WCH-Link-E** — программатор и отладчик по интерфейсу SDI.

  <details>
  <summary>Подключение</summary>

  Адаптер должен работать в режиме RISC-V: в диспетчере устройств Windows — **WCH-LinkRV**, идентификатор `VID_1A86&PID_8010`. Значение `PID_8012` означает режим ARM; переключение — утилитой **WCH-LinkUtility** из комплекта MounRiver Studio. Последовательный канал адаптера обычно появляется как `WCH-Link SERIAL (COMx)`.
  </details>

- **ИИ** (**Claude**, **Grok**, **Cursor**) — сборка, программирование и отладка через MCP `ch32-wch`.

  <details>
  <summary>Как подключить</summary>

  Откройте агенту **папку этого проекта** (корень репозитория, где лежат `CMakeLists.txt` и `mcp/`). Попросите найти в дереве MCP-сервер и навыки и установить их. Конфигурации уже лежат в репозитории: `.mcp.json`, `.claude/`, `.grok/`, `.cursor/mcp.json`, сервер — `mcp/server.py`, навыки — `.claude/skills/ch32-wch` и `.grok/skills/ch32-wch`.
  </details>

## Проверка на железе

Сборка, загрузка во flash, USART и GDB выполнялись на **CH32V303CBT** (`ChipID` `30330514`), программатор WCH-Link-E, режим RISC-V. Образ CH32V307 **компонуется**, на кристалле CH32V307 не прогонялся.

## Как выбрать процессор

1. Откройте `User/chip_select.h`.
2. Поправьте `#define CH32v3xx_CHIP` на `303` или `307`.
3. Для CH32V307 — при необходимости поправьте `#define CH32V307_MEM` в `User/ch32v307_mem.h`.
4. Пересоберите: молоток в MRS 1.92 либо `build.bat` в консоли. Никакой аргумент командной строки и никакая конфигурация IDE не участвуют — единственный источник истины эти два файла.

Известное ограничение: SVD и MCU-подпись в файлах `CH32v3xx_Cmake.launch` / `.template` статично указывают на CH32V303 (плата, на которой проверялся проект). Загрузка и отладка ELF работают правильно для любого выбранного чипа; чтобы окно регистров периферии в отладчике соответствовало CH32V307, поправьте `svdPath` в `.launch` вручную.

## Лицензия

Слой проекта (CMake, скрипты, MCP, `User/main.c`) — **[0BSD](LICENSE)**: использование, копирование и распространение без ограничений и без требования указания авторства.

Файлы библиотеки периферии и EVT компании Nanjing Qinheng (каталоги `Core/`, `Peripheral/`, `Startup/`, `Debug/debug.*`, `system_ch32v30x.*` и связанные заголовки) **не** покрываются 0BSD: действует условие WCH — только для микроконтроллеров этого производителя.

Автор: [mamkincoderr](https://github.com/mamkincoderr) · [Telegram](https://t.me/oDeXteRo)
