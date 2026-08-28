# CH32v3xx_Cmake

[![visits](https://hits.sh/github.com/mamkincoderr/CH32v3xx_Cmake.svg?view=today-total&label=visits)](https://hits.sh/github.com/mamkincoderr/CH32v3xx_Cmake/)

Демонстрационная прошивка и шаблон рабочего проекта для микроконтроллеров **WCH CH32V303** и **CH32V307** (ядро RISC-V QingKe V4F).

**Назначение.** Единое дерево исходных текстов обслуживает оба кристалла семейства CH32V30x. Основная среда работы инженера — **MounRiver Studio 1.92**: редактирование, сборка, загрузка во flash и отладка. Компиляция выполняется не встроенным генератором makefile этой IDE, а воспроизводимой цепочкой CMake / Ninja и **RISC-V GCC 15** из комплекта **MounRiver Studio 2**; Studio 1.92 вызывает её командой Build (`build.bat`) и программирует полученный hex. Для программных агентов (**Claude**, **Grok**, **Cursor**) в репозитории поставляется MCP-сервер `ch32-wch`, выполняющий те же операции сборки, программирования и отладки.

`#WCH` `#CH32V303` `#CH32V307` `#CH32V30x` `#MRS` `#Claude` `#Grok` `#Cursor`

## Системные требования

- **Windows**

- **MounRiver Studio 1.92** — основная среда разработки: исходники, Build, Download, отладчик.

  <details>
  <summary>Где взять</summary>

  Дистрибутив — на сайте разработчика: [mounriver.com/download](http://www.mounriver.com/download). Установить Studio 1.9.x (ветка 1.92). Открыть в IDE файл `CH32v3xx_Cmake.wvproj` этого репозитория.
  </details>

- **MounRiver Studio 2** — компилятор GCC 15 (`riscv32-wch-elf-gcc`) и OpenOCD с конфигурацией `wch-riscv.cfg`. Их использует `build.bat` при сборке из Studio 1.92 и из MCP.

  <details>
  <summary>Где взять</summary>

  Отдельный установщик Studio 2 — там же: [mounriver.com/download](http://www.mounriver.com/download). Типовой путь после установки:

  `C:\MounRiver\MounRiver_Studio2\`

  Если в `...\WCH\Toolchain\` лежит архив `RISC-V Embedded GCC15.zip`, его нужно распаковать на месте, чтобы появилась папка `RISC-V Embedded GCC15\bin` с `riscv32-wch-elf-gcc.exe`.
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

- **Python 3.10** или новее — только если сборкой и отладкой будет управлять ИИ через MCP.

  <details>
  <summary>Установка из PowerShell</summary>

  ```powershell
  winget install --id Python.Python.3.12 --exact
  python -m pip install -r mcp/requirements.txt
  ```

  Выполнять из корня клонированного репозитория. Не запускать сервер командой `python -m mcp.server` — имя модуля совпадает с пакетом SDK.
  </details>

Автор: [mamkincoderr](https://github.com/mamkincoderr) · [Telegram](https://t.me/oDeXteRo)
