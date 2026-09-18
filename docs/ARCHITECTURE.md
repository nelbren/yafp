# YAFP architecture

## Purpose

This document describes YAFP's current boundaries and the invariants that must
be preserved when changing or modularizing the project.

## Components

<!-- markdownlint-disable MD013 -->

| Component                     | Responsibility                                         |
| ----------------------------- | ------------------------------------------------------ |
| `yafp-ps1.bash`               | Bash prompt core, context, hooks, and rendering        |
| `yafp-ps.ps1`                 | PowerShell prompt core, context, jobs, and rendering   |
| `themes/*.bash`               | Bash-specific presentation for each theme              |
| `themes/*.ps1`                | PowerShell-specific presentation for each theme        |
| `yafp-cfg.bash.example`       | Bash configuration template                            |
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

## Git context and remote status

Local context is collected during rendering. Remote queries never run in the
foreground:

- Bash starts a background worker and stores the result inside the actual Git
  directory.
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
- `yafp-ack` acknowledges the current offline incident for the session. It
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

Shared states are checking, refreshing, current, ahead, behind, diverged, and
error. The error state renders `☒🌐︎` as its compact
indicator and the `⎝ NO INTERNET CONNECTION ⎠` expansion in both shells. Remote
warning and error expansions reserve the row immediately above the prompt,
save the cursor at the compact indicator, draw the centered message one row up,
and restore the cursor before rendering the indicator. This keeps alignment
independent of variable-width prompt prefixes without adding a process to the
render path.
The staged-change expansion uses the same cursor-relative mechanism, centered
above `📦N`. When staged and remote expansions are both active, the renderer
reserves two rows so the messages do not overwrite each other.
Detailed staged and remote messages are selected only when their complete
`⎝ … ⎠` banner fits at the compact indicator's actual column. PowerShell reads
the host cursor column; Bash measures a marker-only render of the prompt prefix
with shell built-ins. Both select a compact alternative without adding an
external process or querying the terminal interactively.
The Bash measurement strips both Readline nonprinting spans and raw ANSI style
sequences, including character-set resets emitted by `tput`. Invisible separator
styles must not contribute to the column or its wrapping calculation.
Only ANSI stripping runs under the `C` locale: macOS locale collation can reject
the ASCII regex ranges. Unicode cell measurement retains the caller's locale.
Both shells check the short alternative too and emit no banner text or cursor
movement when neither variant fits. Fixed connectivity messages use the same
check. Compact indicators remain visible; reserved expansion rows may stay empty.
Bash also reserves a small right-edge margin because browser terminals can
temporarily report a wider `COLUMNS` value and fonts can disagree on the cell
width of prompt symbols.
The first successful remote check and each later offline-to-online transition
set a one-render announcement. It displays
`⎝ INTERNET CONNECTION ⎠` with intense white text on a normal green
background and uses that same transition style for a compact `✓🌐︎`. Later
renders restore the normal intense-green foreground and transparent background.
The announcement takes precedence over any repository-state expansion for that
one prompt. Cached success from before the session does not trigger the initial
announcement, and reloads preserve the current connectivity state.
Bash and PowerShell render the compact current-state `✓🌐︎` in intense green.
Expansions and compact prompt indicators share one severity contract: warnings
use black text on an intense yellow background, while errors use intense white
text on a red background. The warning background remains intense for contrast,
while `YAFP_DARKC` selects the dark or bright red error background. The
detailed `yafp-status` report retains foreground-only severity colors.

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

Adding a theme requires Bash and PowerShell implementations, safe fallback,
and loading tests.

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

CI runs these same entry points. The `YAFP_REQUIRE_LINTERS=1` variable turns a
missing optional analyzer into an error.

---

<!-- markdownlint-disable MD033 -->
<div style="text-align: right; font-size: 12px;">
📆 2026-09-18 00:39:53 🍎 |
֎ OpenAI 🤖 Codex 🧠 GPT-6 & 👨🏻‍💻 Nelbren ©️ 2026
</div>
