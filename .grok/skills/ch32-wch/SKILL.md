---
name: ch32-wch
description: >
  Build, flash and debug WCH CH32V303/CH32V307 firmware in this CMake+Ninja
  template over WCH-Link-E. Convert a classic MRS CH32V20x/CH32V30x project
  to this layout. Use when the user asks to compile, download, probe, erase,
  reset, GDB, OpenOCD, or to migrate/convert a CH32V project. Tools live on
  the ch32-wch MCP server (build/flash/debug_start/debug_exec/debug_stop/env).
  Slash command: /ch32-wch
---

# CH32 WCH build / flash / debug

Use **only** the `ch32-wch` MCP tools in a project that already has them. Do not use ARM/ST-Link flash-openocd skills. Do not invent OpenOCD command lines.

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

---

# Convert any CH32V MRS project to this layout

When the user asks to migrate a WCH CH32V firmware tree (typical MRS 1.9 folders `Core/`, `Peripheral/`, `Startup/`, `User/`, `Debug/`, `Ld/`) so it builds like this template: **keep application sources**, **replace only the build/debug shell**. Do not rewrite User logic. Do not mix V20x and V30x SPL trees.

Official EVT (source of truth for macros, startup, linker comments):

- CH32V30x: https://github.com/openwch/ch32v307
- CH32V20x: https://github.com/openwch/ch32v20x

## 1. Identify the silicon (do this first)

Read `Peripheral/inc/ch32v30x.h` or `ch32v20x.h` (the `#if !defined(...D6/D8...)` block) and the files in `Startup/`. Pick **one** family row. Never GLOB all `startup_*.S` — duplicate `Reset_Handler` / vector table.

| Family | Header macro | Startup (exactly one) | Typical `-march` / `-mabi` | Notes |
|---|---|---|---|---|
| CH32V303 | `CH32V30x_D8` | `startup_ch32v30x_D8.S` | `rv32imafcxw` / `ilp32f` | FPU. CB/RB: FLASH 128K + RAM 32K |
| CH32V307 / 305 / 317 | `CH32V30x_D8C` | `startup_ch32v30x_D8C.S` | `rv32imafcxw` / `ilp32f` | Extra vectors (ETH, USBHS, CAN2). EVT default FLASH 288K + RAM 32K |
| CH32V203 F6/G6/K6/C6 | `CH32V20x_D6` | `startup_ch32v20x_D6.S` | `rv32imacxw` / `ilp32` | **No FPU.** FLASH 32K + RAM 10K |
| CH32V203 F8/G8/K8/C8 | `CH32V20x_D6` | `startup_ch32v20x_D6.S` | `rv32imacxw` / `ilp32` | FLASH 64K + RAM 20K |
| CH32V203RBT6 | `CH32V20x_D8` | `startup_ch32v20x_D8.S` | `rv32imacxw` / `ilp32` | HSE often 32 MHz. FLASH 128K class |
| CH32V208 | `CH32V20x_D8W` | `startup_ch32v20x_D8W.S` | `rv32imacxw` / `ilp32` | BLE/ETH; HSE often 32 MHz. FLASH 128K + RAM 64K class |

CH32V003 / QingKe V2 (`rv32ec`) is a **different** core and not this template. CH32V103 is closer to V20x than to V30x; still use its own EVT headers, not V30x `Peripheral/`.

Pass the macro as a **compiler definition** (`-DCH32V30x_D8` etc.). Do not edit the vendor `#define` defaults inside the header if the CMake `-D` already selects the variant.

Linker `MEMORY` lengths: copy the commented maps from that family's official `EVT/EXAM/SRC/Ld/Link.ld`. Stack size in the script must fit RAM.

## 2. Copy the shell from this template

From `CH32v3xx_Cmake` into the target project (overwrite only build wrappers, not `User/`):

```
cmake/toolchain-wch-gcc15.cmake
CMakeLists.txt          (then edit — step 3)
build.bat
flash.ps1  flash.bat
mcp/                    (server.py, requirements.txt)
.mcp.json  .claude.json  .claude/mcp.json  .claude/skills/ch32-wch/
.cursor/mcp.json
.grok/config.toml  .grok/skills/ch32-wch/
```

Keep the target's `Core/`, `Peripheral/`, `Startup/`, `Debug/`, `Ld/`, `User/` if they already match the silicon. If the target is V20x, those trees **must** come from CH32V20x EVT, not from this V30x template.

