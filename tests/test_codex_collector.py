"""Offline quota protocol, authentication, timeouts, and bucket selection."""
import importlib.util
import json
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("codex_collect", ROOT / "scripts/unix/codex/collect.py")
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


@unittest.skipUnless(os.name == "posix", "Unix collector uses POSIX processes")
class CodexCollectorTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="yafp quota ")
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.fixture = self.directory / "fixture.json"
        self.log = self.directory / "requests.jsonl"
        command = self.directory / "codex"
        command.write_text(f"#!/bin/sh\nexec {shlex.quote(sys.executable)} "
                           f"{shlex.quote(str(ROOT / 'tests/fixtures/codex_app_server.py'))}\n")
        command.chmod(0o700)
        environment = {"PATH": str(self.directory), "YAFP_CODEX_TEST_FIXTURE": str(self.fixture),
                       "YAFP_CODEX_TEST_LOG": str(self.log)}
        self.environment = patch.dict(os.environ, environment)
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def probe(self, fixture, timeout=2):
        self.fixture.write_text(json.dumps(fixture))
        self.log.unlink(missing_ok=True)
        return collector.probe(timeout)

    def requests(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_remaining_and_codex_bucket_precedence(self):
        fixture = {"result": {"rateLimits": {"primary": {"usedPercent": 99}},
                               "rateLimitsByLimitId": {
                                   "other": {"primary": {"usedPercent": 100}},
                                   "codex": {"primary": {"usedPercent": 25},
                                             "secondary": {"usedPercent": 40.1, "resetsAt": 2000000000}}}}}
        self.assertEqual(self.probe(fixture), ("ok", [75, 59], 2000000000))
        requests = self.requests()
        self.assertEqual([row["method"] for row in requests],
                         ["initialize", "initialized", "account/read", "account/rateLimits/read"])
        self.assertEqual(requests[2]["params"], {"refreshToken": False})

    def test_legacy_partial_and_unavailable_windows(self):
        for limits, expected in [
            ({"primary": {"usedPercent": 100}}, ("ok", [0, None], None)),
            ({"secondary": {"usedPercent": 0}}, ("ok", [None, 100], None)),
            ({"primary": {"usedPercent": None}}, ("unavailable", [None, None], None)),
            ({"primary": {"usedPercent": True}}, ("unavailable", [None, None], None)),
            ({"primary": {"usedPercent": "15"}}, ("unavailable", [None, None], None)),
            ({"primary": {"usedPercent": -1}}, ("unavailable", [None, None], None)),
            ({"primary": {"usedPercent": 101}}, ("unavailable", [None, None], None)),
            ({"limitId": "other", "primary": {"usedPercent": 0}}, ("unavailable", [None, None], None)),
        ]:
            with self.subTest(limits=limits):
                self.assertEqual(self.probe({"result": {"rateLimits": limits}}), expected)
        self.assertEqual(self.probe({"result": {"rateLimitsByLimitId": {"other": {}}}}),
                         ("unavailable", [None, None], None))

    def test_auth_checked_before_limits_and_errors_sanitized(self):
        for account, state in [(None, "logged-out"), ({"type": "apiKey"}, "unsupported-auth")]:
            self.assertEqual(self.probe({"account": account}), (state, [None, None], None))
            self.assertNotIn("account/rateLimits/read", [row["method"] for row in self.requests()])
        self.assertEqual(self.probe({"error": "account/rateLimits/read"}),
                         ("unavailable", [None, None], None))
        with patch.object(collector.shutil, "which", return_value=None):
            self.assertEqual(collector.probe(), ("missing-cli", [None, None], None))

    def test_timeout_and_atomic_private_cache(self):
        begin = time.monotonic()
        self.assertEqual(self.probe({"delay": 4}, timeout=.2), ("timeout", [None, None], None))
        self.assertLess(time.monotonic() - begin, 1.5)
        self.fixture.write_text(json.dumps({"result": {"rateLimits": {
            "primary": {"usedPercent": 25}, "secondary": {"usedPercent": 40}}}}))
        sample = self.directory / "sample"
        result = subprocess.run([sys.executable, str(ROOT / "scripts/unix/codex/collect.py"),
                                 str(sample), "17"], capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(sample.read_text(), "17 ok 60 75 60 -\n")
        self.assertFalse(sample.with_suffix(".tmp").exists())

    def test_selected_window_reset_and_invalid_timestamps(self):
        for primary, secondary, reset in [
            ({"usedPercent": 50, "resetsAt": 2000000000}, {"usedPercent": 25, "resetsAt": 2100000000}, 2000000000),
            ({"usedPercent": 50, "resetsAt": 2000000000}, {"usedPercent": 50, "resetsAt": 2100000000}, 2000000000),
            ({"usedPercent": 50}, {"usedPercent": 50, "resetsAt": 2100000000}, None),
            (None, {"usedPercent": 25, "resetsAt": 2100000000}, 2100000000),
        ]:
            with self.subTest(primary=primary, secondary=secondary):
                fixture = {"result": {"rateLimits": {"primary": primary, "secondary": secondary}}}
                self.assertEqual(self.probe(fixture)[2], reset)
        for reset in (None, True, "2000000000", -1, 0, 2000000000.5, 10000000000):
            fixture = {"result": {"rateLimits": {"primary": {"usedPercent": 25, "resetsAt": reset}}}}
            self.assertEqual(self.probe(fixture), ("ok", [75, None], None))

    def test_reset_epoch_is_converted_to_session_clock(self):
        sample = self.directory / "sample"
        with patch.object(collector.time, "time", return_value=1000000), \
                patch.object(collector, "probe", return_value=("ok", [75, 60], 1464400)), \
                patch.object(collector.signal, "signal"), \
                patch.object(sys, "argv", ["collect.py", str(sample), "17"]):
            collector.main()
        self.assertEqual(sample.read_text(), "17 ok 60 75 60 464417\n")

    def test_signal_terminates_inflight_worker_without_publishing(self):
        self.fixture.write_text(json.dumps({"delay": 20}))
        sample = self.directory / "sample"
        process = subprocess.Popen([sys.executable, str(ROOT / "scripts/unix/codex/collect.py"),
                                    str(sample), "0"])
        try:
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                if self.log.exists() and "account/rateLimits/read" in self.log.read_text():
                    break
                time.sleep(.01)
            else:
                self.fail("Collector did not reach the quota request")
            process.send_signal(signal.SIGTERM)
            process.wait(timeout=2)
            self.assertFalse(sample.exists())
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()

    def test_helper_holding_stdout_cannot_extend_cleanup(self):
        self.fixture.write_text(json.dumps({"helper": True, "result": {"rateLimits": {
            "primary": {"usedPercent": 25}}}}))
        sample = self.directory / "sample"
        begin = time.monotonic()
        result = subprocess.run([sys.executable, str(ROOT / "scripts/unix/codex/collect.py"),
                                 str(sample), "0"], capture_output=True, timeout=4)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertLess(time.monotonic() - begin, 1.5)
        self.assertEqual(sample.read_text(), "0 ok 75 75 - -\n")


if __name__ == "__main__":
    unittest.main()
