# CH32v3xx_Cmake

[![visits](https://hits.sh/github.com/mamkincoderr/CH32v3xx_Cmake.svg?view=today-total&label=visits)](https://hits.sh/github.com/mamkincoderr/CH32v3xx_Cmake/)

Шаблон прошивки **Hello World** для WCH **CH32V303** и **CH32V307** (RISC-V).

**Зачем.** Клонировал — в одном дереве оба кристалла. Сборка не через внутренний makefile MounRiver Studio: CMake и скрипты едут с репой. Человек собирает и льёт из консоли или из IDE. ИИ делает то же через MCP-сервер `ch32-wch` в комплекте: сборка, прошивка, отладка.

`#WCH` `#CH32V303` `#CH32V307` `#CH32V30x` `#MRS` `#Claude` `#Grok` `#Cursor`

## Что нужно, чтобы это работало

- **Windows** и установленные **CMake** (≥ 3.20) и **Ninja**.
- **MounRiver Studio 2** — из него берутся GCC 15 (`riscv32-wch-elf-gcc`) и OpenOCD с `wch-riscv.cfg`.
- **WCH-Link-E** в режиме RISC-V (`VID_1A86&PID_8010`, не ARM `PID_8012`).
- **MRS 1.92** — по желанию, как редактор: молоток вызывает `build.bat`, Download берёт hex. Сама компиляция MRS не управляет.
- Для ИИ (**Claude**, **Grok**, **Cursor**): **Python 3.10+** и `pip install -r mcp/requirements.txt`.

Автор: [mamkincoderr](https://github.com/mamkincoderr) · [Telegram](https://t.me/mamkincoderr)
