# YAFP architecture

## Purpose

This document describes YAFP's current boundaries and the invariants that must
be preserved when changing or modularizing the project.

## Components

<!-- markdownlint-disable MD013 -->

| Component                     | Responsibility                                         |
| ----------------------------- | ------------------------------------------------------ |
| `yafp-ps1.bash`               | Bash prompt core, context, hooks, and rendering        |
| `yafp-ps1.zsh`                | Native zsh context, hooks, workers, and rendering      |
| `yafp-ps.ps1`                 | PowerShell prompt core, context, jobs, and rendering   |
| `themes/*.bash`               | Bash-specific presentation for each theme              |
| `themes/*.zsh`                | zsh presentation for each theme                        |
| `themes/*.ps1`                | PowerShell-specific presentation for each theme        |
| `yafp-cfg.bash.example`       | Bash configuration template                            |
| `yafp-cfg.zsh.example`        | zsh configuration template                             |
| `yafp-cfg.ps1.example`        | PowerShell configuration template                      |
| `tests/`                      | Logic and integration tests                            |
| `scripts/*/setup/quality.*`   | Platform-specific quality tool installation            |
| `scripts/*/doctor/check.*`    | Environment and configuration diagnostics              |
| `scripts/*/quality/`          | Reproducible validation entry points                   |
| `scripts/unix/git/`           | Versioned Git hooks and safe installation              |
| `.github/workflows/ci.yml`    | Automated Linux, macOS, and Windows matrix             |

<!-- markdownlint-enable MD013 -->

## Bash loading flow

1. `yafp-ps1.bash` calculates the root from its own location.
2. It loads the personal `yafp-cfg.bash` configuration.
3. It initializes variables and selects the requested theme, falling back to
   `default`.
4. It builds the theme and registers `PROMPT_COMMAND` and the `DEBUG` trap,
   except in tests using `YAFP_NO_INSTALL_HOOKS=1`.
5. Each prompt collects general, Git, virtual-environment, and previous-command
   context before rendering `PS1`.

The OSC 133 integration uses the `DEBUG` trap to mark the beginning of a
command and `PROMPT_COMMAND` to close the block with its exit code.
Background intensity is selected during color construction through
`YAFP_DARKC`; transparent backgrounds remain unchanged.
Bright foreground and background colors use ANSI SGR codes directly because
eight-color terminfo entries can misencode palette indexes 8 through 15.

## zsh loading flow

1. `yafp-ps1.zsh` resolves its own location using native filename expansion.
2. It loads `yafp-cfg.zsh`, or the file selected through `YAFP_CONFIG_FILE`.
3. It loads `zsh/datetime`, applies defaults, and builds the selected native
   theme, falling back to `default`.
4. In interactive shells, `add-zsh-hook` registers `preexec`, `precmd`, and
   `zshexit` functions. Repeated sourcing does not duplicate registrations.
   Tests can disable registration with `YAFP_NO_INSTALL_HOOKS=1`.
5. `preexec` captures the full executed command and emits OSC 133 C.
6. `precmd` captures `$?` and `pipestatus` before running other commands,
   completes the previous block with OSC 133 D, collects context, and builds
   the prompt with A/B markers. It returns success so other hooks can run.

The zsh engine is independent of the Bash engine. It retains the existing
context and theme contract without moving Bash or PowerShell behavior into
shared modules. Each function uses a local native option scope with
`KSH_ARRAYS` for its internal arrays; those options do not leak into the user's
session. The interactive prompt explicitly enables `PROMPT_PERCENT` and
`PROMPT_SUBST` and disables `PROMPT_BANG`.

A single parameter expansion supplies the precomputed prompt. Literal data
escapes percent syntax; inserted data is not evaluated as shell code. Native
`%{…%}` spans mark terminal styles and cursor-relative banners as nonprinting.
Prefix measurement expands native prompt escapes, removes terminal styles, and
uses the same Unicode width and terminal-edge rules as Bash. Prompt timestamps
and metrics use the loaded native datetime module.

