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
(`☒ OUTDATED REPOSITORY`), and diverged states, without a separate warning for
local modifications.
Missing Git, non-Git installations, unborn branches, detached HEAD, and missing
upstream/remote configurations receive explicit messages. Failed remote access
shows `☒🌐 REMOTE CHECK FAILED`, without claiming that general internet access
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
Message text includes a severity symbol (`✓`, ``, or `☒`), so the fit and
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
`( ✓ INTERNET CONNECTION )` with intense white text on a normal green
background. The compact `` remains intense green on a transparent background
during that announcement and on subsequent renders.
The announcement takes precedence over any repository-state expansion for that
one prompt. Cached success from before the session does not trigger the initial
announcement, and reloads preserve the current connectivity state.
Bash, zsh, and PowerShell use Nerd Font icons `` (`U+F1EB`) for successful
remote checks and `` (`U+F072`) for failures. Old indicators remain commented
in their rendering code. Each icon occupies one cell for banner alignment.
Expansions and compact prompt indicators share one severity contract: warnings
use black text on an intense yellow background, while error banners and
behind/diverged counters use intense white
text on a red background. The compact error icon `` always uses intense red
text on a transparent background, before and after acknowledgement. The
warning background remains intense for contrast,
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
percentage before conversion to Braille, with red taking precedence. `N/A`
appears in gray. Shared fixtures check color boundaries,
Braille transitions, and all four combinations across shells and themes.

Swap usage is relative to allocated capacity; no allocated swap means 0%.
Age in seconds measures time since sampling, and `` appears while a probe
runs. Timed summaries append it directly to the age, such as `17s`; the prompt
appends it directly to the final resource token. While the first sample is
pending, context supplies gray loading tokens for CPU, RAM, swap, and disk,
using the configured labels and separator. The prompt displays
`↦[⟳▦⟳⟳⟳]` in Unicode + symbols mode, without a trailing ``.
El informe `yafp-resources` muestra un cuadro compartido con las otras
herramientas de diagnóstico. Sus seis campos alineados son `State`,
`Sample age`, `CPU`, `RAM`, `SWAP` y `Disk (HOME)`. Las métricas se muestran
siempre como porcentajes y conservan los detalles usados/totales y sus unidades.
Las etiquetas usan Font Awesome; los valores ausentes se representan con ``
en gris. El contexto conserva porcentajes antes de su conversión a Braille;
el informe reutiliza esos valores y sus colores, sin cambiar los umbrales.

Los estados son `ok` (muestra disponible), `refreshing` (muestra disponible y
trabajador activo), `pending` (trabajador sin muestra), `unavailable` y
`disabled`. El icono `` y su estado `refreshing` siguen en gris. La edad y los
detalles solo proceden de la muestra aceptada en la lectura actual; una caché
inválida no puede volver a mostrar datos diagnósticos antiguos. Las métricas
parciales permanecen disponibles y un swap no asignado sigue siendo cero.
El comando no espera al trabajador. Los marcadores textuales de contexto
`Resources: waiting for sample` y `Resources: no valid sample` siguen siendo
internos; el informe los presenta mediante `State`. Las cadenas `N/A` del
prompt conservan su significado. README describes platform definitions
and diagnostic limitations. Probe and lifecycle tests use fixtures and
controlled workers to cover intervals, reload, failures, rendering without
external tools, and preservation of the previous command status.

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

Windows loads `scripts/windows/codex/context.ps1` and runs the native
`collect.ps1` client in a `Start-ThreadJob`. Redirected process streams,
asynchronous reads, a shared deadline, and process-tree cleanup isolate the
CLI from the prompt. Both native binaries and npm `.cmd` launchers are
supported. Completed jobs are received and removed without waiting; reloads
preserve the job and sample. No Python dependency is added on Windows.

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
above, yellow at 25% or above, and red below 25%. Gray `֍N/A` covers missing
dependencies, authentication, quota, and errors. Before the first sample, an
active worker displays gray `֍⟳d⟳h`, with day/hour placeholders for the pending
reset countdown. Valid samples replace the placeholders with the existing
quota and duration formatting; later refreshes retain the last sample. The
frame shares Git delimiter colors and the existing prompt-prefix width
measurement.
Disabled context renders no prompt frame. El informe `yafp-codex` reutiliza el
marco de diagnóstico y muestra tres campos alineados: ` Reset` en días y
horas, ` State` con un icono semántico por estado, y ` Remaining` con el
porcentaje agregado que limita la cuota. No cambia según el estilo Braille del
prompt ni imprime las ventanas individuales o la edad de la muestra. Los
campos ausentes usan `` (`U+F059`, question-circle) en gris; el plazo
vencido se limita a `0d0h`. El estado de
consulta y la severidad del porcentaje tienen colores independientes.