`toolchain-wch-gcc15.cmake` is family-agnostic (finds `riscv32-wch-elf-gcc`). Leave it.

## 3. Adapt CMakeLists.txt

- `project(<Name> C ASM)` — artifact names follow this or the `CHIP` cache string.
- `CHIP` cache + `CHIP_DEFINE` + **one** `STARTUP_FILE` + matching `LINKER_SCRIPT`.
- `CPU_FLAGS`: V30x keep `rv32imafcxw` / `ilp32f`; V20x use `rv32imacxw` / `ilp32` (no `f`). Do not “upgrade” V203 to `ilp32f`.
- `add_folder_objects` only for directories that contain `*.c` **directly** (not recursive). Extra app folders (`User/Lib`, …) need extra calls.
- Startup: `add_library(objs_startup OBJECT ${STARTUP_FILE})` — never GLOB `Startup/*.S`.
- Post-build: hex, bin, `size`. LTO off unless the user asks (breaks source-level step).
- Link: `-T` the chosen `Ld/*.ld`, `-nostartfiles`, `--specs=nano.specs --specs=nosys.specs`, `--gc-sections`.

`build.bat`: default CHIP = the board on the desk; extra Eclipse args (`-j24 all` / `clean`) must be scanned in all `%*`. Default V30x hex for MRS: `obj\<CHIP>.hex` in the configuration named `obj`.

## 4. MRS 1.92 (human workflow)

MRS 1.92 remains the engineer IDE. Managed Build **off**:

- `.cproject`: `managedBuildOn="false"`, builder `command=".../build.bat"`, `cleanBuildTarget="clean"`.
- `.template`: `Target Path=obj\<artifact>.hex`, `Series` / `MCU` = actual part (e.g. CH32V303CBT6 or CH32V203C8T6).
- Exclude unused `startup_*.S` from the indexer (`sourceEntries excluding=`).
- Download and Debug use the hex/elf produced by `build.bat`, not MRS internal make.

## 5. flash.ps1 / MCP

- Point default image/elf at the CMake outputs.
- OpenOCD: same `wch-riscv.cfg` + WCH-Link-E for V20x and V30x.
- `unfreeze` before programming if the image (or `.rodata`) crosses the 128 K zero-wait window; harmless on small V203 images.
- Every halt session except live GDB must end with `wlink_reset_resume`.
- MCP `CHIPS` / `build` / `flash` arguments: add the new part names if you introduce V203/V208. Do not block programming because CHIP ≠ `device id`.
- Success: log markers (`** Verified OK **`, `flash 'wch_riscv' found at`), not OpenOCD exit code.

## 6. Verify

1. `build.bat` (or MCP `build`) — link map FLASH/RAM within the script limits.
2. `flash.ps1 probe` — adapter RV, a `device id` is printed.
3. `flash.ps1` — `** Verified OK **`.
4. If USART printf exists: confirm TX pin (this template: USART1 remap **PB6**; official EVT USART_Printf is often **PA9**). Wrong pin is not a CMake failure.

## CH32V20x — what changes, what does not

**Does not change:** MRS 1.92 as the human IDE, `build.bat` + CMake + GCC 15 from MRS2, `flash.ps1` / OpenOCD `wch-riscv.cfg`, MCP tool names, skill workflow, WCH-Link RV mode.

**Must change:** vendor tree (`ch32v20x.h`, `system_ch32v20x.c`, `Peripheral/*`, startups), `CPU_FLAGS` without FPU, `MEMORY` in `Link.ld`, HSE value (8 MHz vs 32 MHz on RB/V208 — follow EVT comments), USART pin if the board is not this DCDC/WCH-Link SERIAL layout.

**Not verified on hardware** in this repository (no V20x board). After the first image: `probe`, then a blink or `USART_Printf` from official EVT. If OpenOCD examines the core (`XLEN=32`) but the program silent, check clock (HSE), linker sizes, and UART pin before rewriting CMake.

## Do not when converting

- Copy `Peripheral/` from a V307 tree into a V203 project.
- Enable every `startup_*.S` “to be safe”.
- Use ST-Link OpenOCD scripts.
- Flatten V20x FPU flags to match V307.
- Claim V20x flash/debug is proven if you only compiled.