Background workers disable zsh's automatic job niceness and are disowned at
launch. They reuse the Bash-compatible Git cache and locking contract, perform
non-interactive fetches, and never redraw the line editor when they finish.
The next prompt collects their result. Command serial numbers distinguish
repeated identical input without depending on history settings. Reloads
preserve counters and remote acknowledgement; `zshexit` prints statistics
without replacing existing exit hooks.

## PowerShell loading flow

1. `yafp-ps.ps1` calculates the root from `$MyInvocation`.
2. It loads `yafp-cfg.ps1` when present and applies defaults to the remaining
   options.
3. It imports the requested theme, falling back to `default`.
4. The global `prompt` function captures `$?` and `$LASTEXITCODE` first.
5. It collects context, emits OSC 133 lifecycle markers when enabled, renders
   the theme, and restores `$LASTEXITCODE`.

The PowerShell OSC 133 integration follows the Windows Terminal prompt model:
it emits D for the prior command, A before visible prompt output, and B after
the prompt mark. It deliberately avoids replacing PSReadLine key handlers to
synthesize C, preserving existing interactive bindings and reload safety.

## Local startup counter

All three loaders invoke the startup adapter outside rendering functions. A
shell PID marker prevents duplicate events on reload. Unix disowns the writer;
PowerShell starts Python directly without creating a PowerShell job. The parent
process does not wait for the SQLite write, and the adapter makes no network
requests.

The adapter reuses the silent ai-dev-tools `application-startup` writer and
the shared `RepositoryMetricsStore` contract. The event belongs to the YAFP
checkout and the `application` type. Failures do not replace prompt status.
Tracking stays outside theme, Git, OSC 133, and command-statistics functions;
it adds no external processes during rendering.

Reloads preserve the marker; new processes receive distinct PIDs.
Noninteractive scripts and quality runners do not record real activations.
Configuration and storage details are in README.

## Git context and remote status

Local context is collected during rendering. Remote queries never run in the
foreground:

- Bash and zsh start a background worker and store the result inside the actual
  Git directory.
- PowerShell uses a background job and the same conceptual cache format.
- A lock prevents concurrent workers and is removed when it becomes stale.
- The first repository prompt after loading forces a background refresh; the
  pending initial check is not consumed by prompts outside repositories.
- The cache records both local and upstream object IDs. It is invalidated by
  its interval or as soon as either reference changes, including after a push.
- A successful `push`, `fetch`, or `pull` requests an immediate refresh.
- The loaded YAFP commit is captured once during startup. After a successful
  `git pull`, the next prompt compares that hash with the current YAFP `HEAD`
  and reloads only when they differ. This check does not run during ordinary
  prompt renders and can be disabled independently with `YAFP_AUTO_RELOAD=0`.
- `yafp-reload` reloads the active shell definitions manually. Bash preserves
  an earlier non-YAFP `PROMPT_COMMAND` across repeated loads; PowerShell
  promotes the reloaded definitions back into the interactive session.
- Per-session command counters are updated once when the next prompt classifies
  a completed command. Empty input and internal previews are excluded, reloads
  preserve the counters, and no persistent statistics file is created.
- `yafp-stats` renders succeeded, failed, and total counts. Normal interactive
  shell shutdown prints the same report when `YAFP_STATS_ON_EXIT=1`; Bash
  chains an earlier `EXIT` trap and PowerShell uses the engine exit event.
- `yafp-status` reads the same cached context for an exact, on-demand timer
  report, while `yafp-refresh` requests a background refresh without blocking.
- `yafp-ack` acknowledges the current remote-check failure for the session. It
  suppresses the error expansion and changes the compact indicator to intense
  red on a transparent background until a successful check resets it.
- The refreshing state remains visible on every render while the background
  worker or its cross-process lock is active.
- `yafp-demo` repeatedly invokes the cached status view and renders the current
  prompt theme and context every four seconds. The preview does not emit OSC
  133 lifecycle markers or alter the interactive prompt lifecycle. The Bash
  preview resolves PS1 display escapes into printable ANSI output, and the loop
  remains interruptible with the shell's standard `Ctrl+C` handling.
- `YAFP_STATUS_PROGRESS_STYLE` selects a block or fixed-width Braille progress
  bar without changing the compact prompt countdown.

