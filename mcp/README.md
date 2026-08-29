# ch32-wch MCP

stdio MCP server for **build / flash / debug** of this CH32V303 / CH32V307 CMake template (WCH-Link-E, OpenOCD, GCC 15).

It does not talk to GitHub. Run it from a clone of this template. Any built image may be programmed onto the probe that is plugged in.

## Install

Python 3.10+:

```bat
pip install -r mcp/requirements.txt
```

Need on the machine: CMake ≥ 3.20, Ninja, MounRiver Studio 2 (GCC 15 + WCH OpenOCD), WCH-Link in RV mode (`VID_1A86&PID_8010`).

Start (cwd = template root):

```bat
python mcp/server.py
```

Do **not** use `python -m mcp.server` — that name clashes with the `mcp` package.

## Tools

Chip (303 vs 307) is not a tool argument — it is hand-picked in `User/chip_select.h`. `build` and `flash` always act on whatever that file currently says; check `obj/built_as.txt` (mirrored in `build`'s result) to see what was actually built.

| Tool | Role |
|---|---|
| `env` | Detect toolchain, OpenOCD, WCH-Link |
| `build` | `clean` (bool). Result includes `chip` from `obj/built_as.txt` |
| `flash` | `mode=program\|probe\|verify\|erase\|reset\|lock\|unlock`, `confirm` (bool, required for `lock`/`unlock`) |
| `debug_start` | GDB server `:3333`, halt, ELF = last build |
| `debug_exec` | gdb `--batch` command list |
| `debug_stop` | kill server + resume core |

`flash(mode="probe")` identifies the connected chip: `device_id`, `flash_kb`, and (when the log carries it) `rom_kb`/`ram_kb`.

`flash(mode="lock"|"unlock")` touch the `wch_riscv` read-protect option byte and refuse to run without `confirm=true`:
- `unlock` disables read-protect — this forces a **mass erase**, all firmware is lost, irreversible.
- `lock` enables read-protect — can leave the chip unprogrammable/undebuggable until unlocked (which then erases it).

Both were verified live against a connected CH32V303 (`unlock` → `Success to Disable Read-Protect`, `lock` → `Success to Enable Read-Protect`, chip stayed reachable, firmware re-flashed afterward).

## Wire it to an AI

Relative `python mcp/server.py`, cwd = корень темплейта.

### Claude Code

Уже в репозитории, подхватывается при открытии папки:

- `.mcp.json` — MCP-сервер (штатный файл Claude Code в корне)
- `.claude/mcp.json` — тот же сервер в папке `.claude/`
- `.claude.json` — дубль в корне, формат Claude
- `.claude/skills/ch32-wch/SKILL.md` — скилл

Либо вручную из корня проекта:

```bat
claude mcp add ch32-wch -- python mcp/server.py
```

### Claude Desktop

Скопировать содержимое `mcp/claude_desktop_config.example.json` в
`%APPDATA%\Claude\claude_desktop_config.json` (слить с уже существующими
`mcpServers`, не затирая чужие). Путь к `server.py` в примере — этот клон;
на другой машине поправь на свой абсолютный путь. Перезапустить Desktop.

### Grok / Cursor

- `.grok/config.toml` + `.grok/skills/ch32-wch/SKILL.md`
- `.cursor/mcp.json`
