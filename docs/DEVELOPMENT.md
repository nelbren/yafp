# Development and validation

[Documentation index](../README.md#guides)

Run the examples from the root of your YAFP checkout.

## Tests

Install the complete local quality environment for Linux or macOS:

```bash
bash scripts/unix/setup/quality.bash
```

On Windows, install ShellCheck, PSScriptAnalyzer, and markdownlint with:

```powershell
pwsh -NoProfile -File scripts/windows/setup/quality.ps1
```

To install only PSScriptAnalyzer on Linux or macOS, with PowerShell 7.2.11 or
later (`pwsh`) already on `PATH`, run:

```bash
bash scripts/unix/setup/psscriptanalyzer.bash
```

On Windows, use the standalone PowerShell installer:

```powershell
pwsh -NoProfile -File scripts/windows/setup/psscriptanalyzer.ps1
```

Both entry points install PSScriptAnalyzer `1.25.0` from PSGallery for the
current user, reuse that version if it is already installed, and verify that
the module imports and exposes `Invoke-ScriptAnalyzer`. They do not require
administrator privileges or change the repository trust policy. Preview the
installation without downloading or importing modules with `--dry-run` on
Unix or `-DryRun` on Windows. PowerShell itself is a prerequisite and is not
installed by these scripts.

The Windows quality installer calls this same module installer. The Unix
quality installer continues to install ShellCheck and markdownlint; use the
standalone command above when PowerShell analysis is also needed. Installing
the analyzer on Unix does not enable tests that require Windows APIs.

The Windows setup prefers Scoop, then WinGet, then Chocolatey. ShellCheck is
included so the Bash validation can also run from Git Bash. Preview the
installation commands without changing the system with `--dry-run` on Unix or
`-DryRun` on Windows. Use `-PackageManager scoop`, `winget`, or `choco` to
override automatic selection.

Use `-SkipShellCheck` to prepare only PowerShell validation. The Windows CI
job uses this option and installs PSScriptAnalyzer and markdownlint. The Linux
job runs ShellCheck.

<!-- markdownlint-disable MD013 -->

| Platform | Package managers                            | Installed tools                            |
| -------- | ------------------------------------------- | ------------------------------------------ |
| Linux    | APT, DNF, Pacman, or Zypper                 | ShellCheck and markdownlint                |
| macOS    | Homebrew                                    | ShellCheck and markdownlint                |
| Windows  | Scoop, WinGet, or Chocolatey; PowerShellGet | ShellCheck, PSScriptAnalyzer, markdownlint |

<!-- markdownlint-enable MD013 -->

Git Bash delegates environment installation to the Windows setup script. The
quality runners verify each setup plan before running their platform tests.

Diagnose missing commands, personal configuration, invalid option values,
theme pairs, and shell profile integration without changing the system:

```bash
bash scripts/unix/doctor/check.bash
```

```powershell
pwsh -NoProfile -File scripts/windows/doctor/check.ps1
```

Use `--strict` on Unix or `-Strict` on Windows when warnings such as missing
optional linters should also produce a failing exit code. For an alternate
configuration file, use `--config PATH` or `-ConfigPath PATH`.

The Unix doctor's summary displays passed checks in intense green, warnings
in intense yellow, and errors in intense red, including zero counts. It uses
plain text when output is redirected or `NO_COLOR` is set to a non-empty value.

Run all Bash tests, syntax checks, and installed linters with:

```bash
bash scripts/unix/quality/check.bash
```

Run all PowerShell tests, parser checks, and installed linters with:

```powershell
pwsh -NoProfile -File scripts/windows/quality/check.ps1
```

The quality scripts use `shellcheck`, PSScriptAnalyzer, and `markdownlint` when
they are available. Set `YAFP_REQUIRE_LINTERS=1` to make a missing analyzer an
error, as continuous integration does. Successful lines use a green `✅`,
warnings use a yellow `⚠️`, and failures use a red `❌`; all retain their
textual meaning when color is unavailable.

Resource collector tests use one `vm_stat` stub with success and failure modes.
This avoids redefining the function, which can trigger an unreachable-code
diagnostic in ShellCheck even though the collector invokes both test cases.
The unreachable-code checks remain enabled.

On Windows, run the Bash checks from a complete Git Bash session. When invoking
Bash through a PowerShell shim, use login mode so Unix tools are on `PATH`:

```bash
bash -lc 'cd /c/path/to/yafp && bash scripts/unix/quality/check.bash'
```

GitHub Actions runs the same checks on Linux, macOS, and Windows. See
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) for component boundaries,
runtime invariants, and the safe modularization strategy.

