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

`scripts/unix/history/context.zsh` adds a zsh-only history display mitigation.
`YAFP_ZSH_HISTORY_REDRAW=1` enables it by default; other values disable it.
The native `add-zle-hook-widget` helper chains existing `line-init` and
`history-line-set` hooks and deduplicates repeated loads. Initialization resets
the per-input risk flag. History changes scan the new buffer using builtins
and request `.redisplay` when either the new or previous history entry contains
potentially problematic Unicode symbols, emoji ranges, or variation selectors.
The scan is conservative and runs on history transitions, not on each keypress.
It does not query the terminal, spawn processes, or maintain emoji-width tables.
ASCII and accented Latin entries avoid extra redraws. The widget reuses the
cached prompt and never assigns `BUFFER`/`CURSOR`, rebinds keys, runs context
collection, or emits command-start/completion markers. A redraw can repeat the
cached prompt's OSC A/B markers, as with the shell's own redisplay command.
This mitigates stale screen cells without fixing ZLE's Unicode width model or
guaranteeing cursor positioning while editing emoji. Logic and terminal tests
cover candidates, entering/leaving history entries, unchanged command text and
execution count, existing hooks, reload, and opting out.

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

## Cross-shell Unicode history review

The 2026-11-02 review compared Bash 3.2.57, Bash 5.3.20, and PowerShell 7.6.6
with PSReadLine 2.4.5 in isolated macOS pseudo-terminals. A controlled terminal
model handled UTF-8, emoji cell widths, cursor motion, erasure, and cursor
position queries; no unhandled control sequences remained. The seven input
cases were `⚠️`, `☁️`, `❤️`, `👨‍👩‍👧`, `🇭🇳`, `1️⃣`, and `👍🏽`. Each was
recalled, replaced with an ASCII history entry, recalled again, and executed,
both with a plain prompt and YAFP's light theme. All 42 Bash/PowerShell cases
returned to the clean ASCII line and preserved the exact expected output and
execution count. The same terminal model reproduced residual characters in
zsh 5.9 with `COMBINING_CHARS` and the mitigation disabled; enabling it removed
those remnants.