Shared states are no-commits, no-upstream, checking, refreshing, current,
ahead, behind, diverged, and error. The local no-upstream state applies to
attached branches with a configured remote but no resolvable upstream
reference. It renders the
yellow `⇡?` indicator and a tracking-configuration banner in every theme.
It never starts a worker or uses the remote cache or countdown. Repositories
with commits but without remotes, detached HEAD, and disabled remote checks
remain silent. The no-commits state takes precedence for an unborn branch,
even without a remote, and renders a yellow `○0` with an initial-commit
banner. Staging preserves it; the first commit clears it. Neither local
warning starts a worker. Bash and zsh invalidate a cached non-repository
when a `.git` directory appears in the current directory, using a built-in
filesystem check.
The error state renders `☒🌐︎` as its compact indicator and the
`( ☒ REMOTE CHECK FAILED )` expansion in all three shells. This
state covers fetch and reference-comparison failures; it does not establish
that the internet is unavailable. Cache files are shared by shells using the
same Git directory, including restricted processes. A manual refresh bypasses
the cache interval and replaces the error after a successful worker completes.
Remote warning and error expansions reserve the row immediately above the
prompt,
save the cursor at the compact indicator, draw the centered message one row up,
and restore the cursor before rendering the indicator. This keeps alignment
independent of variable-width prompt prefixes without adding a process to the
render path.
Every expansion uses `( MESSAGE )`, with one space after the opening
delimiter and before the closing delimiter. Width and centering calculations
include both delimiters and the two inner spaces.
Message text includes a severity symbol (`✓`, `⚠`, or `☒`), so the fit and
centering calculations include its width too. Connection and warning styles
use explicit RGB green/white and yellow/black in all three shells, independent of
the terminal's configurable ANSI palette.
The delimiters are ASCII parentheses, avoiding font-dependent placement of
the Unicode parenthesis pieces previously used by the banners.
The staged-change expansion uses the same cursor-relative mechanism, centered
above `📦N`. When staged and remote expansions are both active, the renderer
reserves two rows so the messages do not overwrite each other.
Detailed staged and remote messages are selected only when their complete
`( … )` banner fits at the compact indicator's actual column. PowerShell reads
the host cursor column; Bash measures a marker-only render of the prompt prefix
with shell built-ins. Both select a compact alternative without adding an
external process or querying the terminal interactively.
The Bash measurement strips both Readline nonprinting spans and raw ANSI style
sequences, including character-set resets emitted by `tput`. Invisible separator
styles must not contribute to the column or its wrapping calculation.
Only ANSI stripping and zsh prompt-style wrapping run under the `C` locale:
macOS locale collation can reject the ASCII regex ranges. Unicode cell
measurement retains the caller's locale.
All three shells check the short alternative too and emit no banner text or cursor
movement when neither variant fits. Fixed connectivity messages use the same
check. Compact indicators remain visible; reserved expansion rows may stay empty.
Bash also reserves a small right-edge margin because browser terminals can
temporarily report a wider `COLUMNS` value and fonts can disagree on the cell
width of prompt symbols.
The first successful remote check and each later offline-to-online transition
set a one-render announcement. It displays
`( ✓ INTERNET CONNECTION )` with intense white text on a normal green
background and uses that same transition style for a compact `✓🌐︎`. Later
renders restore the normal intense-green foreground and transparent background.
The announcement takes precedence over any repository-state expansion for that
one prompt. Cached success from before the session does not trigger the initial
announcement, and reloads preserve the current connectivity state.
Bash, zsh, and PowerShell render the compact current-state `✓🌐︎` in intense green.
Expansions and compact prompt indicators share one severity contract: warnings
use black text on an intense yellow background, while errors use intense white
text on a red background. The warning background remains intense for contrast,
while `YAFP_DARKC` selects the dark or bright red error background. The
detailed `yafp-status` report retains foreground-only severity colors.

## Machine resource context

Optional monitoring defaults to `YAFP_RESOURCE_CHECK_INTERVAL=0`. An interval
from 1 through 86400 seconds enables one worker per session, independent of
the repository and Git workers. Existing hooks collect context before calling
themes; no hooks or timers are added. The initial query is asynchronous. A
later prompt consumes the result, retains its age, and requests another sample
only when the interval expires.