En Unix, el contexto expone estado, valor y plazo derivados únicamente de la
muestra validada en esa lectura, evitando que un informe sin muestra reutilice
datos diagnósticos de una lectura anterior. PowerShell usa el objeto de muestra
del contexto. `pending` exige un trabajador activo y `disabled` conserva la
instrucción de configuración. El informe no espera al trabajador ni modifica
la selección de ventana o el token del prompt.

Offline protocol peers and shared boundary fixtures test authentication gates,
bucket selection, unavailable values, timeouts, atomic publication, worker
uniqueness/reload, all themes, invisible ANSI markers, and previous exit status.
The interactive zsh test also covers job notifications and OSC 133 while quota
and machine resource monitoring coexist.

## Uniform indicator frames

Codex uses `↤[…]` after the username; resources, Git remote status, and
populated Git counter groups use `↦[…]` in Bash, zsh, and PowerShell.
Git and resource refreshes use `` (`U+F021`); `⟳` denotes initial pending
values in the resource and Codex blocks. Git retains its warning colors and
resources retain gray. The Git icon touches its cached state, as in `↦[]`,
and the detailed remote report uses the same refresh icon.
The frame uses `cGit` in the Unix default
theme and `cSeparator` in the other themes; PowerShell uses the equivalent
Git delimiter foreground/background pair. Each inner indicator retains its
existing color, including warnings, errors, staged counts, and the connection
announcement. The closing bracket restores the frame style.

The remote renderer groups countdown, refresh marker, and status without inner
spaces: `↦[⣦]` or `↦[(175)]`. All remote states share that wrapper;
an empty context emits nothing. The frame is attached directly to the preceding
Git marker, without a leading space; one trailing space separates the branch.
Unix themes own this trailing separator, and PowerShell emits it in the remote
renderer.
The counter renderer owns its single wrapper in all themes; light no longer
adds a second frame. Empty counter groups remain silent. Labels, counter
emoji, and clean-worktree presentation remain theme-specific.

Unix includes each frame in the existing expansion-prefix measurement. Before
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
where an OS indicator already exists.

Git logo `` (`U+F1D3`) replaces the minimal/light Git marker and the
repository-name prefix in default. Branch separators, remote origin symbols,
and counters retain their semantics. Old assignments remain commented beside
their replacements. These glyphs use existing colors and width measurement;
rendering adds no font probing or external process. Existing directory markers
use `` (`U+F07C`); current timestamp markers use `` (`U+F017`) across themes.
Their replaced assignments remain commented in the engines and themes.
The terminal's local Nerd
Font must contain the glyphs, including when displaying a remote shell.

