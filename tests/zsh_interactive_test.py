#!/usr/bin/env python3
"""Exercise native zsh hooks in a real pseudo-terminal without user profiles."""
import os
import fcntl
from pathlib import Path
import pty
import re
import select
import subprocess
import tempfile
import termios
import time

ROOT = Path(__file__).resolve().parent.parent
OSC = re.compile(rb"\x1b\]133;([^\x07]+)\x07")


def main():
    with tempfile.TemporaryDirectory(prefix="yafp-zsh-interactive-") as directory:
        workspace = Path(directory)
        config = workspace / "config.zsh"
        config.write_text(
            "YAFP_THEME=light\nYAFP_REPOS=0\nYAFP_CLOCK=0\n"
            "YAFP_TITLE=0\nYAFP_ERROR=1\nYAFP_PVENV=0\n"
            "YAFP_OSC133=1\nYAFP_STATS_ON_EXIT=0\n"
        )
        master, slave = pty.openpty()
        environment = dict(
            os.environ,
            ZDOTDIR=directory,
            HISTFILE="/dev/null",
            TERM="xterm-256color",
            YAFP_CONFIG_FILE=str(config),
        )
        environment.pop("YAFP_NO_INSTALL_HOOKS", None)
        def attach_terminal():
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)

        process = subprocess.Popen(
            ["zsh", "-dfi"], stdin=slave, stdout=slave, stderr=slave,
            cwd=directory, env=environment, preexec_fn=attach_terminal,
        )
        os.close(slave)

        def read_output(prompt=True):
            result = b""
            deadline = time.monotonic() + (4 if prompt else 0.2)
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.05)[0]:
                    try:
                        result += os.read(master, 65536)
                    except OSError:
                        break
                    if prompt and b"\x1b]133;B\x07" in result:
                        # Drain the final line-editor sequences before sending input.
                        while select.select([master], [], [], 0.03)[0]:
                            result += os.read(master, 65536)
                        break
            return result

        def run(command, completion=True):
            os.write(master, (command + "\n").encode())
            output = read_output()
            if completion:
                events = OSC.findall(output)
                assert events.count(b"C") == 1, (command, events, output)
                assert sum(event.startswith(b"D;") for event in events) == 1, output
                assert events[-2:] == [b"A", b"B"], output
            assert b"not found" not in output, output
            assert b"bad option" not in output, output
            return output

        try:
            read_output(False)
            # Existing hooks must survive, and their return code must not hide failures.
            setup = workspace / "setup.zsh"
            setup.write_text(
                "autoload -Uz add-zsh-hook\n"
                "existing_hook() { print -r -- EXISTING:$?; return 0; }\n"
                "add-zsh-hook precmd existing_hook\n"
                f"source '{ROOT / 'yafp-ps1.zsh'}'\n"
                f"source '{ROOT / 'yafp-ps1.zsh'}'\n"
                "print -r -- HOOKS:${#precmd_functions}:${#preexec_functions}:${#zshexit_functions}\n"
                "print -r -- KSH_ARRAYS:$options[ksharrays]\n"
            )
            output = run(f"source '{setup}'", completion=False)
            assert b"HOOKS:2:1:1" in output, output
            assert b"KSH_ARRAYS:off" in output, output
            output = run("false")
            assert b"D;1" in OSC.findall(output), output
            assert b"EXISTING:1" in output, output
            output = run('print -r -- "OBSERVED:$?"')
            assert b"OBSERVED:1\r\n" in output, output
            output = run("false | true")
            assert b"D;0" in OSC.findall(output), output
            output = run('print -r -- "PIPE:${(j:,:)YAFP_LAST_PIPESTATUS}"')
            assert b"PIPE:1,0\r\n" in output, output
            output = run("print once >> executed.txt; true")
            assert (workspace / "executed.txt").read_text() == "once\n", output
            run("yafp-reload")
            output = run('print -r -- "COUNTERS:$YAFP_COMMANDS_TOTAL:$YAFP_COMMANDS_FAILED"')
            assert b"COUNTERS:6:1\r\n" in output, output
            # Percent escapes and substitution-shaped data must stay literal.
            hostile = workspace / 'path%F{red}$(touch INJECTED)'
            hostile.mkdir()
            output = run("cd '" + str(hostile) + "'")
            assert not (hostile / "INJECTED").exists(), output
            assert not (workspace / "INJECTED").exists(), output
            assert b"path%F{red}$(touch INJECTED)" in output, output
            # Redraws/empty input must not count or create command markers.
            os.write(master, b"\n")
            output = read_output()
            assert b"C" not in OSC.findall(output), output
            output = run('print -r -- "COUNTERS:$YAFP_COMMANDS_TOTAL"')
            assert b"COUNTERS:8\r\n" in output, output
            # Interactive interruption must complete exactly one block with 130.
            os.write(master, b"sleep 5\n")
            initial = read_output(False)
            os.write(master, b"\x03")
            output = initial + read_output()
            assert b"D;130" in OSC.findall(output), output
            assert OSC.findall(output).count(b"C") == 1, output
            print("ok - zsh interactive hooks, OSC 133, pipelines, reload, and interruption")
        finally:
            os.close(master)
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.terminate()
                process.wait(timeout=2)


if __name__ == "__main__":
    main()
