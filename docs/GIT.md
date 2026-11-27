# Git status and remote checks

[Documentation index](../README.md#guides)

## Git repository identity

In the Bash `default` theme, only the repository name uses the same yellow
highlight as its directory representation in PowerShell. The surrounding Git
symbols and metadata keep the Git block color.

The Git icon sits directly before the branch name in all three themes. ``
indicates a repository with a configured remote. It appears green when the
last check succeeded, yellow while no result is available, and red when the
check fails. A yellow `` identifies a repository without a remote.

## Changed files

Run `yafp-git` inside a repository in Bash, zsh, or PowerShell to list the
paths behind the Git counters in a box:

```text
┌─────────────┐
│  yafp-git  │
├─────────────┤
│  old.txt   │
│  README.md │
│  notes.txt │
│  ready.txt │
└─────────────┘
```

Each path uses the color of its status icon. The `` icon marks staged
changes. A file changed again after staging has a row for each state.
The report also flags unresolved conflicts with ``.
Paths are relative to the repository root. Git may show an untracked
directory as a single entry, just as it does for the prompt counter.

## Remote repository checks

YAFP can periodically refresh the configured upstream without blocking the
prompt. Configure the cache lifetime in seconds before loading the prompt:

| Value             | Behavior                                      |
| ----------------- | --------------------------------------------- |
| `0`               | Disables remote checks completely             |
| Positive integer  | Enables checks using that interval in seconds |
| Not configured    | Defaults to 300 seconds                       |

For Bash, set the value in `yafp-cfg.bash`:

```bash
YAFP_REMOTE_CHECK_INTERVAL=300
```

For PowerShell, set the value in `yafp-cfg.ps1`:

```powershell
$global:YAFP_REMOTE_CHECK_INTERVAL = 300
```

Choose how the remaining interval is displayed with
`YAFP_REMOTE_COUNTDOWN_STYLE`. The default `numeric` value shows the exact
seconds as `(N)`. The `symbols` value shows one Braille cell that progressively
empties as the next check approaches:

```bash
YAFP_REMOTE_COUNTDOWN_STYLE="symbols"
```

```powershell
$global:YAFP_REMOTE_COUNTDOWN_STYLE = 'symbols'
```

The symbolic sequence is `⣿`, `⣷`, `⣶`, `⣦`, `⣤`, `⣄`, `⣀`, and `⡀`.
Each shape progresses through intense white, normal white, and dark gray before
repeating the cycle. The shape follows the remaining time, while the color
advances once whenever a new prompt is rendered. It does not update while the
prompt is idle. At zero, the countdown cell disappears and the existing ``
refresh indicator communicates that the background check is running. The color
cycle uses only an integer increment and selection during rendering; it does not
start another timer or process.

When the cached result expires, YAFP starts a non-interactive `git fetch` in
the background. A later prompt render reads the result. Repositories without
an upstream do not produce a false outdated warning. If a branch has a
configured remote but no upstream reference, all themes show the yellow `⇡?`
indicator with `(  NO UPSTREAM: configure tracking before pushing )`.
On narrower terminals the banner becomes `(  NO UPSTREAM )`; if neither
banner fits, the compact indicator remains visible. `yafp-status` reports
`⇡? No upstream`. This local warning does not fetch, start a worker, show a
countdown, or claim a count of unpublished commits. Local-only repositories
with commits and detached HEAD do not show it. Setting
`YAFP_REMOTE_CHECK_INTERVAL=0` also disables this warning.

After `git init`, a repository without commits shows the yellow `○0`
indicator and `(  NO COMMITS: create the initial commit )`, or the compact
`(  NO COMMITS )` banner when space is limited. This warning takes precedence
over missing upstream tracking, works without a remote, and remains visible
while files are staged. The first commit clears it; a configured remote may
then trigger the no-upstream warning. Both warnings respect
`YAFP_REMOTE_CHECK_INTERVAL=0` and never start background jobs.
Bash and zsh detect `git init` in the current directory even if an earlier
prompt cached it as a non-repository; changing directories is unnecessary.

To publish a new branch and configure tracking, run `git push -u origin main`
with your intended remote and branch. If the branch is already published,
run `git fetch origin` and `git branch --set-upstream-to=origin/main main`
instead. YAFP only displays the warning; it does not run these commands.
The warning disappears once a valid upstream reference is available.

Bash records the worker PID in its refresh lock; if the worker exits without
cleaning up, the next prompt render removes the abandoned lock and retries the
refresh.

The first prompt rendered inside a repository after YAFP loads always requests
an immediate background refresh, even when a previous cache is still fresh.
Starting outside a repository preserves that initial check until the first
repository prompt. Rendering remains non-blocking.

### Remote status indicators

The refresh countdown and compact indicator appear immediately to the right
of the branch symbol and to the left of the branch name:

| Indicator | Color                  | State and meaning                      |
| --------- | ---------------------- | -------------------------------------- |
| `(N)`     | Dark gray              | Numeric countdown until next check     |
| `⣿…⡀`     | Dark gray              | Symbolic countdown until next check    |
| ``       | Intense green          | Current: matches upstream              |
| `⇡N`      | Black / intense yellow | Ahead: `N` commits ready to push       |
| `…`       | Black / intense yellow | Checking: first check is running       |
| ``       | Black / intense yellow | Refreshing cached state                |
| `⇣N`      | White / red            | Behind: `N` commits need integration   |
| `⇡N⇣M`    | White / red            | Diverged: unique commits on both sides |
| ``       | White / red            | Remote check failed                    |

The `` indicator can precede the last known state while YAFP refreshes it,
for example `` or `⇣2`. Warning expansions and compact indicators use black
text on an intense yellow background. Error expansions and behind/diverged
indicators use intense white text on a red background. The compact connectivity
icon `` (`U+F1EB`) uses intense green on a transparent background. The
compact failure icon `` (`U+F072`) shares the white text and red background
of the active remote error banner. Acknowledged
errors use intense red on a transparent background. Their previous glyphs
remain commented in the code.
`YAFP_DARKC` selects the dark or bright
red background variant without changing that severity contract. When the
remote check fails, YAFP displays
`(  REMOTE CHECK FAILED )` centered above the compact `` indicator. The
same expansion layout applies to ahead, behind, and diverged messages. All
expansions, including staged-change messages, use `( MESSAGE )`, with one
space after `(` and before `)`.
The delimiters are ordinary ASCII parentheses so terminal fonts display the
inner spaces consistently.
No colored padding precedes the opening delimiter. For example, the ahead
banner starts with `(  REMOTE NOT UPDATED:`. Run `yafp-reload` in an existing
shell to apply the current banner formatting after updating YAFP.
Centering and terminal-edge checks include
both delimiters and the two inner spaces. The layout uses
the indicator's actual cursor position, so changes to the user, host, path,
repository, or branch do not require estimating their display width. These
expansions are cleared immediately when the prompt leaves the repository.
Long remote messages are used only when the complete centered banner fits
between the terminal edges at the compact indicator's current column. Narrow
or crowded prompts automatically use ` PUSH PENDING: N`,
` PULL PENDING: N`, or
` DIVERGED: ⇡N ⇣M`; all variants retain the centered `( … )` presentation.
When the indicator approaches the right edge, YAFP shifts the banner left
to fit its row. It also calculates how many rows to move up if the prompt
prefix has wrapped across multiple lines.

After the first fresh successful check, or after connectivity recovers from an
offline state, YAFP displays
`(  INTERNET CONNECTION )` with intense white text on a normal green
background above the compact remote indicator.
Green banners use exact RGB `#008000` with white `#FFFFFF` text; yellow
banners use `#FFFF00` with black text in Bash and PowerShell. These banners
use ANSI true color so a customized terminal palette cannot change their tones.
The compact `` shares the banner’s white text and green background on that
prompt. On later prompts it uses intense green on a transparent background.
The connection
expansion appears once per offline-to-online transition; reloading YAFP does
not duplicate the current state. If the recovered result is ahead, behind, or
diverged, the connection expansion takes precedence for one prompt and the
repository-state expansion returns on the next prompt.

The offline compact indicator is ``.

The cache tracks both the local commit and the upstream tracking commit. A
successful push therefore invalidates an outdated `Ahead` result immediately,
and `` remains visible across prompt renders until the background refresh has
finished.

The detailed `yafp-status` report uses the same severity colors: current is
intense green; ahead, checking, and refreshing are intense yellow; and behind,
diverged, and remote-check errors are intense red.

For example, `[(250)⇡1]↤master` means that the local branch is one commit
ahead and the next remote check will run in 250 seconds. When the countdown
reaches zero, the display can temporarily become `[(0)⇡1]↤master` while the
background refresh completes.

A successful `git push`, `git fetch`, or `git pull` bypasses the remaining
countdown and requests an immediate background refresh. The prompt temporarily
shows `` immediately before the last known state, as in `[(0)]↤` with a
numeric countdown; after the worker completes, the next
prompt displays the new state and restarts the configured countdown. Failed
commands and incidental text such as `echo "git push"` do not reset it. This
behavior is also disabled when `YAFP_REMOTE_CHECK_INTERVAL` is `0`.

### Staged changes

YAFP distinguishes every step between editing and publishing repository work:

| Indicator | Meaning                                      |
| --------- | -------------------------------------------- |
| `+N`     | `N` untracked files                          |
| `±N`     | `N` unstaged modifications                   |
| `-N`     | `N` unstaged deletions                       |
| `N`      | `N` staged files are ready to commit         |
| `⇡N`      | `N` committed changes are ready to push      |

When the index contains staged additions, modifications, deletions, renames,
copies, or type changes, all themes display the `N` indicator and this
expansion centered above it with matching singular or plural grammar. Both use
black text on an intense yellow background:

```text
(  COMMIT PENDING: 14 staged files are ready to commit )
```

The expansion uses the indicator's actual cursor position and keeps a separate
row when a remote-status expansion is visible at the same time. If the long
message cannot remain centered above `N` without crossing a terminal edge,
it becomes `(  COMMIT PENDING: N )`.
Bash excludes both Readline-wrapped and raw terminal color sequences when
measuring that position, so colored separators cannot make an overflowing
detailed banner appear to fit.
ANSI recognition and removal in Bash and zsh use locale-independent byte
matching, while visible text keeps Unicode width measurement. This also applies
with macOS UTF-8 locales.
If even the short banner would cross the right edge, YAFP omits the expansion
and keeps the `N` indicator. The same fit check applies to remote banners;
their compact status indicators remain visible.

### On-demand remote controls

Use `yafp-status` in Bash, zsh, or PowerShell to inspect the exact timer
independently of the configured countdown style:

```text
┌────────────────────────────────────────────────────────────────────┐
│                            yafp-status                            │
├────────────────────────────────────────────────────────────────────┤
│        Remote:  Up to date                                       │
│         Timer: ████░░░░░░ 42% · 125/300s elapsed · 175s remaining │
│  Current time: 14:32:25                                           │
│    Next check: 14:35:20                                           │
└────────────────────────────────────────────────────────────────────┘
```

`yafp-status` fits its gray frame to the longest visible line, including when
the repository, upstream, or Git is unavailable. Narrow terminals wrap the
state, timer bar, and timestamps inside the frame.
`yafp-demo` shows that frame before the separate preview frame.

The remote state text is intense green when up to date and intense red when
a remote check fails. The timer bar and metrics use green with `` when at
least 66% of the interval remains, yellow with `` when at least 33% remains,
and red with ``
below 33%. The current time uses intense white, and the next-check time uses
intense yellow.

Choose the progress-bar presentation independently of the prompt countdown:

```bash
YAFP_STATUS_PROGRESS_STYLE="symbols"
```

```powershell
$global:YAFP_STATUS_PROGRESS_STYLE = 'symbols'
```

The default `blocks` style uses filled and shaded blocks. The `symbols` style
uses Braille cells for elapsed progress and spaces for the remaining area:

```text
        Timer: ⣿⣿⣿⣿⣀      42% · 125/300s elapsed · 175s remaining
```

Use `yafp-refresh` to set the countdown to zero and request an immediate
background refresh. The compact ` yafp-refresh` frame reports whether the
request was made or a refresh is unavailable. The prompt displays `` next
to the last known state until the worker finishes.

YAFP checks the configured Git remote, not general internet connectivity.
Authentication, permissions, an invalid remote, DNS, or a restricted execution
environment can all make `git fetch` fail while other internet access works.
The ` REMOTE CHECK FAILED` banner reflects that uncertainty, including for
previously cached errors. To see Git's diagnostic, run `git fetch` in your
terminal; after resolving the cause, run `yafp-refresh` and render another
prompt once the background check finishes. A successful check replaces the
error even before its cache interval expires. Checks from restricted shells
can write failures into the same repository cache used by your terminal.

After a remote check fails, use `yafp-ack` to acknowledge the current alert. The
`(  REMOTE CHECK FAILED )` expansion then stays hidden while the compact
`` remains intense red on a transparent background. A successful
remote check resets the acknowledgement, so a later remote-check failure displays
the expansion again. The compact ` yafp-ack` frame reports whether an alert
was acknowledged or there was no alert to acknowledge.
