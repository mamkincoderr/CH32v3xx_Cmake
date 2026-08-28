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

| Tool | Role |
|---|---|
| `env` | Detect toolchain, OpenOCD, WCH-Link |
| `build` | `chip=CH32V303\|CH32V307`, `clean` |
| `flash` | `mode=program\|probe\|verify\|erase\|reset`, `chip` |
| `debug_start` | GDB server `:3333`, halt |
| `debug_exec` | gdb `--batch` command list |
| `debug_stop` | kill server + resume core |

## Wire it to an AI

Configs in this repo (relative `python mcp/server.py`, cwd = project root):

- `.mcp.json` — Claude Code, Grok, others that scan the standard file
- `.grok/config.toml` — Grok project scope
- `.cursor/mcp.json` — Cursor

Claude Desktop — absolute path in `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "ch32-wch": {
      "command": "python",
      "args": ["C:/path/to/CH32v3xx_Cmake/mcp/server.py"]
    }
  }
}
```

Agent rules: `.grok/skills/ch32-wch/SKILL.md` (copy into your agent's skills folder if it is not Grok).