A separate cursor-position check found PSReadLine offsets of six cells for
`👨‍👩‍👧` and one for `1️⃣`, with or without YAFP. `Ctrl+L` did not correct the
family-emoji offset. The installed assembly's width calculation and the tagged
[PSReadLine 2.4.5 renderer](https://github.com/PowerShell/PSReadLine/blob/v2.4.5/PSReadLine/Render.Helper.cs)
both sum individual UTF-16 character widths, rather than measuring the whole
grapheme. Repainting history cannot fix that underlying model. YAFP retains
native Readline/PSReadLine bindings instead of adding a speculative automatic
history wrapper to Bash or PowerShell.

A follow-up feasibility check evaluated cursor-only compensation through public
PSReadLine/console APIs, without changing input or existing bindings. Public
`GetBufferState` exposes the logical cursor, but PSReadLine has no public
post-render event. Its documented `OnIdle` notification is restricted to an
empty edit buffer. An isolated timer/reader-wrapper prototype did not retain
its correction through editing or history navigation in the macOS terminal
probe. A new, otherwise unbound key handler could correct the physical cursor
once, but subsequent editing again used the editor's original width model.
These prototypes are not part of YAFP. A stable automatic solution under the
unchanged-command/unchanged-key-binding constraint requires support in the
line editor; speculative polling or private PSReadLine patches are not enabled.

These are controlled macOS tests, not a visual iTerm test or a native Windows,
Linux, WSL2, or Git Bash certification. Terminal/font differences and other
editor versions can change the result. Any additional mitigation needs a
reproducer for the affected editor and host, rather than assuming zsh's fix
applies unchanged.

## Startup update check

The first interactive load in a shell session performs a synchronous check of
YAFP's installation before showing the prompt. A process-ID marker survives
reloads and is set before checking, preventing recursive or repeated startup
checks. A current installation produces no startup output. For warnings,
errors, or an update offer, the installation path is printed explicitly,
independent of the current directory. The header is intense white. Startup
lines have no enclosing parentheses and reuse the warning/error palette, including
`YAFP_DARKC` for error backgrounds. Unix resets ANSI styling before each newline
and emits plain text when redirected or when `NO_COLOR` is set. PowerShell
uses the shared text writer and severity style helper. This startup-only wait
is an exception to the usual background-only
remote monitoring; prompt rendering never performs the startup check.

Unix loads `scripts/unix/update/context.bash` and waits for `collect.bash`.
PowerShell loads `scripts/windows/update/context.ps1` and calls `collect.ps1`
directly, without jobs. Both collectors disable credential prompts. Unix gives
Git a private process group for its 15-second fetch deadline; PowerShell drains
redirected streams and kills timed-out Git process trees after 15 seconds.
No persistent worker or prompt hook is added. Unix removes its temporary result
immediately after consumption.

After fetching, ahead and behind counts are computed against the tracking
branch. Startup distinguishes current, ahead (` REMOTE NOT UPDATED`), behind
(` OUTDATED REPOSITORY`), and diverged states, without a separate warning for
local modifications.
Missing Git, non-Git installations, unborn branches, detached HEAD, and missing
upstream/remote configurations receive explicit messages. Failed remote access
shows `🌐 REMOTE CHECK FAILED`, without claiming that general internet access
was independently tested.

Only a behind-only checkout offers `Update YAFP now? [y/N]`. Enter, EOF, and
answers other than `y`/`Y` decline. Accepted updates use `git pull --ff-only` in
the installation and reload only after success. Divergence never creates an
automatic merge or push. HEAD, branch, and upstream are checked against the
result before offering an update. Noninteractive or redirected sessions, test
hook suppression, and `YAFP_UPDATE_CHECK=0` disable startup checking.

Local-remotes tests cover consent, refusal, successful reload, once-per-session
loading, current/ahead/behind/diverged states independent of local edits,
failed access, timeout,
worktrees, detached HEAD, missing upstream, and stale results.

## Local startup counter

All three loaders invoke the startup adapter outside rendering functions. A
shell PID marker prevents duplicate events on reload. Unix disowns the writer;
zsh uses native `&!` at creation so neither launch PIDs nor completion notices
appear in the terminal;
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
  suppresses the error expansion and keeps the compact indicator intense
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
The error state renders `` as its compact indicator and the
`(  REMOTE CHECK FAILED )` expansion in all three shells. This
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
Message text includes a severity symbol (``, ``, or ``), so the fit and
centering calculations include its width too. Connection and warning styles
use explicit RGB green/white and yellow/black in all three shells, independent of
the terminal's configurable ANSI palette.
The delimiters are ASCII parentheses, avoiding font-dependent placement of
the Unicode parenthesis pieces previously used by the banners.
The staged-change expansion uses the same cursor-relative mechanism, centered
above `N`. When staged and remote expansions are both active, the renderer
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
`(  INTERNET CONNECTION )` with intense white text on a normal green
background. The compact `` shares the banner colors when the announcement fits.
It uses intense green on a transparent background otherwise.
The announcement takes precedence over any repository-state expansion for that
one prompt. Cached success from before the session does not trigger the initial
announcement, and reloads preserve the current connectivity state.
Bash, zsh, and PowerShell use Nerd Font icons `` (`U+F1EB`) for successful
remote checks and `` (`U+F072`) for failures. Old indicators remain commented
in their rendering code. Each icon occupies one cell for banner alignment.
Expansions and compact prompt indicators share one severity contract: warnings
use black text on an intense yellow background, while error banners and
behind/diverged counters use intense white
text on a red background. The compact error icon `` shares the white text
and red background of the active alert. After
acknowledgement, it uses intense red text on a transparent
background. The warning background remains intense for contrast,
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
If the session directory disappears, the next scheduled refresh creates a
new private directory before launching its worker. An active worker still
prevents a replacement; recovery preserves the interval and worker limit.

PowerShell loads `scripts/windows/resources/context.ps1`. Its `Start-ThreadJob`
queries CIM/WMI without starting another PowerShell process. Individual probes
allow partial failures; in-memory results are collected only after completion,
and the job is removed. Reloads preserve the job and last sample. Rendering
neither waits nor invokes CIM. All three themes receive `Context.Resources`;
Bash/zsh use `yafp_ctx_resources` in their general host renderer.

Presentation attaches `↦[resources]` directly to the hostname in every theme,
before the path or other host metadata. The old standalone resource position
is removed. `YAFP_RESOURCE_LABEL_STYLE` selects `letters`
(`C/R/S/D`, default) or `unicode` (`/▦//`). The display order is CPU, RAM,
swap, and disk: swap sits between RAM and disk in every mode and theme. The
collection and cache order is unchanged. `YAFP_RESOURCE_VALUE_STYLE` selects
`percent` (default) or `symbols`. These options are independent, and invalid
values fall back to their defaults. Context defines an empty resource
separator only for `unicode` + `symbols`; all other modes use one space.
There is no padding between the host and frame or inside its brackets.
The prompt hides sample age, which remains in the internal textual
summary with a separating space. The summary uses the same resource separator
as the colored tokens. Symbolic mode
uses eight cells, from `⡀` through `⣿` as usage increases: the index is
`min(7, floor(percentage * 8 / 100))`, so 0% uses `⡀` and 100% uses `⣿`.

Context retains presentation tokens and colors for each resource, plus the
internal textual summary. The Unix renderer uses only builtins and marks
styles as invisible to Readline/zsh; PowerShell writes each token with
`NoNewline`. Foreground colors are green, yellow, and red, always on a
transparent background. The `↦[]` frame reuses Git's structural style: the
Git block colors in `default`, and neutral separator colors in the other
themes. The closing bracket restores that style after the last resource.
The optional gray refresh icon `` (`U+F021`) stays inside the frame and touches
the last token; no space precedes ``. Disabled monitoring emits no empty
frame. Host resources participate in the existing prompt-prefix
measurement, preserving staged and remote banner alignment when Git follows
the host. RAM, CPU, and disk become yellow above 85% and red
above 95%; swap uses thresholds above 10% and 30%. Comparison uses the integer
percentage before conversion to Braille, with red taking precedence.
Missing values use a red ``. Shared fixtures check color boundaries,
Braille transitions, and all four combinations across shells and themes.

Swap usage is relative to allocated capacity; no allocated swap means 0%.
Age in seconds measures time since sampling, and `` appears while a probe
runs. Timed summaries append it directly to the age, such as `17s`; the prompt
appends it directly to the final resource token. While the first sample is
pending, context supplies gray loading tokens for CPU, RAM, swap, and disk,
using the configured labels and separator. The prompt displays
`↦[⟳▦⟳⟳⟳]` in Unicode + symbols mode, without a trailing ``.
The `yafp-resources` report displays a frame shared with the other diagnostic
tools. Its six aligned fields are `State`, `Sample age`, `CPU`, `RAM`, `SWAP`,
and `Disk (HOME)`. Metrics always appear as percentages and retain used/total
details and their units. Labels use Font Awesome; missing values appear as a
gray ``. Context retains percentages before conversion to Braille;
the report reuses those values and their colors without changing thresholds.

States are `ok` (sample available), `refreshing` (sample available and worker
active), `pending` (worker without a sample), `unavailable`, and `disabled`.
The `` icon and its `refreshing` state remain gray. Age and details come only
from the sample accepted during the current read; an invalid cache cannot
redisplay old diagnostic data. Partial metrics remain available, and
unallocated swap remains zero. The command does not wait for the worker.
The context text markers `Resources: waiting for sample` and
`Resources: no valid sample` remain internal; the report presents them through
`State`. Without a valid sample, the prompt produces four red tokens with
``, respecting labels and the separator (`↦[▦]` in Unicode +
symbols mode). Missing partial metrics also use ``; valid values retain
their colors. README describes
platform definitions and diagnostic limitations. Probe and lifecycle tests use
fixtures and controlled workers to cover intervals, reload, failures, rendering
without external tools, and preservation of the previous command status.

The `yafp-demo-resources` command generates three readings for the selected
resource. With `ALL`, it shows all four groups in CPU, MEMORY, SWAP, and DISK
order, separated by blank lines. It reuses the metric formatter and the system
icon and frame rendering. Bash and zsh isolate tokens in local variables.
PowerShell passes temporary context to the renderers. The demo does not read
the cache or start a worker. The label and percentage occupy a fixed-width
field to align the examples.

## Codex quota context

`YAFP_CODEX_CHECK_INTERVAL=0` disables this independent optional context.
Positive intervals up to 86400 seconds enable one background worker per shell
session. The existing prompt and preview hooks collect context; no additional
hooks, credential prompts, or foreground network requests are introduced.

Unix loads `scripts/unix/codex/context.bash`, which validates a private cache
using builtins, throttles requests with `SECONDS`, and preserves worker/cache
state across reloads. Its Bash launcher delegates to `collect.py` when Python
3 is available and publishes `missing-python` otherwise. The native zsh
launcher uses `&!`, matching the silent Git/resource lifecycle. The Python
collector starts a private stdio `codex app-server`, initializes JSON-RPC,
reads `account/read` with `refreshToken=false`, and requests
`account/rateLimits/read` only for a ChatGPT account. It ignores unrelated
notifications and never invokes login, conversations, credits, or reset APIs.
The worker has a ten-second deadline and terminates its private process group
on completion, timeout, or normal shell cleanup. Native Python in Git Bash
uses Windows process-tree termination instead.

`yafp-codex --debug` extends only the requested report. On Unix, the worker
atomically publishes `sample.debug`: the attempt's session-clock value,
stage, fixed reason, elapsed milliseconds, and server PID. It publishes a
snapshot before each request and another after cleanup. The reader validates
numeric fields and closed sets of stages and reasons, and requires the
attempt to match `YAFP_CODEX_ATTEMPT`. It does not evaluate file contents or
attribute an old stage to the new worker. Diagnostic files and their temporary
files are removed with the session cache. Older collectors remain compatible
and show `no-diagnostics` until the next query. Normal rendering does not read
this additional file.

Windows loads `scripts/windows/codex/context.ps1` and runs the native
`collect.ps1` client in a `Start-ThreadJob`. Redirected process streams,
asynchronous reads, a shared deadline, and process-tree cleanup isolate the
CLI from the prompt. Both native binaries and npm `.cmd` launchers are
supported. Completed jobs are received and removed without waiting; reloads
preserve the job and sample. No Python dependency is added on Windows.

In PowerShell, the synchronized control shares a diagnostic snapshot by
replacing its reference; the final result also includes it. The attempt's
clock value is passed to the job to associate progress even if it starts in
a different second. The report accepts `--debug` and `-Diagnostics`, shows
the job ID and server PID, and does not wait for the job. Both systems retain
the last stage with a fixed reason (`rpc-error`, `server-closed`,
`invalid-response`, `no-valid-limits`, among others), without persisting error
messages, stderr, or account data. Final duration includes cleanup; active
duration is approximate. The server PID is historical, not proof of activity.
If the worker disappears with reason `in-progress`, the report shows
`worker-ended`. Diagnostics preserve existing scheduling and never start a
second worker or make foreground network queries.

Both collectors prefer `rateLimitsByLimitId.codex`, falling back to the legacy
`rateLimits` view without accepting an unrelated bucket. They validate numeric
`usedPercent` values and compute `floor(100 - usedPercent)` for each available
window. The minimum remaining value determines the single indicator. Missing
windows are not interpreted as zero. Caches contain only the sample time,
fixed state, remaining percentages, and reset timing; no account identity or
credentials.
Errors overwrite the old value with an unavailable sample at the next prompt.

The selected window also supplies `resetsAt`; primary wins percentage ties.
Only positive integer timestamps up to 9999999999 are accepted. On Unix, the
collector converts that epoch time into a deadline on the session `SECONDS`
clock. The optional sixth cache field holds that deadline; existing five-field
samples remain valid and omit the countdown. PowerShell retains the epoch
value in `Sample.ResetsAt` and uses the existing context clock. Neither
renderer needs a date process or another network call. Missing or malformed
reset timestamps omit the timer without discarding valid availability.
As with Unix resource monitoring, a missing temporary quota directory is
replaced at the next scheduled refresh, after any active worker finishes.

All themes append a compact reset countdown directly after the quota value,
without a separator inside the frame, for example `↤[֍75%5d9h]` or
`↤[֍⣷5d9h]`. Formatting keeps two units (days/hours, hours/minutes, or
minutes/seconds), or just seconds below
one minute. Subordinate units are rounded down; expired deadlines clamp to
`0s` while waiting for the next sample. The timer shares the quota foreground
color and participates in the existing prefix-width measurement.

All themes insert `↤[֍value]` immediately after the username, before `@`.
`YAFP_CODEX_VALUE_STYLE` chooses `percent` or `symbols` independently of the
machine resource options. Braille uses `min(7, floor(value * 8 / 100))` with
fuller cells meaning greater availability. Foreground is green at 50% or
above, yellow at 25% or above, and red below 25%. Red `֍dh` covers missing
dependencies, authentication, quota, and errors. Before the first sample, an
active worker displays gray `֍⟳d⟳h`, with day/hour placeholders for the pending
reset countdown. Valid samples replace the placeholders with the existing
quota and duration formatting; later refreshes retain the last sample. The
frame shares Git delimiter colors and the existing prompt-prefix width
measurement.
Disabled context renders no prompt frame. The `yafp-codex` report reuses the
diagnostic frame and shows three aligned fields: ` Reset` in days and hours,
` State` with a semantic icon for each state, and ` Remaining` with the
aggregate percentage limiting the quota. It does not change with the prompt's
Braille style or print individual windows or sample age. Missing fields use
a gray `` (`U+F059`, question-circle); an elapsed deadline is clamped to
`0d0h`. Query state and percentage severity have independent colors.

On Unix, context exposes state, value, and deadline derived only from the
sample validated during that read, preventing a report without a sample from
reusing diagnostic data from a previous read. PowerShell uses the context's
sample object. `pending` requires an active worker, and `disabled` retains the
configuration hint. The report does not wait for the worker or modify window
selection or the prompt token.

Offline protocol peers and shared boundary fixtures test authentication gates,
bucket selection, unavailable values, timeouts, atomic publication, worker
uniqueness/reload, all themes, invisible ANSI markers, and previous exit status.
The interactive zsh test also covers job notifications and OSC 133 while quota
and machine resource monitoring coexist.

The Git connection announcement invalidates the Codex timer once per
transition. The prompt collects Git context first so Codex can start a check
during the same pass. If a worker is active, the request remains pending until
it finishes. A zero interval keeps Codex disabled.

## Uniform indicator frames

Codex uses `↤[…]` after the username. Resources and populated Git counter
groups use `↦[…]` in Bash, zsh, and PowerShell. Git remote status uses `[…]↤`.
Git and resource refreshes use `` (`U+F021`); `⟳` denotes initial pending
values in the resource and Codex blocks. Git retains its warning colors and
resources retain gray. The Git icon touches its cached state, as in `[]↤`,
and the detailed remote report uses the same refresh icon.
The frame uses `cGit` in the Unix default
theme and `cSeparator` in the other themes; PowerShell uses the equivalent
Git delimiter foreground/background pair. Each inner indicator retains its
existing color, including warnings, errors, staged counts, and the connection
announcement. The closing bracket restores the frame style.

The remote renderer groups countdown, refresh marker, and status without inner
spaces: `[⣦]↤` or `[(175)]↤`. The frame touches the Git icon, which
touches the branch. The branch also touches the change frame. An empty remote
context emits nothing. The Git icon is `` for a configured remote and ``
otherwise. The cached remote status selects green for a successful check,
red for a failure, and yellow for unavailable status or a local repository.
The counter renderer owns its single wrapper in all themes; light no longer
adds a second frame. Empty counter groups remain silent. The counters share
``, ``, and `` in red, yellow, and cyan in every theme. Each number
follows its icon directly, as in `↦[123]`.

Unix measures the prefix in terminal cells to locate the indicator column
and wrapped row. PowerShell uses the cursor position. Remote banners move
left at the right edge to stay inside the row reserved above the prompt. Before
emitting a staged expansion, the counter renderer flushes earlier counters so
the marker anchors the staged token at its actual column inside the frame.
PowerShell writes the frame and preceding counters before capturing the banner
cursor position. Shared Bash/zsh tests and portable PowerShell tests cover all
themes, dark/bright frame colors, compact states, empty groups, a single frame
per group, and preservation of severity colors. Existing banner and interactive
tests cover positioning, narrow terminals, and OSC 133 behavior.

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

## OS and repository glyphs

OS indicators use Font Awesome glyphs supplied by Nerd Fonts: macOS ``
(`U+F179`), Windows `` (`U+F17A`), and Linux `` (`U+F17C`). Unix server
and client detection shares this mapping, including Windows-backed client
composites. Linux servers specialize exact `/etc/os-release` IDs `debian`
(``) and `kali` (`㉿`); all others, including Ubuntu, use ``. Reading uses
shell builtins without evaluating file contents. Missing or unreadable release
files and absent IDs fall back to ``; `ID_LIKE` does not select a logo.
PowerShell themes use the Windows glyph
where an OS indicator already exists. In `minimal` and `light`, the server
icon reuses the colors of the four resource indicators. Red takes precedence
over yellow, and other states appear white. Evaluation uses prompt data
already in memory.

Git logos `` (`U+F1D3`) and `` (`U+F1D2`) distinguish branches with
and without a configured remote. Old assignments remain commented beside
their replacements. These glyphs use existing colors and width measurement;
rendering adds no font probing or external process. Existing directory markers
use `` (`U+F07C`); current timestamp markers use `` (`U+F017`) across themes.
Their replaced assignments remain commented in the engines and themes.
The terminal's local Nerd
Font must contain the glyphs, including when displaying a remote shell.

Prompt states and decorative labels use the Font Awesome glyphs documented
in [FONTS.md](FONTS.md#prompt-icons). Bash and zsh retain their `YAFP_SYMBOL_*`
variables; PowerShell uses the same glyphs in its renderers. Replacements are
limited to static labels: command, path, branch, and environment text is not
rewritten. No processes, font detection, or additional per-render work are
introduced.

Expansions measure the displayed text with the counter glyphs. The remote
timer uses `` with the existing green, yellow, or red shades; its text retains
percentages and seconds. All themes use `` and `` for success and error.
Braille indicators, `֍`, ``, `⟳`, frames, and time-of-day symbols retain
their representation. Presentation tests verify dark/light variants, all
three themes, performance thresholds, and expansion anchors with these labels.

The report shared by `yafp-status` and `yafp-demo` uses Font Awesome icons for
the remote, up-to-date status, current time, and next check. All four labels
end in the same column, even when no data is available. The preview and
interruption reminder also use Font Awesome; the loop, its four-second pause,
and OSC 133 sequences retain their logic. PowerShell keeps its recognition
patterns aligned with the new labels to preserve timestamp colors.

### Diagnostic frames

`yafp-demo`, `yafp-codex`, `yafp-resources`, `yafp-status`, `yafp-stats`,
`yafp-help`, and `yafp-msgs` load the helpers
`scripts/unix/preview/lib/frame.bash` and
`scripts/windows/preview/lib/frame.ps1` on demand. No processes or work are
added to interactive prompt rendering. The normal preview remains available
without a frame; Bash/zsh select the frame with the internal `frame` argument.
PowerShell captures the preview's information records and converts their
console colors to SGR before drawing the frame.

`Write-YafpText` emits `HostInformationMessage` records with the requested
colors: an unspecified background remains null. This prevents `Write-Host`
from materializing the current `RawUI` background on Windows and turning it
into an explicit background inside the frame. Requested backgrounds, RGB
banners, and separate newlines retain their behavior. Tests set black and blue
console backgrounds to verify this capture even on hosts that do not normally
expose a default color.

A cell canvas interprets newlines, SGR, line erasure, and the relative and
save/restore movements used by banners. Only text, colors, and borders are
printed; movements do not escape the frame. Lines wrap according to their
visible width, accounting for combining marks and double-width characters.
Bash 3.2 decodes the first UTF-8 byte returned by its `printf` to measure
these characters in the preview. This follows YAFP's width model; it does not
replace the editor's or terminal's grapheme calculations.

The interior width is the terminal width minus five columns: four for the
borders and their inner padding, and one free column at the right margin.
The frame uses gray, with a color reset before the margins; terminals with
fewer than seven columns retain normal output. Tests cover wrapping, colors,
Unicode, banners, erasure, and narrow output; a zsh PTY test verifies actual
execution at 240 and 60 columns, OSC 133, and interruption.

`yafp-status` frames the existing formatter's result without querying remote
context again. Bash/zsh use an internal `frame` formatter mode; PowerShell uses
`-Framed`. Unframed formatters preserve their text contracts for field and
timestamp tests. Captured color on Unix is enabled only in the diagnostic
formatter and respects `NO_COLOR`. The `yafp-demo` view contains two independent
frames: status and prompt.

`yafp-stats` preserves counter operations, rounding, alignment, and all four
report lines inside the frame. The automatic exit report is also framed.
PowerShell offers the renderer `-DirectConsole` to write directly with
`Console.WriteLine` during `PowerShell.Exiting`, without depending on host
message delivery at shutdown. It restores the original console colors when
available. Tests compare framed text with previous characterizations and
check colors, the direct console path, zero commands, reload, and EXIT chaining.

`yafp-help` and `yafp-msgs` frame their static catalogs with the same renderer.
Their internal `plain` mode on Unix and `-Plain` mode on PowerShell preserve
the original formatters to characterize text, order, and styles. The public
path captures that colored text once and applies the frame; it does not query
Git, resources, or services. Tests compare entries with previous catalogs,
validate help colors, and check banner backgrounds in light and dark modes,
along with borders and wrapping in the shared renderer.

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

The Windows CI installer and PowerShell validator preview use
`-SkipShellCheck`. The full installation includes ShellCheck for Git Bash.
The Linux job validates Bash with ShellCheck.

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
📆 2026-11-03 20:55:30 🍎 MBP02 |
֎ OpenAI 🤖 Codex 🧠 GPT-6 Not exposed & 👨🏻‍💻 Nelbren ©️ 2026
</div>
