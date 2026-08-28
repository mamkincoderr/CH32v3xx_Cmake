#!/usr/bin/env python3
"""stdio MCP: build / flash / debug CH32V303 and CH32V307 via WCH-Link-E.

Author: mamkincoderr
  https://github.com/mamkincoderr
  https://t.me/mamkincoderr

Project root is the parent of this file's directory (the template root).
Run as:  python mcp/server.py
Do not run as python -m mcp.server — that shadows the `mcp` package.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

from mcp.server.fastmcp import FastMCP

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CHIPS = ("CH32V303", "CH32V307")
FLASH_MODES = ("program", "probe", "verify", "erase", "reset")
GDB_PORT = 3333

_ocd_proc: Optional[subprocess.Popen] = None
_ocd_log: Optional[Path] = None
_debug_chip: str = "CH32V303"

mcp = FastMCP(
    "ch32-wch",
    instructions=(
        "Build, flash and debug WCH CH32V303/CH32V307 firmware in this "
        "CMake+Ninja template using WCH-Link-E / OpenOCD. Any built image "
        "may be programmed onto the connected probe."
    ),
)


def _ok(ok: bool, **fields) -> str:
    payload = {"ok": ok, **fields}
    return json.dumps(payload, ensure_ascii=False, indent=2)


def _normalize_chip(chip: str) -> str:
    c = (chip or "CH32V303").strip().upper()
    if c in ("303", "V303"):
        c = "CH32V303"
    if c in ("307", "V307"):
        c = "CH32V307"
    if c not in CHIPS:
        raise ValueError(f"chip must be one of {CHIPS}, got {chip!r}")
    return c


def _chip_dir(chip: str) -> Path:
    if chip == "CH32V303":
        return PROJECT_ROOT / "obj"
    return PROJECT_ROOT / "obj" / chip


def _artifact(chip: str, ext: str) -> Path:
    return _chip_dir(chip) / f"{chip}.{ext}"


def _drives() -> list[str]:
    return ["C", "D", "E", "F"]


def _which(name: str) -> Optional[Path]:
    from shutil import which

    p = which(name)
    return Path(p) if p else None


def _find_toolchain_bin() -> Optional[Path]:
    env = os.environ.get("WCH_TOOLCHAIN_DIR")
    if env and (Path(env) / "riscv32-wch-elf-gcc.exe").is_file():
        return Path(env)
    found = _which("riscv32-wch-elf-gcc")
    if found:
        return found.parent
    for d in _drives():
        for root in (
            Path(f"{d}:/MounRiver/MounRiver_Studio2"),
            Path(f"{d}:/Program Files/MounRiver/MounRiver_Studio2"),
            Path(f"{d}:/Program Files (x86)/MounRiver/MounRiver_Studio2"),
        ):
            bin_dir = (
                root
                / "resources/app/resources/win32/components/WCH/Toolchain"
                / "RISC-V Embedded GCC15/bin"
            )
            if (bin_dir / "riscv32-wch-elf-gcc.exe").is_file():
                return bin_dir
    return None


def _find_openocd() -> tuple[Optional[Path], Optional[Path]]:
    env = os.environ.get("WCH_OPENOCD_DIR")
    cands: list[Path] = []
    if env:
        cands.append(Path(env))
    tail = Path("resources/app/resources/win32/components/WCH/OpenOCD/OpenOCD/bin")
    for d in _drives():
        cands.append(Path(f"{d}:/MounRiver/MounRiver_Studio2") / tail)
        cands.append(Path(f"{d}:/Program Files/MounRiver/MounRiver_Studio2") / tail)
        cands.append(Path(f"{d}:/MounRiver/MounRiver_Studio/toolchain/OpenOCD/bin"))
    for c in cands:
        exe = c / "openocd.exe"
        cfg = c / "wch-riscv.cfg"
        if exe.is_file() and cfg.is_file():
            return exe, cfg
    return None, None


def _wch_link() -> dict:
    cmd = [
        "powershell",
        "-NoProfile",
        "-Command",
        (
            "Get-PnpDevice -PresentOnly | "
            "Where-Object { $_.InstanceId -match 'VID_1A86' } | "
            "Select-Object Status, FriendlyName, InstanceId | ConvertTo-Json -Compress"
        ),
    ]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=15)
        raw = (p.stdout or "").strip()
        data = json.loads(raw) if raw else []
        if isinstance(data, dict):
            data = [data]
    except (subprocess.TimeoutExpired, json.JSONDecodeError, OSError):
        data = []
    rv = [x for x in data if "PID_8010" in str(x.get("InstanceId", ""))]
    arm = [x for x in data if "PID_8012" in str(x.get("InstanceId", ""))]
    com = None
    for x in data:
        m = re.search(r"\(COM(\d+)\)", str(x.get("FriendlyName", "")), re.I)
        if m:
            com = f"COM{m.group(1)}"
            break
    return {
        "rv_mode": bool(rv),
        "arm_mode": bool(arm),
        "devices": data,
        "serial": com,
    }


def _run(cmd: list[str], timeout: int) -> tuple[int, str]:
    p = subprocess.run(
        cmd,
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )
    out = (p.stdout or "") + (p.stderr or "")
    return p.returncode, out


def _flash_ok(mode: str, log: str) -> bool:
    if f"OK: {mode} succeeded." in log:
        return True
    if mode == "program":
        return "** Verified OK **" in log
    if mode == "verify":
        return bool(re.search(r"verified|Verified OK", log, re.I))
    if mode == "erase":
        return "erased sectors" in log
    if mode == "probe":
        return "flash 'wch_riscv' found at" in log
    return "wlink_init ok" in log


def _kill_ocd() -> None:
    global _ocd_proc, _ocd_log
    proc = _ocd_proc
    _ocd_proc = None
    if proc is None:
        return
    if proc.poll() is None:
        try:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=3)
        except OSError:
            pass


@mcp.tool(description="Detect cmake, ninja, WCH GCC15, OpenOCD, GDB and WCH-Link-E on this machine.")
def env() -> str:
    gcc_bin = _find_toolchain_bin()
    ocd_exe, ocd_cfg = _find_openocd()
    cmake = _which("cmake") or _which("cmake.exe")
    ninja = _which("ninja") or _which("ninja.exe")
    gcc = (gcc_bin / "riscv32-wch-elf-gcc.exe") if gcc_bin else None
    gdb = (gcc_bin / "riscv32-wch-elf-gdb.exe") if gcc_bin else None
    link = _wch_link()
    return _ok(
        True,
        project_root=str(PROJECT_ROOT),
        cmake=str(cmake) if cmake else None,
        ninja=str(ninja) if ninja else None,
        gcc=str(gcc) if gcc and gcc.is_file() else None,
        gdb=str(gdb) if gdb and gdb.is_file() else None,
        openocd=str(ocd_exe) if ocd_exe else None,
        openocd_cfg=str(ocd_cfg) if ocd_cfg else None,
        wch_link=link,
        ready=bool(cmake and ninja and gcc and gcc.is_file() and ocd_exe),
    )


@mcp.tool(description="Build firmware with build.bat (CMake+Ninja, GCC 15). chip=CH32V303|CH32V307.")
def build(chip: str = "CH32V303", clean: bool = False) -> str:
    chip = _normalize_chip(chip)
    bat = PROJECT_ROOT / "build.bat"
    cmd = ["cmd", "/c", str(bat), chip]
    if clean:
        cmd.append("clean")
    try:
        code, log = _run(cmd, timeout=180)
    except subprocess.TimeoutExpired:
        return _ok(False, chip=chip, error="build timed out")
    hex_path = _artifact(chip, "hex")
    elf_path = _artifact(chip, "elf")
    success = code == 0 and (clean or hex_path.is_file())
    return _ok(
        success,
        chip=chip,
        clean=clean,
        exit_code=code,
        hex=str(hex_path) if hex_path.is_file() else None,
        elf=str(elf_path) if elf_path.is_file() else None,
        log=log[-8000:],
    )


@mcp.tool(
    description=(
        "Flash via flash.ps1 / WCH-Link-E OpenOCD. "
        "mode=program|probe|verify|erase|reset. chip selects the hex/elf. "
        "Does not compare CHIP to silicon — any image may be programmed."
    )
)
def flash(mode: str = "program", chip: str = "CH32V303") -> str:
    chip = _normalize_chip(chip)
    mode = (mode or "program").strip().lower()
    if mode not in FLASH_MODES:
        return _ok(False, error=f"mode must be one of {FLASH_MODES}")
    ps1 = PROJECT_ROOT / "flash.ps1"
    cmd = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(ps1),
        mode,
        chip,
    ]
    try:
        code, log = _run(cmd, timeout=90)
    except subprocess.TimeoutExpired:
        return _ok(False, chip=chip, mode=mode, error="flash timed out")
    success = _flash_ok(mode, log)
    id_m = re.search(r"device id\s*=\s*(0x[0-9a-fA-F]+)", log)
    return _ok(
        success,
        chip=chip,
        mode=mode,
        exit_code=code,
        device_id=id_m.group(1) if id_m else None,
        image=str(_artifact(chip, "hex")) if mode in ("program", "verify") else None,
        log=log[-8000:],
    )


@mcp.tool(description="Start OpenOCD GDB server on localhost:3333 and halt the core. chip selects the ELF for later debug_exec.")
def debug_start(chip: str = "CH32V303") -> str:
    global _ocd_proc, _ocd_log, _debug_chip
    chip = _normalize_chip(chip)
    _kill_ocd()
    ocd_exe, ocd_cfg = _find_openocd()
    if not ocd_exe or not ocd_cfg:
        return _ok(False, error="openocd.exe / wch-riscv.cfg not found")
    elf = _artifact(chip, "elf")
    log_path = PROJECT_ROOT / "obj" / "openocd-gdb.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_f = open(log_path, "w", encoding="utf-8", errors="replace")
    flags = 0
    if os.name == "nt":
        flags = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
    try:
        proc = subprocess.Popen(
            [str(ocd_exe), "-f", str(ocd_cfg), "-c", "init", "-c", "halt"],
            cwd=str(PROJECT_ROOT),
            stdout=log_f,
            stderr=subprocess.STDOUT,
            creationflags=flags,
        )
    except OSError as e:
        log_f.close()
        return _ok(False, error=str(e))
    _ocd_proc = proc
    _ocd_log = log_path
    _debug_chip = chip
    deadline = time.time() + 15
    text = ""
    while time.time() < deadline:
        if proc.poll() is not None:
            log_f.flush()
            text = log_path.read_text(encoding="utf-8", errors="replace")
            _ocd_proc = None
            return _ok(False, error="OpenOCD exited", log=text[-4000:])
        time.sleep(0.25)
        log_f.flush()
        text = log_path.read_text(encoding="utf-8", errors="replace")
        if "Listening on port 3333" in text:
            return _ok(
                True,
                port=GDB_PORT,
                chip=chip,
                elf=str(elf) if elf.is_file() else None,
                gdb=f'riscv32-wch-elf-gdb "{elf}" -ex "target remote :3333"',
            )
    return _ok(False, error="timeout waiting for GDB port 3333", log=text[-4000:])


@mcp.tool(description="Run gdb --batch commands against the OpenOCD server started by debug_start. Example commands: ['bt','info registers pc sp ra'].")
def debug_exec(commands: list[str]) -> str:
    if _ocd_proc is None or _ocd_proc.poll() is not None:
        return _ok(False, error="GDB server is not running — call debug_start first")
    if not commands:
        return _ok(False, error="commands must be a non-empty list of gdb commands")
    gcc_bin = _find_toolchain_bin()
    gdb = (gcc_bin / "riscv32-wch-elf-gdb.exe") if gcc_bin else None
    if not gdb or not gdb.is_file():
        return _ok(False, error="riscv32-wch-elf-gdb not found")
    elf = _artifact(_debug_chip, "elf")
    cmd = [str(gdb), "--batch", "-q"]
    if elf.is_file():
        cmd.append(str(elf))
    cmd += [
        "-ex", "set pagination off",
        "-ex", "set confirm off",
        "-ex", f"target remote :{GDB_PORT}",
    ]
    for c in commands:
        cmd.extend(["-ex", c])
    try:
        code, log = _run(cmd, timeout=30)
    except subprocess.TimeoutExpired:
        return _ok(False, error="gdb timed out")
    return _ok(code == 0, chip=_debug_chip, exit_code=code, output=log[-8000:])


@mcp.tool(description="Stop the GDB server and resume the core (wlink_reset_resume). Always call this after debug_start.")
def debug_stop() -> str:
    _kill_ocd()
    ps1 = PROJECT_ROOT / "flash.ps1"
    cmd = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(ps1),
        "reset",
    ]
    try:
        code, log = _run(cmd, timeout=30)
    except subprocess.TimeoutExpired:
        return _ok(False, error="reset timed out after killing OpenOCD")
    success = _flash_ok("reset", log)
    return _ok(success, exit_code=code, log=log[-4000:])


def _selftest() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    print(env())
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--selftest":
        raise SystemExit(_selftest())
    mcp.run()