Los estados y las etiquetas decorativas del prompt usan los glifos Font
Awesome documentados en [FONTS.md](FONTS.md#iconos-del-prompt). Bash y zsh
conservan sus variables `YAFP_SYMBOL_*`; PowerShell usa los mismos glifos en
sus renderizadores. Los reemplazos se limitan a etiquetas estáticas: no se
reescribe el texto de comandos, rutas, ramas ni entornos. No se incorporan
procesos, detección de fuentes ni trabajo adicional por renderizado.

Los contadores mantienen sus signos y colores, y las expansiones miden el
texto que se muestra con los nuevos glifos. El temporizador remoto usa ``
con los tonos verde, amarillo o rojo existentes; el texto conserva porcentaje
y segundos. `light` mantiene sus marcas `✓`, `☒`, `↯` y los contadores
numéricos. Los indicadores Braille, `֍`, ``, `⟳`, marcos y momentos del día
conservan su representación. Las pruebas de presentación verifican las
variantes oscuras/claras, los tres temas, los umbrales de rendimiento y los
anclajes de las expansiones con estas etiquetas.

El informe compartido de `yafp-status` y `yafp-demo` usa iconos Font Awesome
para remoto, estado al día, hora actual y próxima revisión. Las cuatro
etiquetas terminan en la misma columna, incluso sin datos disponibles. La
vista previa y el aviso de interrupción también usan Font Awesome; el bucle,
su pausa de cuatro segundos y las secuencias OSC 133 conservan su lógica.
PowerShell mantiene sus patrones de reconocimiento alineados con las nuevas
etiquetas para conservar los colores de las horas.

### Marcos de diagnóstico

`yafp-demo`, `yafp-codex`, `yafp-resources`, `yafp-status`, `yafp-stats`,
`yafp-help` y `yafp-msgs` cargan bajo demanda los helpers
`scripts/unix/preview/lib/frame.bash` y
`scripts/windows/preview/lib/frame.ps1`. No se añaden procesos ni trabajo al
renderizado del prompt interactivo. La vista previa normal sigue disponible
sin marco; Bash/zsh seleccionan el cuadro con el argumento interno `frame`.
PowerShell captura los registros de información de la vista previa y convierte
sus colores de consola a SGR antes de dibujar el cuadro.

Un lienzo de celdas interpreta saltos de línea, SGR, borrado de línea y los
movimientos relativos y de guardado/restauración usados por los avisos. Solo
se imprimen texto, colores y los bordes; los movimientos no escapan del cuadro.
Las líneas se distribuyen según su ancho visible, con tratamiento de marcas
combinantes y caracteres de dos celdas. Bash 3.2 decodifica el primer byte UTF-8
que devuelve su `printf` para medir estos caracteres en la vista previa.
Se sigue el modelo de ancho de YAFP; no se sustituye el cálculo de grafemas
del editor ni el de la terminal.

El ancho interior es el ancho de terminal menos cinco columnas: cuatro para
los bordes y su espacio interior, y una libre al margen derecho. El cuadro
usa gris, con restablecimiento de color antes de los márgenes; menos de siete
columnas conserva la salida normal. Las pruebas cubren ajuste de línea,
colores, Unicode, avisos, borrado y la salida estrecha; una prueba PTY de zsh
verifica la ejecución real a 240 y 60 columnas, OSC 133 e interrupción.

`yafp-status` encuadra el resultado del formateador existente sin volver a
consultar el contexto remoto. Bash/zsh usan un modo interno `frame` en el
formateador; PowerShell usa `-Framed`. Los formateadores sin marco conservan
sus contratos de texto para las pruebas de campos y horas. El color capturado
en Unix se habilita solo en el formateador de diagnóstico y respeta `NO_COLOR`.
La vista de `yafp-demo` contiene dos cuadros independientes: estado y prompt.

`yafp-stats` conserva las operaciones de contadores, el redondeo, la alineación
y las cuatro líneas del informe dentro del cuadro. También se encuadra el
informe automático de salida. PowerShell ofrece al renderer `-DirectConsole`
para escribir directamente con `Console.WriteLine` durante `PowerShell.Exiting`,
sin depender de la entrega de mensajes del host al cerrar. Restaura los colores
de consola originales cuando están disponibles. Las pruebas comparan el texto
dentro del cuadro con las caracterizaciones anteriores y comprueban colores,
la ruta directa de consola, cero comandos, recarga y el encadenamiento de EXIT.

`yafp-help` y `yafp-msgs` encuadran sus catálogos estáticos mediante el mismo
renderer. Sus modos internos `plain` en Unix y `-Plain` en PowerShell conservan
los formateadores originales para caracterizar texto, orden y estilos. La ruta
pública captura ese texto coloreado una sola vez y aplica el marco; no consulta
Git, recursos ni servicios. Las pruebas comparan las entradas con los catálogos
anteriores, validan colores de ayuda y comprueban los fondos de los avisos en
modo claro y oscuro, además de bordes y ajuste de línea del renderer compartido.

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
📆 2026-11-02 23:35:53 🍎 MBP02 |
֎ OpenAI 🤖 Codex 🧠 GPT-6 No expuesto & 👨🏻‍💻 Nelbren ©️ 2026
</div>
