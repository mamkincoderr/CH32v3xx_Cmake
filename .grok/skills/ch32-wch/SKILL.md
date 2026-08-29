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
2. `build` — no chip argument. Chip is hand-picked in `User/chip_select.h` (`CH32v3xx_CHIP` 303 or 307), CMake reads that file. `clean`: bool. Result includes `chip` = contents of `obj/built_as.txt` so you can see what was actually built.
3. `flash` — `mode`: `program` | `probe` | `verify` | `erase` | `reset` | `lock` | `unlock`. Uses whatever `build` last produced. Program any built image onto the connected probe; do not refuse a CHIP/silicon mismatch.
   - `probe` identifies the connected chip: `device_id`, `flash_kb` (and `rom_kb`/`ram_kb` when the log carries them).
   - `lock`/`unlock` touch the read-protect option byte and are **refused unless `confirm=true`**. `unlock` forces a mass erase — all firmware lost, irreversible. `lock` can leave the chip unprogrammable/undebuggable until unlocked (which then erases it). Only pass `confirm=true` after the user has explicitly asked for a lock/unlock in this conversation — never default to it or infer approval from an unrelated build/flash request. Verified live on a CH32V303: `unlock` → `Success to Disable Read-Protect`, `lock` → `Success to Enable Read-Protect`, chip stayed reachable both times.
4. `debug_start` → `debug_exec` → **always** `debug_stop`.

Judge flash success by JSON `ok` (from log markers such as `** Verified OK **`), not OpenOCD's process exit code.

## Debug

- `debug_start()` — OpenOCD GDB server `:3333`, core halted, ELF = whatever was last built.
- `debug_exec(commands)` — gdb `--batch` list, e.g. `["bt", "info registers pc sp ra", "info line *$pc"]`.
- `debug_stop` — kill the server and `wlink_reset_resume`. Leaving halt stuck the board.

One-shot snapshot: start → exec → stop. Session: start, several execs, stop when done.

## Artifacts

Single output, chip-independent name: `obj/CH32v3xx_Cmake.elf` / `.hex`. `obj/built_as.txt` says which chip (303/307) that binary actually is — check it before flashing, since it reflects `User/chip_select.h` at the time of the last `build`, not whatever the caller assumes.

`flash program` needs a prior `build`. LTO is off in CMake — keep it off for stepping.

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

- `project(<Name> C ASM)` — single fixed artifact name (`${PROJECT_NAME}`), not a per-chip string. One `obj/`, no CHIP cache variable.
- Chip is selected by hand in a plain tracked header (this template: `User/chip_select.h`, macro `CH32v3xx_CHIP` = 303/307), **not** a CMake cache var / command-line `-DCHIP=`. CMake reads that file with `file(READ) + string(MATCHES)` regex to pick `CHIP_DEFINE` + **one** `STARTUP_FILE` + matching `LINKER_SCRIPT`. This is deliberate, not a shortcut: a CMake `-D`/generated-header scheme is invisible to MRS 1.92's CDT indexer (Managed Build off, no compile_commands.json support in its CDT 6.5), so `#if`/`#elif` greying in the editor goes wrong. A plain header that main.c `#include`s directly resolves the same way for the real compiler and for the indexer. Force-include the same header (`-include`) for the vendor sources (Core/Peripheral/Debug) that don't include it themselves.
- CH32V30x CodeFlash is 480K: R0WAIT (zero-wait, the datasheet "Flash" column) plus SLOWFLASH (non-zero wait). CH32V303CB/RB: FLASH 128K at 0, SLOWFLASH 352K at `0x20000`. CH32V307: SLOWFLASH starts after the CODE window from `#define CH32V307_MEM` in `User/ch32v307_mem.h` (`MEM288_32` / `MEM256_64` / `MEM224_96` / `MEM192_128`) — same hand-edited-header-read-by-regex pattern as the chip pick. CMake generates the 307 MEMORY map. `MemConfig()` is called from `startup_ch32v30x_D8C.S` only — do not rewrite D8. CH32V303CB/RB has no RAM_CODE_MOD.
- `CPU_FLAGS`: V30x keep `rv32imafcxw` / `ilp32f`; V20x use `rv32imacxw` / `ilp32` (no `f`). Do not “upgrade” V203 to `ilp32f`.
- `add_folder_objects` only for directories that contain `*.c` **directly** (not recursive). Extra app folders (`User/Lib`, …) need extra calls.
- Startup: `add_library(objs_startup OBJECT ${STARTUP_FILE})` — never GLOB `Startup/*.S`.
- Post-build: hex, bin, `size`. LTO off unless the user asks (breaks source-level step).
- Link: `-T` the chosen `Ld/*.ld`, `-nostartfiles`, `--specs=nano.specs --specs=nosys.specs`, `--gc-sections`.

`build.bat`: no chip argument — chip comes from the hand-edited header, CMake reconfigures automatically when it changes. Only recognised argument is `clean`; extra Eclipse args (`-j24 all`) are ignored. Artifact: `obj\<ProjectName>.hex`.

## 4. MRS 1.92 (human workflow)

MRS 1.92 remains the engineer IDE. Managed Build **off**. One firmware tree, **one** Eclipse configuration, one `.project`/`.template`/`.launch` — chip is not a build-config axis, it lives in the hand-edited header from step 3.

- `.cproject`: `managedBuildOn="false"`, builder `command=".../build.bat"`, `arguments=""`, `cleanBuildTarget="clean"`. Single `cconfiguration`.
- `.template`: one Download target, `Target Path=obj\<ProjectName>.hex`. The MCU/Series fields are static (pick the primary board) — cosmetic only, OpenOCD doesn't gate on them.
- Debug: one `.launch`. Image/symbols = the single CMake ELF. SVD is also static (`template/wizard/WCH/RISC-V/<primary-chip>/NoneOS/<chip>xx.svd`) — note in docs that switching the hand-edited chip header to the other family means editing `svdPath` too if the register view in the debugger needs to match.
- Exclude unused `startup_*.S` from the indexer (`sourceEntries excluding=`).
- Download and Debug use the hex/elf produced by `build.bat`, not MRS internal make.

## 5. flash.ps1 / MCP

- Point default image/elf at the single CMake output (no chip argument — `flash.ps1`/MCP `flash` always use whatever `build` last produced).
- OpenOCD: same `wch-riscv.cfg` + WCH-Link-E for V20x and V30x.
- `unfreeze` before programming if the image (or `.rodata`) crosses the 128 K zero-wait window; harmless on small V203 images.
- Every halt session except live GDB must end with `wlink_reset_resume`.
- Do not block programming because the chip in `obj/built_as.txt` ≠ `device id` read off the probe.
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
