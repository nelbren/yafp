#!/usr/bin/env python3
"""Read Codex quota without starting a conversation or exposing account data."""

import json
import math
import os
from pathlib import Path
import queue
import shutil
import signal
import subprocess
import sys
import threading
import time


def remaining_windows(result):
    """Prefer the Codex bucket; never substitute an unrelated model bucket."""
    buckets = result.get("rateLimitsByLimitId")
    limits = buckets.get("codex") if isinstance(buckets, dict) and "codex" in buckets else result.get("rateLimits")
    if not isinstance(limits, dict) or limits.get("limitId") not in (None, "codex"):
        return [None, None], None
    values, resets = [], []
    for name in ("primary", "secondary"):
        window = limits.get(name)
        used = window.get("usedPercent") if isinstance(window, dict) else None
        valid = (isinstance(used, (int, float)) and not isinstance(used, bool)
                 and math.isfinite(used) and 0 <= used <= 100)
        values.append(math.floor(100 - used) if valid else None)
        reset = window.get("resetsAt") if isinstance(window, dict) else None
        resets.append(reset if valid and isinstance(reset, int) and not isinstance(reset, bool)
                      and 0 < reset <= 9999999999 else None)
    available = [index for index, value in enumerate(values) if value is not None]
    # Ties select primary, including its reset time.
    selected = min(available, key=lambda index: values[index]) if available else None
    return values, resets[selected] if selected is not None else None


class ProbeFailure(OSError):
    """A fixed diagnostic code, never a server-provided message."""


def probe(timeout=10, report=None):
    started = time.monotonic()
    stage, reason = "locate-cli", "in-progress"
    process = None

    def progress(next_stage):
        nonlocal stage
        stage = next_stage
        if report is not None:
            report(stage, reason, int((time.monotonic() - started) * 1000),
                   process.pid if process is not None else 0)

    try:
        progress(stage)
        command = shutil.which("codex")
        if not command:
            reason = "missing-cli"
            return "missing-cli", [None, None], None
        progress("start-server")
        process = subprocess.Popen(
            [command, "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, text=True, encoding="utf-8", errors="replace",
            start_new_session=(os.name == "posix"),
        )
        messages = queue.Queue()

        def read_messages():
            try:
                for line in process.stdout:
                    messages.put(line)
            finally:
                messages.put(None)

        reader = threading.Thread(target=read_messages, daemon=True)
        reader.start()
        deadline = time.monotonic() + timeout

        def request(identifier, method, params=None):
            progress(method)
            payload = {"id": identifier, "method": method}
            if params is not None:
                payload["params"] = params
            process.stdin.write(json.dumps(payload) + "\n")
            process.stdin.flush()
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError
                try:
                    line = messages.get(timeout=remaining)
                except queue.Empty as error:
                    raise TimeoutError from error
                if line is None:
                    raise ProbeFailure("server-closed")
                try:
                    message = json.loads(line)
                except ValueError:
                    continue
                if isinstance(message, dict) and message.get("id") == identifier:
                    if "error" in message:
                        raise ProbeFailure("rpc-error")
                    if not isinstance(message.get("result"), dict):
                        raise ProbeFailure("invalid-response")
                    return message["result"]

        request(1, "initialize", {"clientInfo": {"name": "yafp", "version": "1"}})
        process.stdin.write('{"method":"initialized"}\n')
        process.stdin.flush()
        account = request(2, "account/read", {"refreshToken": False}).get("account")
        if not isinstance(account, dict):
            reason = "logged-out"
            return "logged-out", [None, None], None
        if account.get("type") != "chatgpt":
            reason = "unsupported-auth"
            return "unsupported-auth", [None, None], None
        result = request(3, "account/rateLimits/read")
        progress("parse-limits")
        values, reset = remaining_windows(result)
        reason = "ok" if any(value is not None for value in values) else "no-valid-limits"
        return ("ok" if reason == "ok" else "unavailable"), values, reset
    except TimeoutError:
        reason = "timeout"
        return "timeout", [None, None], None
    except ProbeFailure as error:
        reason = str(error)
        return "unavailable", [None, None], None
    except (OSError, ValueError):
        reason = "server-start-failed" if stage == "start-server" else "io-error"
        return "unavailable", [None, None], None
    except SystemExit:
        reason = "cancelled"
        raise
    finally:
        if process is not None:
            # Kill only this private stdio tree, including helpers holding pipes.
            try:
                if os.name == "posix":
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=0.3)
                    except subprocess.TimeoutExpired:
                        pass
                    finally:
                        # The parent can exit before a helper closes stdout.
                        try:
                            os.killpg(process.pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                elif process.poll() is None:
                    # Native Python in Git Bash needs the Windows tree terminator.
                    subprocess.run(
                        ["taskkill.exe", "/PID", str(process.pid), "/T", "/F"],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1,
                        check=False,
                    )
            except (OSError, subprocess.TimeoutExpired):
                pass
            if process.poll() is None:
                process.kill()
            try:
                process.wait(timeout=0.3)
            except subprocess.TimeoutExpired:
                pass
            for stream in (process.stdin, process.stdout):
                if stream is not None:
                    try:
                        stream.close()
                    except OSError:
                        pass
        # The final duration includes process-tree cleanup. The PID is historical.
        if report is not None:
            report(stage, reason, int((time.monotonic() - started) * 1000),
                   process.pid if process is not None else 0)


def main():
    target = Path(sys.argv[1])
    checked = int(sys.argv[2])
    # Raising from SIGTERM unwinds probe's finally block on shell exit.
    def interrupted(_signum, _frame):
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, interrupted)
    started_at = int(time.time())

    def report(stage, reason, duration, server_pid):
        diagnostic = target.with_name(target.name + ".debug")
        temporary = diagnostic.with_name(diagnostic.name + ".tmp")
        try:
            temporary.write_text(f"{checked} {stage} {reason} {duration} {server_pid}\n",
                                 encoding="utf-8")
            temporary.replace(diagnostic)
        except OSError:
            pass

    status, windows, reset = probe(report=report)
    available = [value for value in windows if value is not None]
    # Convert epoch time once in the worker so renderers need no date process.
    deadline = max(0, checked + reset - started_at) if reset is not None else None
    values = [min(available) if available else None, *windows, deadline]
    fields = " ".join("-" if value is None else str(value) for value in values)
    temporary = target.with_name(target.name + ".tmp")
    try:
        temporary.write_text(f"{checked} {status} {fields}\n", encoding="utf-8")
        temporary.replace(target)
    except OSError:
        pass


if __name__ == "__main__":
    main()