The new Unix capability lives in `scripts/unix/resources/context.bash` and
`collect.bash`; no existing engine behavior was moved. The shared context uses
Bash/zsh builtins to validate and read the cache and check the PID. Only the
initial private-directory creation and worker launch add processes when the
interval expires. Samples are published with an atomic rename inside the
session temporary directory, outside the checkout. Values read from the cache
are never evaluated as code. The worker is disowned, with stdin, stdout, and
stderr disconnected. A dead PID permits retrying after the interval expires;
a running worker prevents duplicates. The native zsh launcher uses `&!` to
disown at creation, just like the Git worker: redirecting output does not
suppress job-control notifications. The pseudo-terminal test checks that the
worker is absent from `jobs`, finishes without notifications, and leaves a
readable sample. Existing exit hooks remove the worker and session files.

PowerShell loads `scripts/windows/resources/context.ps1`. Its `Start-ThreadJob`
queries CIM/WMI without starting another PowerShell process. Individual probes
allow partial failures; in-memory results are collected only after completion,
and the job is removed. Reloads preserve the job and last sample. Rendering
neither waits nor invokes CIM. All three themes receive `Context.Resources`;
Bash/zsh use `yafp_ctx_resources` in their general host renderer.

Presentation attaches `⇢[resources]` directly to the hostname in every theme,
before the path or other host metadata. The old standalone resource position
is removed. `YAFP_RESOURCE_LABEL_STYLE` selects `letters`
(`C/R/S/D`, default) or `unicode` (`⚙/▦/⇄/◉`). The display order is CPU, RAM,
swap, and disk: swap sits between RAM and disk in every mode and theme. The
collection and cache order is unchanged. `YAFP_RESOURCE_VALUE_STYLE` selects
`percent` (default) or `symbols`. These options are independent, and invalid
values fall back to their defaults. Context defines an empty resource
separator only for `unicode` + `symbols`; all other modes use one space.
There is no padding between the host and frame or inside its brackets.
The prompt hides sample age, which remains in the plain `yafp-resources`
summary with a separating space. The summary uses the same resource separator
as the colored tokens. Symbolic mode
uses eight cells, from `⡀` through `⣿` as usage increases: the index is
`min(7, floor(percentage * 8 / 100))`, so 0% uses `⡀` and 100% uses `⣿`.

Context retains presentation tokens and colors for each resource, plus the
plain `yafp-resources` summary. The Unix renderer uses only builtins and marks
styles as invisible to Readline/zsh; PowerShell writes each token with
`NoNewline`. Foreground colors are green, yellow, and red, always on a
transparent background. The `⇢[]` frame reuses Git's structural style: the
Git block colors in `default`, and neutral separator colors in the other
themes. The closing bracket restores that style after the last resource.
An optional refresh marker stays inside the frame. Disabled monitoring emits
no empty frame. Host resources participate in the existing prompt-prefix
measurement, preserving staged and remote banner alignment when Git follows
the host. RAM, CPU, and disk become yellow above 85% and red
above 95%; swap uses thresholds above 10% and 30%. Comparison uses the integer
percentage before conversion to Braille, with red taking precedence. `N/D`
appears in gray. Shared fixtures check color boundaries,
Braille transitions, and all four combinations across shells and themes.

Swap usage is relative to allocated capacity; no allocated swap means 0%.
Age in seconds measures time since sampling, and `~` appears while a probe
runs. `N/D` indicates unavailable data. `yafp-resources` shows used/total values
for the last sample without waiting. README describes platform definitions
and diagnostic limitations. Probe and lifecycle tests use fixtures and
controlled workers to cover intervals, reload, failures, rendering without
external tools, and preservation of the previous command status.

## Silent prompt degradation

YAFP runs after every command and is part of the basic console interaction. By
design, a failure in optional information—such as history, the remote cache,
or a network job—must not prevent the prompt from rendering or write messages
that mix with user output. In those cases, the application continues with a
fallback value or an error remote state.

Deliberately empty `catch` blocks that implement this policy are exempted from
`PSAvoidUsingEmptyCatchBlock` through a function-scoped
`SuppressMessageAttribute` with a specific `Justification`. The rule is not
excluded globally: failures outside this expected degradation must be handled
normally. The exceptions can be audited with:

