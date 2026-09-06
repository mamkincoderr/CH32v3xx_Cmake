# CH32v3xx_Cmake

[![visits](https://hits.sh/github.com/mamkincoderr/CH32v3xx_Cmake.svg?view=today-total&label=visits)](https://hits.sh/github.com/mamkincoderr/CH32v3xx_Cmake/)
[![M8ven Score](https://m8ven.ai/badge/mcp/mamkincoderr-ch32v3xx-cmake-19bek7)](https://m8ven.ai/mcp/mamkincoderr-ch32v3xx-cmake-19bek7)

**[Русский](#русский)** · **[English](#english)** · **[中文](#中文)**

---

## Русский

Демонстрационная прошивка и шаблон рабочего проекта для микроконтроллеров **WCH CH32V303** и **CH32V307** (ядро RISC-V QingKe V4F).

**Назначение.** Единое дерево исходных текстов обслуживает оба кристалла семейства CH32V30x. Основная среда работы инженера — **MounRiver Studio 1.92**: редактирование, сборка, загрузка во flash и отладка. Компиляция выполняется не встроенным генератором makefile этой IDE, а воспроизводимой цепочкой CMake / Ninja и **RISC-V GCC 15** из комплекта **MounRiver Studio 2**; Studio 1.92 вызывает её командой Build (`build.bat`) и программирует полученный hex. Для программных агентов (**Claude**, **Grok**, **Cursor**) в репозитории поставляется MCP-сервер `ch32-wch`, выполняющий те же операции сборки, программирования и отладки.

`#WCH` `#CH32V303` `#CH32V307` `#CH32V30x` `#MRS` `#Claude` `#Grok` `#Cursor`

### Выбор кристалла — руками, в одном файле

Чип не выбирается ключом командной строки и не завязан на конфигурацию IDE — это одна строка в `User/chip_select.h`:

```c
#define CH32v3xx_CHIP   303   /* или 307 */
```

Поправили значение — пересобрали (`build.bat` в консоли или молоток в MRS, без аргументов). Один `obj/`, один артефакт `CH32v3xx_Cmake.elf/.hex`, одна конфигурация MRS. Это же — обычный `#include`, не CMake-генерируемый заголовок и не флаг `-D`, поэтому редактор MRS 1.92 корректно подсвечивает неактивные ветки `#if`/`#elif` в исходниках: индексатор Eclipse CDT видит значение так же, как реальный компилятор.

Для CH32V307 отдельно, в `User/ch32v307_mem.h`, тем же способом выбирается разбивка Flash/RAM (`RAM_CODE_MOD`): `MEM288_32` / `MEM256_64` / `MEM224_96` / `MEM192_128`.

### Системные требования

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

### Проверка на железе

Сборка, загрузка во flash, USART и GDB выполнялись на **CH32V303CBT** (`ChipID` `30330514`) и на **CH32V307** (OpenOCD: ROM 288K + RAM 32K), программатор WCH-Link-E, режим RISC-V. USART1: на 303 — remap **PB6**, на 307 — **PA9** (как EVT); WCH-Link SERIAL 115200.

### Как выбрать процессор

1. Откройте `User/chip_select.h`.
2. Поправьте `#define CH32v3xx_CHIP` на `303` или `307`.
3. Для CH32V307 — при необходимости поправьте `#define CH32V307_MEM` в `User/ch32v307_mem.h`.
4. Пересоберите: молоток в MRS 1.92 либо `build.bat` в консоли. Никакой аргумент командной строки и никакая конфигурация IDE не участвуют — единственный источник истины эти два файла.

Известное ограничение: SVD и MCU-подпись в файлах `CH32v3xx_Cmake.launch` / `.template` статично указывают на CH32V303 (плата, на которой проверялся проект). Загрузка и отладка ELF работают правильно для любого выбранного чипа; чтобы окно регистров периферии в отладчике соответствовало CH32V307, поправьте `svdPath` в `.launch` вручную.

### Лицензия

Слой проекта (CMake, скрипты, MCP, `User/main.c`) — **[0BSD](LICENSE)**: использование, копирование и распространение без ограничений и без требования указания авторства.

Файлы библиотеки периферии и EVT компании Nanjing Qinheng (каталоги `Core/`, `Peripheral/`, `Startup/`, `Debug/debug.*`, `system_ch32v30x.*` и связанные заголовки) **не** покрываются 0BSD: действует условие WCH — только для микроконтроллеров этого производителя.

Автор: [mamkincoderr](https://github.com/mamkincoderr) · [Telegram](https://t.me/oDeXteRo)

---

## English

Demo firmware and a working-project template for **WCH CH32V303** and **CH32V307** microcontrollers (RISC-V QingKe V4F core).

**Purpose.** A single source tree serves both dies of the CH32V30x family. The engineer's primary environment is **MounRiver Studio 1.92**: editing, building, flashing and debugging. Compilation is done not by the IDE's built-in makefile generator but by a reproducible CMake / Ninja chain with **RISC-V GCC 15** from **MounRiver Studio 2**; Studio 1.92 invokes it through its Build command (`build.bat`) and programs the resulting hex. For software agents (**Claude**, **Grok**, **Cursor**) the repository ships the `ch32-wch` MCP server, which performs the same build, flash and debug operations.

`#WCH` `#CH32V303` `#CH32V307` `#CH32V30x` `#MRS` `#Claude` `#Grok` `#Cursor`

### Chip selection — by hand, in one file

The chip is not selected by a command-line switch and is not tied to the IDE configuration — it is one line in `User/chip_select.h`:

```c
#define CH32v3xx_CHIP   303   /* or 307 */
```

Change the value, rebuild (`build.bat` in a console, or the hammer button in MRS, with no arguments). One `obj/`, one artefact `CH32v3xx_Cmake.elf/.hex`, one MRS configuration. This is also a plain `#include` — not a CMake-generated header and not a `-D` flag — so the MRS 1.92 editor correctly greys out inactive `#if`/`#elif` branches in the sources: the Eclipse CDT indexer sees the value the same way the real compiler does.

For CH32V307 separately, in `User/ch32v307_mem.h`, the Flash/RAM split (`RAM_CODE_MOD`) is chosen the same way: `MEM288_32` / `MEM256_64` / `MEM224_96` / `MEM192_128`.

### System requirements

- **Windows**

- **MounRiver Studio 1.92** — the main development environment: sources, Build, Download, debugger.

  <details>
  <summary>Where to get it</summary>

  The distribution is on the developer's site: [mounriver.com/download](http://www.mounriver.com/download). Install Studio 1.9.x (the 1.92 branch). Open this repository's `CH32v3xx_Cmake.wvproj` file in the IDE.

  The project has one build configuration (**Default**). The hammer button calls `build.bat` with no arguments — it takes the chip from `User/chip_select.h`. Debugging: Run → Debug Configurations → **CH32v3xx_Cmake** (ELF `obj\CH32v3xx_Cmake.elf`). The Download button programs `obj\CH32v3xx_Cmake.hex` (the `.template` file).

  CodeFlash up to 480K: R0WAIT (zero wait states) and SLOWFLASH (non-zero wait). On CH32V303CB/RB R0WAIT = 128K, SLOWFLASH = 352K from address `0x20000`. CH32V307 has 4 CODE/RAM window modes (`RAM_CODE_MOD`); the mode is set in `User/ch32v307_mem.h` by the `CH32V307_MEM` macro. CMake substitutes the map into the linker; `MemConfig()` in the D8C startup writes the option byte.
  </details>

- **MounRiver Studio 2** — the GCC 15 compiler (`riscv32-wch-elf-gcc`) and OpenOCD with the `wch-riscv.cfg` configuration. `build.bat` uses them when building from Studio 1.92 and from the MCP.

  <details>
  <summary>Where to get it</summary>

  A separate Studio 2 installer is at the same place: [mounriver.com/download](http://www.mounriver.com/download). After installation the toolchain directory **always** contains an archive, not a ready folder:

  `C:\MounRiver\MounRiver_Studio2\resources\app\resources\win32\components\WCH\Toolchain\RISC-V Embedded GCC15.zip`

  Extract the archive **into the same** `Toolchain` directory (in Explorer: "Extract All…", destination — the `Toolchain` folder, without creating an extra nesting level). The result must be the compiler:

  `C:\MounRiver\MounRiver_Studio2\resources\app\resources\win32\components\WCH\Toolchain\RISC-V Embedded GCC15\bin\riscv32-wch-elf-gcc.exe`

  The archive can be left next to it after extraction.
  </details>

- **CMake** version 3.20 or newer.

  <details>
  <summary>Install from PowerShell</summary>

  ```powershell
  winget install --id Kitware.CMake --exact
  ```

  Check: `cmake --version`. Restart MounRiver Studio 1.92 if needed so the IDE picks up the updated PATH; `build.bat` also looks for `cmake.exe` in the standard directories without that.
  </details>

- **Ninja**.

  <details>
  <summary>Install from PowerShell</summary>

  ```powershell
  winget install --id Ninja-build.Ninja --exact
  ```

  Check: `ninja --version`.
  </details>

- **WCH-Link-E** — programmer and debugger over the SDI interface.

  <details>
  <summary>Connection</summary>

  The adapter must be in RISC-V mode: in Windows Device Manager — **WCH-LinkRV**, identifier `VID_1A86&PID_8010`. `PID_8012` means ARM mode; switch it with the **WCH-LinkUtility** from the MounRiver Studio bundle. The adapter's serial channel usually appears as `WCH-Link SERIAL (COMx)`.
  </details>

- **AI** (**Claude**, **Grok**, **Cursor**) — build, flash and debug through the `ch32-wch` MCP.

  <details>
  <summary>How to connect</summary>

  Open **this project's folder** for the agent (the repository root, where `CMakeLists.txt` and `mcp/` are). Ask it to find the MCP server and skills in the tree and install them. The configurations are already in the repository: `.mcp.json`, `.claude/`, `.grok/`, `.cursor/mcp.json`; the server is `mcp/server.py`; the skills are `.claude/skills/ch32-wch` and `.grok/skills/ch32-wch`.
  </details>

### Hardware verification

Building, flashing, USART and GDB were run on a **CH32V303CBT** (`ChipID` `30330514`) and on a **CH32V307** (OpenOCD: ROM 288K + RAM 32K), WCH-Link-E programmer, RISC-V mode. USART1: on the 303 — remap **PB6**, on the 307 — **PA9** (as in the EVT); WCH-Link SERIAL 115200.

### How to pick the processor

1. Open `User/chip_select.h`.
2. Set `#define CH32v3xx_CHIP` to `303` or `307`.
3. For CH32V307 — adjust `#define CH32V307_MEM` in `User/ch32v307_mem.h` if needed.
4. Rebuild: the hammer button in MRS 1.92 or `build.bat` in a console. No command-line argument and no IDE configuration is involved — those two files are the single source of truth.

Known limitation: the SVD and the MCU signature in `CH32v3xx_Cmake.launch` / `.template` statically point to CH32V303 (the board the project was verified on). Loading and debugging the ELF work correctly for any selected chip; to make the peripheral register view in the debugger match CH32V307, edit `svdPath` in `.launch` by hand.

### License

The project layer (CMake, scripts, MCP, `User/main.c`) is **[0BSD](LICENSE)**: use, copying and distribution without restriction and without an attribution requirement.

The peripheral-library and EVT files from Nanjing Qinheng (the `Core/`, `Peripheral/`, `Startup/`, `Debug/debug.*`, `system_ch32v30x.*` directories and related headers) are **not** covered by 0BSD: the WCH condition applies — for this manufacturer's microcontrollers only.

Author: [mamkincoderr](https://github.com/mamkincoderr) · [Telegram](https://t.me/oDeXteRo)

---

## 中文

面向 **WCH CH32V303** 和 **CH32V307** 微控制器（RISC-V QingKe V4F 内核）的演示固件与工程模板。

**用途。** 单一源码树同时服务 CH32V30x 系列的两款芯片。工程师的主要工作环境是 **MounRiver Studio 1.92**：编辑、构建、烧录和调试。编译不由该 IDE 内置的 makefile 生成器完成，而是由可复现的 CMake / Ninja 链配合 **MounRiver Studio 2** 自带的 **RISC-V GCC 15** 完成；Studio 1.92 通过其 Build 命令（`build.bat`）调用它，并烧录生成的 hex。对于软件智能体（**Claude**、**Grok**、**Cursor**），仓库提供 `ch32-wch` MCP 服务器，执行相同的构建、烧录和调试操作。

`#WCH` `#CH32V303` `#CH32V307` `#CH32V30x` `#MRS` `#Claude` `#Grok` `#Cursor`

### 选择芯片——手动，在单个文件中

芯片不通过命令行开关选择，也不与 IDE 配置绑定——它是 `User/chip_select.h` 中的一行：

```c
#define CH32v3xx_CHIP   303   /* 或 307 */
```

改动数值后重新构建（控制台中的 `build.bat`，或 MRS 中的锤子按钮，均无需参数）。一个 `obj/`、一个产物 `CH32v3xx_Cmake.elf/.hex`、一个 MRS 配置。它同时是一个普通的 `#include`——不是 CMake 生成的头文件，也不是 `-D` 标志——因此 MRS 1.92 编辑器能正确地将源码中未激活的 `#if`/`#elif` 分支置灰：Eclipse CDT 索引器与真实编译器看到相同的取值。

CH32V307 另有 `User/ch32v307_mem.h`，以同样方式选择 Flash/RAM 划分（`RAM_CODE_MOD`）：`MEM288_32` / `MEM256_64` / `MEM224_96` / `MEM192_128`。

### 系统要求

- **Windows**

- **MounRiver Studio 1.92**——主要开发环境：源码、Build、Download、调试器。

  <details>
  <summary>从哪里获取</summary>

  发行版在开发商网站：[mounriver.com/download](http://www.mounriver.com/download)。安装 Studio 1.9.x（1.92 分支）。在 IDE 中打开本仓库的 `CH32v3xx_Cmake.wvproj` 文件。

  工程只有一个构建配置（**Default**）。锤子按钮调用无参数的 `build.bat`——芯片取自 `User/chip_select.h`。调试：Run → Debug Configurations → **CH32v3xx_Cmake**（ELF `obj\CH32v3xx_Cmake.elf`）。Download 按钮烧录 `obj\CH32v3xx_Cmake.hex`（`.template` 文件）。

  CodeFlash 最大 480K：R0WAIT（零等待）和 SLOWFLASH（非零等待）。CH32V303CB/RB 的 R0WAIT = 128K，SLOWFLASH = 352K，起始地址 `0x20000`。CH32V307 有 4 种 CODE/RAM 窗口模式（`RAM_CODE_MOD`），模式在 `User/ch32v307_mem.h` 中由 `CH32V307_MEM` 宏设定。CMake 将存储器映射代入链接器；D8C 启动文件中的 `MemConfig()` 写入选项字节。
  </details>

- **MounRiver Studio 2**——GCC 15 编译器（`riscv32-wch-elf-gcc`）和带 `wch-riscv.cfg` 配置的 OpenOCD。从 Studio 1.92 及从 MCP 构建时，`build.bat` 都会使用它们。

  <details>
  <summary>从哪里获取</summary>

  Studio 2 的独立安装程序在同一处：[mounriver.com/download](http://www.mounriver.com/download)。安装后，工具链目录中**始终**是一个压缩包，而不是现成的文件夹：

  `C:\MounRiver\MounRiver_Studio2\resources\app\resources\win32\components\WCH\Toolchain\RISC-V Embedded GCC15.zip`

  将压缩包解压**到同一个** `Toolchain` 目录（在资源管理器中：「全部解压…」，目标路径为 `Toolchain` 文件夹，不要多出一层嵌套）。结果应当是编译器：

  `C:\MounRiver\MounRiver_Studio2\resources\app\resources\win32\components\WCH\Toolchain\RISC-V Embedded GCC15\bin\riscv32-wch-elf-gcc.exe`

  解压后压缩包可留在旁边。
  </details>

- **CMake** 3.20 或更高版本。

  <details>
  <summary>从 PowerShell 安装</summary>

  ```powershell
  winget install --id Kitware.CMake --exact
  ```

  检查：`cmake --version`。必要时重启 MounRiver Studio 1.92，让 IDE 获取更新后的 PATH；即便不重启，`build.bat` 也会在标准目录中查找 `cmake.exe`。
  </details>

- **Ninja**。

  <details>
  <summary>从 PowerShell 安装</summary>

  ```powershell
  winget install --id Ninja-build.Ninja --exact
  ```

  检查：`ninja --version`。
  </details>

- **WCH-Link-E**——通过 SDI 接口的编程器和调试器。

  <details>
  <summary>连接</summary>

  适配器必须处于 RISC-V 模式：在 Windows 设备管理器中显示为 **WCH-LinkRV**，标识 `VID_1A86&PID_8010`。`PID_8012` 表示 ARM 模式；用 MounRiver Studio 附带的 **WCH-LinkUtility** 工具切换。适配器的串口通道通常显示为 `WCH-Link SERIAL (COMx)`。
  </details>

- **AI**（**Claude**、**Grok**、**Cursor**）——通过 `ch32-wch` MCP 构建、烧录和调试。

  <details>
  <summary>如何连接</summary>

  为智能体打开**本工程的文件夹**（仓库根目录，`CMakeLists.txt` 和 `mcp/` 所在处）。让它在目录树中找到 MCP 服务器和技能并安装。配置已在仓库中：`.mcp.json`、`.claude/`、`.grok/`、`.cursor/mcp.json`；服务器为 `mcp/server.py`；技能为 `.claude/skills/ch32-wch` 和 `.grok/skills/ch32-wch`。
  </details>

### 硬件验证

构建、烧录、USART 和 GDB 已在一块 **CH32V303CBT**（`ChipID` `30330514`）和一块 **CH32V307**（OpenOCD：ROM 288K + RAM 32K）上运行，编程器为 WCH-Link-E，RISC-V 模式。USART1：303 上——重映射 **PB6**，307 上——**PA9**（与 EVT 相同）；WCH-Link SERIAL 115200。

### 如何选择处理器

1. 打开 `User/chip_select.h`。
2. 将 `#define CH32v3xx_CHIP` 设为 `303` 或 `307`。
3. 对于 CH32V307——如有需要，调整 `User/ch32v307_mem.h` 中的 `#define CH32V307_MEM`。
4. 重新构建：MRS 1.92 中的锤子按钮或控制台中的 `build.bat`。不涉及任何命令行参数和任何 IDE 配置——这两个文件是唯一的事实来源。

已知限制：`CH32v3xx_Cmake.launch` / `.template` 中的 SVD 和 MCU 签名静态指向 CH32V303（工程验证所用的板子）。对任何所选芯片，ELF 的加载和调试都能正确工作；若要让调试器中的外设寄存器视图匹配 CH32V307，请手动修改 `.launch` 中的 `svdPath`。

### 许可证

工程层（CMake、脚本、MCP、`User/main.c`）为 **[0BSD](LICENSE)**：可无限制地使用、复制和分发，且无需署名。

南京沁恒（Nanjing Qinheng）的外设库和 EVT 文件（`Core/`、`Peripheral/`、`Startup/`、`Debug/debug.*`、`system_ch32v30x.*` 目录及相关头文件）**不**在 0BSD 范围内：适用 WCH 的条件——仅限该厂商的微控制器。

作者：[mamkincoderr](https://github.com/mamkincoderr) · [Telegram](https://t.me/oDeXteRo)
