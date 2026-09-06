"""Hardware-free unit tests for mcp/server.py.

No WCH-Link-E, no build, no OpenOCD — only the pure parsing and guard
logic is exercised. Runs under either runner:

    python -m unittest discover -s mcp/tests
    pytest mcp/tests

Author: mamkincoderr  https://github.com/mamkincoderr
"""

from __future__ import annotations

import asyncio
import json
import sys
import unittest
from pathlib import Path

# server.py is meant to be imported as a top-level module (as `python
# mcp/server.py` does), not as a package — add its dir, not the repo root,
# so the installed `mcp` package is not shadowed.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import server  # noqa: E402


class OkPayload(unittest.TestCase):
    def test_ok_true(self):
        self.assertEqual(json.loads(server._ok(True, foo="bar")), {"ok": True, "foo": "bar"})

    def test_ok_false_keeps_fields(self):
        d = json.loads(server._ok(False, error="boom", mode="lock"))
        self.assertFalse(d["ok"])
        self.assertEqual(d["error"], "boom")
        self.assertEqual(d["mode"], "lock")

    def test_ok_is_valid_json_utf8(self):
        # ensure_ascii=False path — a non-ASCII field must round-trip
        d = json.loads(server._ok(True, note="прошивка"))
        self.assertEqual(d["note"], "прошивка")


class FlashGuards(unittest.TestCase):
    def test_unknown_mode_rejected_before_hardware(self):
        d = json.loads(server.flash(mode="wipe-everything"))
        self.assertFalse(d["ok"])
        self.assertIn("mode must be one of", d["error"])

    def test_destructive_modes_need_confirm(self):
        for mode in server.DESTRUCTIVE_FLASH_MODES:
            d = json.loads(server.flash(mode=mode, confirm=False))
            self.assertFalse(d["ok"], mode)
            self.assertEqual(d["mode"], mode)
            self.assertIn("confirm=true", d["error"])

    def test_destructive_modes_are_a_subset_of_all_modes(self):
        self.assertTrue(set(server.DESTRUCTIVE_FLASH_MODES) <= set(server.FLASH_MODES))

    def test_mode_is_normalised(self):
        d = json.loads(server.flash(mode="  UNLOCK  ", confirm=False))
        self.assertEqual(d["mode"], "unlock")


class FlashLogParser(unittest.TestCase):
    def test_program_needs_verified_ok(self):
        self.assertTrue(server._flash_ok("program", "...\n** Verified OK **\n..."))
        self.assertFalse(server._flash_ok("program", "download done, no verify line"))

    def test_mode_specific_success_markers(self):
        self.assertTrue(server._flash_ok("erase", "erased sectors 0 to 7 in 1.2s"))
        self.assertTrue(server._flash_ok("probe", "flash 'wch_riscv' found at 0x08000000"))
        self.assertTrue(server._flash_ok("verify", "** Verified OK **"))
        self.assertTrue(server._flash_ok("reset", "wlink_init ok"))

    def test_generic_success_line_wins(self):
        self.assertTrue(server._flash_ok("reset", "OK: reset succeeded."))


class ArtifactPaths(unittest.TestCase):
    def test_names_and_dir(self):
        self.assertEqual(server._artifact("hex").name, "CH32v3xx_Cmake.hex")
        self.assertEqual(server._artifact("elf").name, "CH32v3xx_Cmake.elf")
        self.assertEqual(server._artifact("bin").parent, server.BUILD_DIR)


class DebugGuards(unittest.TestCase):
    def test_debug_exec_without_server(self):
        server._ocd_proc = None
        d = json.loads(server.debug_exec(["bt"]))
        self.assertFalse(d["ok"])
        self.assertIn("debug_start", d["error"])

    def test_debug_exec_rejects_empty_commands(self):
        # a running-looking sentinel so we get past the server check
        class _Fake:
            def poll(self):
                return None

        server._ocd_proc = _Fake()
        try:
            d = json.loads(server.debug_exec([]))
            self.assertFalse(d["ok"])
            self.assertIn("non-empty list", d["error"])
        finally:
            server._ocd_proc = None


class ToolAnnotations(unittest.TestCase):
    def test_every_tool_advertises_hints(self):
        tools = asyncio.run(server.mcp.list_tools())
        self.assertTrue(tools, "no tools registered")
        by_name = {t.name: t for t in tools}
        self.assertEqual(
            set(by_name),
            {"env", "build", "flash", "debug_start", "debug_exec", "debug_stop"},
        )
        for name, t in by_name.items():
            self.assertIsNotNone(t.annotations, f"{name}: no annotations")
            self.assertIsNotNone(t.annotations.readOnlyHint, f"{name}: no readOnlyHint")

    def test_flash_is_flagged_destructive_and_open_world(self):
        tools = {t.name: t for t in asyncio.run(server.mcp.list_tools())}
        self.assertTrue(tools["flash"].annotations.destructiveHint)
        self.assertTrue(tools["flash"].annotations.openWorldHint)
        self.assertFalse(tools["flash"].annotations.readOnlyHint)

    def test_env_is_read_only(self):
        tools = {t.name: t for t in asyncio.run(server.mcp.list_tools())}
        self.assertTrue(tools["env"].annotations.readOnlyHint)


if __name__ == "__main__":
    unittest.main()
