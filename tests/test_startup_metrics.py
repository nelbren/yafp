"""Startup contracts: a counter outside the rendering path."""
from pathlib import Path
import json
import os
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest
import venv

ROOT = Path(__file__).resolve().parents[1]


class StartupMetricsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='yafp startup ')
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name).resolve()
        self.tools = self.base / 'tools with spaces'
        venv.EnvBuilder(with_pip=False).create(self.tools / '.venv')
        recorder = self.tools / 'bin/application-startup'
        recorder.parent.mkdir()
        recorder.write_text("from pathlib import Path\nimport os,sys,json\n"
                            "with Path(os.environ['YAFP_TEST_STARTUP_LOG']).open('a') as stream:\n"
                            " stream.write(json.dumps(sys.argv[1:])+'\\n')\n")
        self.log = self.base / 'events.jsonl'
        self.environment = {**os.environ, 'AI_DEV_TOOLS_ROOT': str(self.tools),
                            'YAFP_TEST_STARTUP_LOG': str(self.log), 'YAFP_METRICS_DISABLED': '0',
                            'YAFP_NO_INSTALL_HOOKS': '0', 'TERM': 'xterm-256color'}
        self.environment.pop('YAFP_STARTUP_METRICS_PID', None)

    def checkout(self):
        checkout = self.base / 'prompt with spaces'
        checkout.mkdir()
        for name in ('yafp-ps1.bash', 'yafp-ps1.zsh', 'yafp-ps.ps1'):
            shutil.copy2(ROOT / name, checkout / name)
        shutil.copytree(ROOT / 'themes', checkout / 'themes')
        for shell in ('unix', 'windows'):
            shutil.copytree(ROOT / f'scripts/{shell}/metrics', checkout / f'scripts/{shell}/metrics')
        for shell in ('bash', 'zsh'):
            config = (ROOT / f'yafp-cfg.{shell}.example').read_text()
            config += '\nYAFP_REPOS=0\nYAFP_STATS_ON_EXIT=0\nYAFP_OSC133=0\n'
            (checkout / f'yafp-cfg.{shell}').write_text(config)
        (checkout / 'yafp-cfg.ps1').write_text(
            '$global:YAFP_REPOS=0\n$global:YAFP_STATS_ON_EXIT=0\n$global:YAFP_OSC133=0\n')
        return checkout

    def test_unix_entrypoints_activate_once_and_keep_functions_uninstrumented(self):
        checkout = self.checkout()
        for shell in ('bash', 'zsh'):
            if not shutil.which(shell):
                continue
            with self.subTest(shell=shell):
                self.log.unlink(missing_ok=True)
                engine = checkout / f'yafp-ps1.{shell}'
                script = (f'. {shlex.quote(str(engine))}; trap - DEBUG; PROMPT_COMMAND=; '
                          f'. {shlex.quote(str(engine))}; trap - DEBUG; PROMPT_COMMAND=; '
                          'for x in 1 2 3 4 5; do yafp_theme_background_color red >/dev/null; done; '
                          'printf ready')
                args = [shell, '--noprofile', '--norc'] if shell == 'bash' else [shell, '-df']
                completed = subprocess.run(args + ['-ic', script], env=self.environment,
                                           capture_output=True, text=True, timeout=20)
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertEqual(self.events(1), [['--path', str(checkout), '--shell', shell]])

    @unittest.skipUnless(shutil.which('pwsh'), 'Requiere PowerShell 7')
    def test_powershell_entrypoint_activates_once_with_noexit(self):
        checkout = self.checkout()
        engine = str(checkout / 'yafp-ps.ps1').replace("'", "''")
        script = f". '{engine}'; $null=prompt; . '{engine}'; $null=prompt; exit 0"
        completed = subprocess.run(['pwsh', '-NoProfile', '-NoExit', '-Command', script],
                                   env=self.environment, capture_output=True, text=True, timeout=20)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(self.events(1), [['--path', str(checkout), '--shell', 'powershell']])

    def events(self, expected):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            rows = self.log.read_text().splitlines() if self.log.exists() else []
            if len(rows) >= expected:
                return [json.loads(row) for row in rows]
            time.sleep(.03)
        self.fail(f'Esperados {expected} eventos, observados {len(rows)}')

    def unix(self, shell, body, interactive=True, disabled=False):
        helper = ROOT / 'scripts/unix/metrics/startup.bash'
        script = f'. {shlex.quote(str(helper))}; {body}'
        args = [shell, '--noprofile', '--norc'] if shell == 'bash' else [shell, '-df']
        args += ['-ic' if interactive else '-c', script]
        environment = {**self.environment, 'YAFP_METRICS_DISABLED': '1' if disabled else '0'}
        completed = subprocess.run(args, env=environment, capture_output=True, text=True, timeout=15)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        return completed

    def test_unix_counts_once_across_reload_and_function_calls(self):
        for shell in ('bash', 'zsh'):
            if not shutil.which(shell):
                continue
            with self.subTest(shell=shell):
                self.log.unlink(missing_ok=True)
                body = (f'yafp_record_startup "{self.base}" {shell}; '
                        f'yafp_record_startup "{self.base}" {shell}; '
                        'yafp_theme_background_color() { :; }; '
                        'for x in 1 2 3 4 5; do yafp_theme_background_color; done; printf ready')
                self.assertEqual(self.unix(shell, body).stdout, 'ready')
                self.assertEqual(len(self.events(1)), 1)
                self.unix(shell, body)
                self.assertEqual(len(self.events(2)), 2)

    def test_unix_noninteractive_and_disabled_do_not_record(self):
        for shell in ('bash', 'zsh'):
            if shutil.which(shell):
                body = f'yafp_record_startup "{self.base}" {shell}'
                self.unix(shell, body, interactive=False)
                self.unix(shell, body, disabled=True)
        time.sleep(.1)
        self.assertFalse(self.log.exists())

    @unittest.skipUnless(shutil.which('pwsh'), 'Requiere PowerShell 7')
    def test_powershell_counts_once_across_reload(self):
        helper = ROOT / 'scripts/windows/metrics/startup.ps1'
        def quote(value):
            return "'" + str(value).replace("'", "''") + "'"
        script = (f'. {quote(helper)}; Register-YafpStartup -Root {quote(self.base)} -Interactive $false; '
                  f'Register-YafpStartup -Root {quote(self.base)} -Interactive $true; '
                  f'. {quote(helper)}; Register-YafpStartup -Root {quote(self.base)} -Interactive $true; '
                  "'ready'")
        completed = subprocess.run(['pwsh', '-NoProfile', '-Command', script],
                                   env=self.environment, capture_output=True, text=True, timeout=15)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(completed.stdout.strip(), 'ready')
        self.assertEqual(self.events(1), [['--path', str(self.base), '--shell', 'powershell']])


if __name__ == '__main__':
    unittest.main()
