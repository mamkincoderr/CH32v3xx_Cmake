---
name: ch32-wch
description: >
  Build, flash and debug WCH CH32V303/CH32V307 firmware in this CMake+Ninja
  template over WCH-Link-E. Use when the user asks to compile, download,
  probe, erase, reset, GDB, or OpenOCD this project. Tools live on the
  ch32-wch MCP server (build/flash/debug_start/debug_exec/debug_stop/env).
  Slash command: /ch32-wch
---

# CH32 WCH build / flash / debug

Use **only** the `ch32-wch` MCP tools. Do not use ARM/ST-Link flash-openocd skills. Do not invent OpenOCD command lines.

Project root is the template directory (parent of `mcp/`).

## Tools

1. `env` — cmake, ninja, GCC 15, OpenOCD, GDB, WCH-Link. Need `wch_link.rv_mode=true` (`VID_1A86&PID_8010`). `PID_8012` is ARM mode — switch the adapter with WCH-LinkUtility.
2. `build` — `chip`: `CH32V303` (default) or `CH32V307`. `clean`: bool.
3. `flash` — `mode`: `program` | `probe` | `verify` | `erase` | `reset`. `chip` selects the hex/elf. Program any built image onto the connected probe; do not refuse a CHIP/silicon mismatch.
4. `debug_start` → `debug_exec` → **always** `debug_stop`.

Judge flash success by JSON `ok` (from log markers such as `** Verified OK **`), not OpenOCD's process exit code.

## Debug

- `debug_start(chip)` — OpenOCD GDB server `:3333`, core halted.
- `debug_exec(commands)` — gdb `--batch` list, e.g. `["bt", "info registers pc sp ra", "info line *$pc"]`.
- `debug_stop` — kill the server and `wlink_reset_resume`. Leaving halt stuck the board.

One-shot snapshot: start → exec → stop. Session: start, several execs, stop when done.

## Artifacts

- CH32V303: `obj/CH32V303.elf` / `.hex`
- CH32V307: `obj/CH32V307/CH32V307.elf` / `.hex`

`flash program` needs a prior `build` for that chip. LTO is off in CMake — keep it off for stepping.

## Do not

- Drive MRS GUI; hammer/Download already call `build.bat` / the hex path.
- Manage git or GitHub through this MCP.
