# CH32v3xx_Cmake

Шаблон прошивки **Hello World** для WCH **CH32V303** и **CH32V307** (RISC-V).

Сборка — **CMake + Ninja** и GCC 15 из MounRiver Studio 2. Тот же проект открывается в **MRS 1.92** (молоток зовёт `build.bat`, Download берёт hex). Прошивка и GDB — **WCH-Link-E / OpenOCD**.

**Зачем.** Один клон, два камня, без ручной возни с makefile MRS. Человек собирает и льёт из консоли или из IDE. ИИ (Claude, Grok, Cursor и другие) делает то же через MCP-сервер `ch32-wch` в комплекте: сборка, прошивка, отладка.

Автор: [mamkincoderr](https://github.com/mamkincoderr) · [Telegram](https://t.me/mamkincoderr)
