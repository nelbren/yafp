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
            ". ./yafp-ps.ps1; $global:YAFP_CODEX_CHECK_INTERVAL=0; "
            "$global:YAFP_RESOURCE_CHECK_INTERVAL=0; function prompt { 'READY>' }"
        )
        args = subprocess.list2cmdline(["-NoLogo", "-NoProfile", "-NoExit", "-Command", command])
        for key in ("q", "\x1b"):
            with self.subTest(key=repr(key)):
                terminal = PTY(80, 24)
                try:
                    terminal.spawn(shutil.which("pwsh"), cmdline=" " + args,
                                   cwd=str(Path(__file__).resolve().parents[1]))
                    self.wait_for(terminal, "READY>")
                    terminal.write("yafp-screen\r")
                    self.wait_for(terminal, "█")
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