## zsh checks

Run the zsh syntax, logic, local Git, and interactive terminal tests with:

```bash
bash scripts/unix/quality/zsh.bash
```

The test runner requires zsh and Python 3; Python is not a prompt dependency.
The normal Unix quality command also runs these checks when zsh is installed.
Set `YAFP_REQUIRE_ZSH=1` to require the runtime, as Linux and macOS CI do.
The existing Unix doctor continues to diagnose Bash configuration and profiles.

## Development timing

Set `YAFP_DEVEL` to `1` to display the prompt construction time. A value of `0`
or an unset variable disables it. It works with every Bash and PowerShell theme.

For Bash, set the value in `yafp-cfg.bash`:

```bash
YAFP_DEVEL=1
```

For PowerShell, set the value in `yafp-cfg.ps1`:

```powershell
$global:YAFP_DEVEL = 1
```

The diagnostic line uses the same fields on both shells:

| Field     | Meaning                                      |
| --------- | -------------------------------------------- |
| `Total`   | Total prompt construction time               |
| `General` | General context time                         |
| `Git`     | Git context time                             |
| `Venv`    | Python virtual environment context time      |
| `Error`   | Previous command status calculation time     |
| `Timer`   | Remaining timer and orchestration overhead   |

The output maps those fields to `Total ms | General Git Venv Error
Timer`.

Totals below 50 ms use `` in green, totals from 50 through 199 ms use
`` with black text on an intense yellow background, and totals of 200 ms or
more use
`` with intense white text on a red background.

## Origin device commit trailer

Install the versioned `prepare-commit-msg` hook for the current repository:

```bash
bash scripts/unix/git/setup.bash
```

Preview the target without changing the repository with `--dry-run`. Use
`--repo PATH` to install it in another checkout. The hook obtains the macOS
Computer Name first, then falls back to `COMPUTERNAME` on Windows or the short
hostname on other Unix systems. It adds an `Origin-Device` trailer only when
one is not already present. The installer is idempotent and refuses to
overwrite a different existing `prepare-commit-msg` hook.

## YAFP startup tracking

YAFP records one activation per interactive shell process after the prompt
loads successfully. Reloading in the same session does not record another
activation. Each new terminal or SSH session has its own activation. Internal
function calls and prompt redraws are not recorded.

A silent background writer runs once using the existing ai-dev-tools Python
runtime. In zsh, it is disowned at creation to avoid job/PID announcements.
It uses `AI_DEV_TOOLS_ROOT` or `~/ai-dev-tools` and stores an `application`
event with source `yafp/startup/bash`, `yafp/startup/zsh`, or
`yafp/startup/powershell`. It starts no services and makes no network requests.
The shared SQLite database stays outside the checkout at
`PROJECT_TEST_HOME/repository-metrics/IDENTITY/executions.sqlite3`, or in the
default local ai-dev-tools store.

The counter appears in the application executions section of Software Facts
for the YAFP checkout. It does not measure commands, redraws, duration, or
sessions from before this integration. The `yafp-stats` command counters retain
their separate per-session scope.

If a prepared ai-dev-tools runtime is unavailable, the prompt keeps working and
Software Facts retains the missing measurement. Writer errors are recorded in
`PROJECT_TEST_HOME/application-startup-errors.log`. To disable the counter, set
`YAFP_METRICS_DISABLED=1` before loading YAFP; in PowerShell, use
`$env:YAFP_METRICS_DISABLED = '1'`. Quality runners disable real tracking; their
contract tests use temporary environments and writers.

Prompt functions must not be instrumented as another project's aliases merely
because they share a prefix. After updating ai-dev-tools and YAFP, a session
with earlier instrumentation can clear it and reload the prompt with:

```bash
AIDT_alias-reload; yafp-reload
```

New shells apply the integration when YAFP loads. Git-ignored personal
configurations do not need changes.

## Classified test records

`.project-test.yml` declares the existing suites by platform. On Unix,
`scripts/unix/quality/project-test.sh` runs the Bash tests and zsh checks
without mixing static analysis with test counts. PowerShell suites retain
their Windows selection.

```sh
project-test run --path . --profile quick
software-facts --path .
```

The shell runner preserves logs and aggregate status. Internal case counts
remain uncollected when no native report is provided; this does not mean zero.
Full quality validation still uses the entry points in the existing testing
section and does not install analyzers during a run.
