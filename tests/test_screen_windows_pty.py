import os
import shutil
import subprocess
import time
import unittest
from pathlib import Path

try:
    from winpty import PTY
except ImportError:
    PTY = None


@unittest.skipUnless(os.name == "nt" and PTY and shutil.which("pwsh"),
                     "requires Windows, PowerShell 7 and pywinpty")
class PowerShellScreenTests(unittest.TestCase):
    def test_quit_keys_return_to_the_shell_without_enter(self):
        command = (
            "$env:TERM='xterm-256color'; $env:YAFP_METRICS_DISABLED='1'; "
            "Remove-Item Env:NO_COLOR -ErrorAction Ignore; "
            ". ./yafp-ps.ps1; $global:YAFP_CODEX_CHECK_INTERVAL=0; "
            "$global:YAFP_RESOURCE_CHECK_INTERVAL=0; function prompt { 'READY>' }"
        )
        args = subprocess.list2cmdline(["-NoLogo", "-NoProfile", "-NoExit", "-Command", command])
        for mode, key in (("off", "q"), ("point", "\x1b"), ("diagonal", "q"),
                          ("horizontal-up", "q"), ("random", "q")):
            with self.subTest(mode=mode, key=repr(key)):
                terminal = PTY(80, 24)
                try:
                    terminal.spawn(shutil.which("pwsh"), cmdline=" " + args,
                                   cwd=str(Path(__file__).resolve().parents[1]))
                    self.wait_for(terminal, "READY>")
                    background = "matrix" if mode == "random" else "off"
                    terminal.write(f"$global:YAFP_SCREEN_BACKGROUND='{background}'; "
                                   "$global:YAFP_SCREEN_MATRIX_COLOR='cyan'; "
                                   "$global:YAFP_SCREEN_MATRIX_DENSITY='medium'; "
                                   f"$global:YAFP_SCREEN_SHINE='{mode}'; yafp-screen\r")
                    marker = "\x1b[96m" if mode == "random" else "\x1b[97m"
                    self.wait_for(terminal, "█" if mode == "off" else marker)
                    # Unrelated keystrokes queued before the exit key must drain in one tick.
                    terminal.write("xyz" + key)
                    self.wait_for(terminal, "READY>", timeout=2)
                finally:
                    del terminal

    def wait_for(self, terminal, marker, timeout=10):
        output = ""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            output += terminal.read(8192, blocking=False)
            if marker in output:
                return
            time.sleep(0.02)
        self.fail(f"Timed out waiting for {marker!r}")


if __name__ == "__main__":
    unittest.main()
