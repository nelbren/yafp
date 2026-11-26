import os
import select
import shlex
import struct
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

try:
    import fcntl
    import pty
    import shutil
    import termios
except ImportError:
    fcntl = pty = shutil = termios = None


ROOT = Path(__file__).resolve().parents[1]
RENDERER = ROOT / "scripts/unix/screen/render.py"


class ScreenPtyTests(unittest.TestCase):
    @unittest.skipIf(pty is None, "Unix shells are unavailable on this platform")
    def test_screen_shortcuts_delegate_to_their_views(self):
        context = shlex.quote(str(ROOT / "scripts/unix/screen/context.bash"))
        for shell, options in (("bash", ["--noprofile", "--norc"]), ("zsh", ["-df"])):
            if not shutil.which(shell):
                continue
            with self.subTest(shell=shell):
                output = subprocess.check_output(
                    [shell, *options, "-c", f"""
                        . {context}
                        yafp-screen() {{ printf '%s\\n' "$@"; }}
                        yafp-screen-codex
                        yafp-screen-resources
                    """],
                    text=True, timeout=5,
                )
                self.assertEqual(output.splitlines(), ["codex", "resources"])

    @unittest.skipIf(pty is None, "pseudo-terminals are unavailable on this platform")
    def test_screen_switches_quota_format_when_the_cached_sample_changes(self):
        shells = [shell for shell in ("bash", "zsh") if shutil.which(shell)]
        for shell in shells:
            with self.subTest(shell=shell), tempfile.TemporaryDirectory() as directory:
                sample = Path(directory) / "sample"
                sample.write_text("0 ok 25 25 - 0\n")
                master, slave = pty.openpty()
                # Force the compact text view so the actual token is visible.
                fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 4, 24, 0, 0))
                script = f"""
                    YAFP_ROOT={shlex.quote(str(ROOT))}
                    . "$YAFP_ROOT/scripts/unix/codex/context.bash"
                    . "$YAFP_ROOT/scripts/unix/screen/context.bash"
                    YAFP_CODEX_CHECK_INTERVAL=300 YAFP_CODEX_ATTEMPT=$SECONDS
                    YAFP_CODEX_DIR={shlex.quote(directory)}
                    YAFP_CODEX_VALUE_STYLE=symbols YAFP_CODEX_PERCENT_AT_OR_BELOW=24
                    yafp-screen-codex
                """
                shell_options = ["--noprofile", "--norc"] if shell == "bash" else ["-df"]
                environment = {**os.environ, "TERM": "xterm-256color", "COLUMNS": "24", "LINES": "4"}

                try:
                    with subprocess.Popen(
                        [shell, *shell_options, "-c", script],
                        stdin=slave, stdout=slave, stderr=slave, env=environment,
                    ) as process:
                        output = bytearray()
                        try:
                            for expected, next_sample in (
                                ("Codex ⣄0s", "0 ok 24 24 - 0\n"),
                                ("Codex 24%0s", "0 ok 25 25 - 0\n"),
                                ("Codex ⣄0s", None),
                            ):
                                output.clear()
                                deadline = time.monotonic() + 5
                                while expected.encode() not in output and time.monotonic() < deadline:
                                    ready, _, _ = select.select([master], [], [], 0.2)
                                    if ready:
                                        output.extend(os.read(master, 8192))
                                self.assertIn(expected.encode(), output)
                                if next_sample:
                                    replacement = sample.with_suffix(".new")
                                    replacement.write_text(next_sample)
                                    replacement.replace(sample)
                        finally:
                            if process.poll() is None:
                                process.kill()
                finally:
                    os.close(slave)
                    os.close(master)

    @unittest.skipIf(pty is None, "pseudo-terminals are unavailable on this platform")
    def test_resize_exit_keys_and_terminal_restoration(self):
        for key, expected_code in ((b"q", 0), (b"\x1b", 0), (b"\x03", 0)):
            with self.subTest(key=key):
                self._run_screen(key, expected_code)

    @unittest.skipIf(pty is None or shutil.which("bash") is None, "Bash PTY is unavailable")
    def test_bash_command_loads_and_renders_disabled_samples(self):
        master, slave = pty.openpty()
        pid = os.fork()
        if pid == 0:
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
            os.dup2(slave, 0)
            os.dup2(slave, 1)
            os.dup2(slave, 2)
            script = f"source {ROOT / 'yafp-ps1.bash'}; yafp-screen"
            environment = {
                **os.environ, "YAFP_NO_INSTALL_HOOKS": "1", "TERM": "xterm-256color",
                "YAFP_RESOURCE_CHECK_INTERVAL": "0", "YAFP_CODEX_CHECK_INTERVAL": "0",
            }
            os.execvpe("bash", ["bash", "--noprofile", "--norc", "-ic", script], environment)
        output = bytearray()
        try:
            fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
            deadline = time.monotonic() + 8
            while b"?1049h" not in output and time.monotonic() < deadline:
                ready, _, _ = select.select([master], [], [], 0.2)
                if ready:
                    output.extend(os.read(master, 8192))
            self.assertIn(b"?1049h", output)
            self.assertNotIn("".encode(), output)
            os.write(master, b"q")
            deadline = time.monotonic() + 8
            while b"?1049l" not in output and time.monotonic() < deadline:
                ready, _, _ = select.select([master], [], [], 0.2)
                if ready:
                    output.extend(os.read(master, 8192))
            self.assertIn(b"?1049l", output)
            _, status = os.waitpid(pid, 0)
            self.assertEqual(os.waitstatus_to_exitcode(status), 0)
        finally:
            os.close(slave)
            os.close(master)

    @unittest.skipIf(pty is None or shutil.which("zsh") is None, "zsh PTY is unavailable")
    def test_zsh_command_loads_and_renders_disabled_samples(self):
        master, slave = pty.openpty()
        pid = os.fork()
        if pid == 0:
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
            os.dup2(slave, 0)
            os.dup2(slave, 1)
            os.dup2(slave, 2)
            script = f"source {ROOT / 'yafp-ps1.zsh'}; yafp-screen"
            environment = {
                **os.environ, "YAFP_NO_INSTALL_HOOKS": "1", "TERM": "xterm-256color",
                "YAFP_RESOURCE_CHECK_INTERVAL": "0", "YAFP_CODEX_CHECK_INTERVAL": "0",
            }
            os.execvpe("zsh", ["zsh", "-df", "-ic", script], environment)
        output = bytearray()
        try:
            fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
            deadline = time.monotonic() + 8
            while b"?1049h" not in output and time.monotonic() < deadline:
                ready, _, _ = select.select([master], [], [], 0.2)
                if ready:
                    output.extend(os.read(master, 8192))
            self.assertIn(b"?1049h", output)
            self.assertNotIn("".encode(), output)
            os.write(master, b"q")
            deadline = time.monotonic() + 8
            while b"?1049l" not in output and time.monotonic() < deadline:
                ready, _, _ = select.select([master], [], [], 0.2)
                if ready:
                    output.extend(os.read(master, 8192))
            self.assertIn(b"?1049l", output)
            _, status = os.waitpid(pid, 0)
            self.assertEqual(os.waitstatus_to_exitcode(status), 0)
        finally:
            os.close(slave)
            os.close(master)

    def _run_screen(self, exit_key, expected_code):
        master, slave = pty.openpty()
        original = termios.tcgetattr(slave)
        pid = os.fork()
        if pid == 0:
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
            os.dup2(slave, 0)
            os.dup2(slave, 1)
            os.dup2(slave, 2)
            executable = shutil.which(os.environ.get("PYTHON", "python3"))
            os.execv(executable, [
                executable, str(RENDERER), "--view", "all",
                "--codex", "֍⣄3d4h", "--resources", "⣀", "▦⣶", "⡀", "⣷",
            ])
        output = bytearray()
        try:
            fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
            deadline = time.monotonic() + 5
            while (b"?1049h" not in output or b"\x1b[H" not in output) and time.monotonic() < deadline:
                ready, _, _ = select.select([master], [], [], 0.2)
                if ready:
                    output.extend(os.read(master, 8192))
            self.assertIn(b"?1049h", output)
            initial_frame = bytes(output).split(b"\x1b[H", 1)[1]
            fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 10, 20, 0, 0))
            deadline = time.monotonic() + 3
            while bytes(output).count(b"\x1b[H") < 2 and time.monotonic() < deadline:
                ready, _, _ = select.select([master], [], [], 0.2)
                if ready:
                    output.extend(os.read(master, 8192))
            resized_frame = bytes(output).split(b"\x1b[H", 2)[2]
            self.assertNotEqual(initial_frame, resized_frame)
            os.write(master, exit_key)
            deadline = time.monotonic() + 5
            while b"?1049l" not in output and time.monotonic() < deadline:
                ready, _, _ = select.select([master], [], [], 0.2)
                if not ready:
                    continue
                try:
                    output.extend(os.read(master, 8192))
                except OSError:
                    break
            self.assertIn(b"?1049l", output)
            self.assertIn(b"\x1b[0m", output)
            restored = termios.tcgetattr(slave)
            mode_bits = termios.ECHO | termios.ICANON
            self.assertEqual(original[3] & mode_bits, restored[3] & mode_bits)
            _, status = os.waitpid(pid, 0)
            self.assertEqual(os.waitstatus_to_exitcode(status), expected_code)
        finally:
            os.close(slave)
            os.close(master)


if __name__ == "__main__":
    unittest.main()