```powershell
$settings = './.PSScriptAnalyzerSettings.psd1'
Invoke-ScriptAnalyzer -Path . -Recurse -Settings $settings `
    -SuppressedOnly
```

## Theme contract

Themes receive precomputed context and must not perform Git or network queries.
Each implementation must represent, when applicable:

- user, host, and directory;
- branch and Git changes;
- staged Git changes and the black-on-intense-yellow commit-pending expansion;
- remote status;
- virtual environment;
- previous command status, with command errors rendered in intense red on a
  transparent background independently from banner severity styles;
- development metrics.

Adding a theme requires Bash, zsh, and PowerShell implementations, safe
fallback, and loading tests.

## Integration boundaries

YAFP controls the prompt and its hooks, but not the terminal emulator, ANSI
parser, or scrollback. OSC 133 provides semantic markers; it cannot capture or
draw output blocks by itself.

## Modularization strategy

Future separation must follow verifiable boundaries:

1. Pure utilities and measurement.
2. General context and command status.
3. Local and remote Git context.
4. Shell-specific hook integration.
5. Rendering and themes.

Before moving each boundary, create characterization tests, measure rendering
cost, and compare observable output. Modularization must not add external
processes during every prompt.

## Validation

Install the quality tools for the current platform with:

```bash
bash scripts/unix/setup/quality.bash
```

```powershell
pwsh -NoProfile -File scripts/windows/setup/quality.ps1
```

Both installers support a non-mutating setup-plan mode through `--dry-run` on
Unix and `-DryRun` on Windows.

The standalone `scripts/windows/setup/psscriptanalyzer.ps1` installer shares
its cross-platform module installation logic with the Windows quality setup
and `scripts/unix/setup/psscriptanalyzer.bash`. It pins PSScriptAnalyzer to
`1.25.0` in the current-user scope, reuses an existing matching version, and
verifies the imported command. PowerShell 7.2.11 or later must already be
installed. Setup tests mock module installation and the `pwsh` executable to
cover dry runs, repeated setup, argument forwarding, and failures without
network access or changes to installed modules.

Inspect the local environment without changing it with:

```bash
bash scripts/unix/doctor/check.bash
```

```powershell
pwsh -NoProfile -File scripts/windows/doctor/check.ps1
```

The doctors check required runtimes, optional quality tools, personal
configuration, supported values, theme pairing, and shell profile loading.
Strict mode (`--strict` or `-Strict`) also treats warnings as failures.

The canonical entry points are:

```bash
bash scripts/unix/quality/check.bash
```

```powershell
pwsh -NoProfile -File scripts/windows/quality/check.ps1
```

The Unix runner includes zsh checks when installed. The dedicated entry point
`bash scripts/unix/quality/zsh.bash` requires zsh 5.9 or later and Python 3
for pseudo-terminal tests. It checks syntax, all themes, native context,
banners, reload, local Git state transitions, nonblocking refreshes, abandoned
locks, worktrees, and live OSC 133 hooks, pipelines, and interruption. Linux
and macOS CI set `YAFP_REQUIRE_ZSH=1`.

The Bash preview test measures the visible prompt mark after stripping ANSI;
it accepts equivalent reset sequences from different terminfo entries.

CI runs these same entry points. The `YAFP_REQUIRE_LINTERS=1` variable turns a
missing optional analyzer into an error.

PowerShell RGB render fixtures separate nested arrays with commas so each
case retains its foreground, background, and expected ANSI sequence. Without
that separator PowerShell flattens the cases and indexes individual characters.

PowerShell render tests validate the countdown and compact remote indicator
separately. The captured information stream includes banner text and cursor
movement between them, even though they appear adjacent on the prompt line.
The behind-state test covers both the initial connection announcement and the
subsequent repository-state banner.

---

<!-- markdownlint-disable MD033 -->
<div style="text-align: right; font-size: 12px;">
📆 2026-10-29 20:37:42 🍎 MBP02 |
֎ OpenAI 🤖 Codex 🧠 GPT-6 Not exposed & 👨🏻‍💻 Nelbren ©️ 2026
</div>
