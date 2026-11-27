# Resources and Codex quota

[Documentation index](../README.md#guides)

Use `yafp-resources` for CPU, RAM, swap and disk details. Use `yafp-codex`
for the remaining quota and reset time. Both reports use cached samples.

## Background resource monitoring

YAFP can show CPU, RAM, swap, and used capacity on the volume containing
`HOME`, inside or outside a repository. Monitoring is disabled by default.
To enable it in Bash or zsh, add this to your personal configuration:

```bash
YAFP_RESOURCE_CHECK_INTERVAL=30
```

For PowerShell 7 on Windows, use:

```powershell
$global:YAFP_RESOURCE_CHECK_INTERVAL = 30
```

Then run `yafp-reload`. The interval accepts integers from `1` through `86400`
seconds; `0` disables monitoring. Invalid values also disable it without
printing prompt errors. Existing personal configurations are not modified.

All three themes attach the resource block directly to the hostname:

```text
HOST↦[C24% R74% S50% D93%]
```

The `↦[]` frame uses the same colors as the theme's Git change delimiters.
Each resource keeps its own usage color. Labels and values can be selected
independently in Bash/zsh:

```bash
YAFP_RESOURCE_LABEL_STYLE="unicode"  # letters (default) or unicode
YAFP_RESOURCE_VALUE_STYLE="symbols"  # percent (default) or symbols
```

In PowerShell, write the same options as follows:

```powershell
$global:YAFP_RESOURCE_LABEL_STYLE = 'unicode'
$global:YAFP_RESOURCE_VALUE_STYLE = 'symbols'
```

The four combinations produce the following output for the same sample:

```text
letters + percent: HOST↦[C24% R74% S50% D93%]
unicode + percent: HOST↦[24% ▦74% 50% 93%]
letters + symbols: HOST↦[C⣀ R⣶ S⣦ D⣿]
unicode + symbols: HOST↦[⣀▦⣶⣦⣿]
```

`C`/``, `R`/`▦`, `S`/``, and `D`/`` represent CPU, RAM, swap, and disk,
respectively. CPU appears first, and swap sits between RAM and disk to
highlight their relationship. All four modes and all three themes use this
order. Only Unicode + Braille (`unicode` + `symbols`) removes spaces between
resources. No space separates the hostname from `↦[`, and there is no inner
padding next to the brackets. The other three combinations separate resources
with spaces. Disabled monitoring renders no frame. Invalid styles fall back
to `letters` and `percent`.

Unicode resource labels use Nerd Font glyphs for CPU (`U+F2DB`), swap
(`U+F0EC`), and disk (`U+F0A0`). RAM keeps `▦` (`U+25A6`). Previous label
assignments remain commented in both platform implementations.

Swap usage is relative to its total allocated capacity. Percentages are shown
as integers without decimal places. The `symbols` mode divides usage into
eight levels: 0–12% `⡀`, 13–24% `⣀`, 25–37% `⣄`, 38–49% `⣤`, 50–62% `⣦`,
63–74% `⣶`, 75–87% `⣷`, and 88–100% `⣿`. At 0%, the minimum cell `⡀` is used;
`yafp-resources` retains the used/total details for inspecting exact values.

### Resource thresholds

Each resource uses a foreground color on a transparent background in every
theme:

| Resource       | Green | Yellow | Red  |
| -------------- | ----- | ------ | ---- |
| RAM, CPU, disk | ≤85%  | >85%   | >95% |
| Swap           | ≤10%  | >10%   | >30% |

Red takes precedence over yellow. Thresholds use the actual integer percentage
even in Braille mode; unavailable values appear in red. The prompt omits
sample age to keep the host block compact. `yafp-resources` still reports age:
`17s` means seconds elapsed since sampling, rather than a countdown to the
next update. The gray Font Awesome icon `` (`U+F021`, refresh) inside the
frame indicates a new sample in progress. It attaches directly to the last
value without a space, for example `↦[⣷▦⣦⡀⣿]`.
While the first sample loads, the prompt displays `↦[⟳▦⟳⟳⟳]` in
Unicode + symbols mode, or `↦[C⟳ R⟳ S⟳ D⟳]` with the default styles.
Loading tokens use gray and follow the configured labels and spacing, without
a trailing ``. Missing prompt metrics use a red ``, never an invented zero.
Without a valid sample, all four labels remain:
`↦[▦]` in Unicode + symbols mode or `↦[C R S D]`
with the default styles. A swap total of zero means
no swap/pagefile is allocated: this appears as `S0%` or `0%`, or the
minimum cell in symbolic mode.

### Inspect a resource sample

`yafp-resources` and `yafp-resources-fix` size their gray frames to the longest
visible row. Lines wrap when the terminal is narrower than the report.
Each frame centers its icon and title together in black on a bright white
background. The border and the `├─┤` separator use the normal border color.
`yafp-resources` shows the sample state, its age in seconds, and all four
resources, with numeric percentages even when the prompt uses Braille:

```text
┌─────────────────────────────────────────┐
│             yafp-resources             │
├─────────────────────────────────────────┤
│         State:  refreshing            │
│    Sample age: 30s                     │
│           CPU: 25%                     │
│           RAM: 75% · 12.03/16 GiB      │
│          SWAP: 47% · 1.41/3 GiB        │
│   Disk (HOME): 80% · 741.11/926.35 GiB │
└─────────────────────────────────────────┘
```

CPU, RAM, SWAP, and disk retain the prompt's colors and thresholds. Used/total
pairs share one binary unit based on the larger known value. RAM and SWAP
start at MiB and the `HOME` volume starts at KiB. The report scales up to TiB
and shows up to two decimals. A positive value that rounds to zero appears as
`<0.01`. Missing values appear as ``, and unallocated swap shows
`0% · 0/0 MiB`.

` State` describes sample availability: ` ok`, gray ` refreshing` if a
previous sample remains available, ` pending` while waiting for the first,
` unavailable` if there is no valid sample, and ` disabled`.
` Sample age` measures the time since sampling; it uses `` if no valid
sample exists. When monitoring is disabled, the command retains the
configuration hint below the frame. The report does not wait for the worker
or reuse old details after an invalid cache read.
On Linux, macOS, and Windows PowerShell, `yafp-resources` shows up to three
processes below CPU ranked by processor use and up to three below SWAP ranked
by physical RAM use whenever the sample includes process data.
They are ordered from highest to lowest and use the tree branches `├──` and
`└──`, aligned with the percentage above each group. CPU usage is shown as a
percentage, and each process's RAM usage scales from MiB up to TiB. The
background worker gathers process data.
All three systems measure the change in each process's CPU time over a window
of about 200 ms. A process using multiple logical CPUs can exceed 100%.
Tree branches are gray, names use the normal text color, and values match the
color of their CPU or SWAP row (gray if its percentage is unavailable).
Use `yafp-resources-fix` to add a red `` skull and the termination command for
each process. Unix shows `sudo kill -9` with the PID, and PowerShell shows an
elevated `Stop-Process` command. Both reports only display information.
A worker starts during prompt rendering when the interval expires; a later
prompt reads its result. There is no persistent timer, and the line is not
redrawn while you type. The sample age identifies older data when a probe is
slow or fails. Each session has at most one resource worker; two terminals
keep independent samples. Reloading does not duplicate workers. In zsh, the
worker launches disowned with `&!`, so starting or finishing it does not emit
job notifications such as `[3] + done`.
If a session's temporary resource directory disappears, the next scheduled
refresh creates a new private directory and resumes sampling automatically.
An already running worker finishes before a replacement is started.

### Simulate resource load

To compare colors with simulated percentages, run `yafp-demo-resources`.
The command demonstrates CPU by default. It also accepts `MEMORY`, `SWAP`,
`DISK`, and `ALL`.

```text
yafp-demo-resources ALL
```

The view uses one compact frame with the centered title ` yafp-demo-resources`.
It shows three rows per resource with the system icon in white, yellow, and
red. `ALL` groups all twelve rows in CPU, MEMORY, SWAP, and DISK order.
A blank line separates the groups.
The icon and resource block start in the same column on each row.
The view uses the session's configured resource format and does not change
the actual sample. It works in Bash, zsh, and PowerShell, even when monitoring
is disabled.

macOS uses `sysctl`, `vm_stat`, two `top` samples one second apart, and `df`.
RAM is an estimate of occupied physical memory that excludes free, inactive,
and speculative pages; it can differ from Activity Monitor. Linux/WSL2 uses
`MemTotal - MemAvailable`, swap from `/proc/meminfo`, and two `/proc/stat`
samples 200 ms apart. Windows uses CIM/WMI and allocated pagefiles from a
PowerShell 7 thread job. In Git Bash, metrics without a native probe appear
as ``; disk usage still uses `df`. Disk reports capacity, without measuring
I/O latency or saturation.

All probes run in the background with isolated input and output. Rendering
reads numeric data using shell builtins without running probes or querying
the network. Unix publishes samples atomically in a private session temporary
directory and removes it on normal exit. PowerShell keeps results in memory
and removes completed jobs. No repository files or metric histories are created.

On macOS, swap usage alone does not establish the cause of a slowdown. To
investigate memory pressure, Activity Monitor also considers the swap rate,
wired memory, and file cache:
[Apple memory guide](https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac).

Prompt, diagnostic, and test messages are in English. Missing values use a
red `` in resource and Codex indicators. The `yafp-resources` and `yafp-codex`
frames use a gray `` for unavailable data.

## Background Codex quota

YAFP can display the remaining Codex quota for the ChatGPT account signed in
to the local Codex CLI (`codex`). This measures account quota, rather than
service uptime or the message allowance in the ChatGPT website. It uses the
official [Codex app-server account interface](https://learn.chatgpt.com/docs/app-server).
The feature is disabled by default and works independently of Git and machine
resource monitoring.

Add a configuration block to your personal Bash/zsh configuration:

```bash
# --- Codex account quota ---
YAFP_CODEX_CHECK_INTERVAL=300
YAFP_CODEX_VALUE_STYLE="symbols"  # percent (default) or symbols
# Optional: YAFP_CODEX_PERCENT_AT_OR_BELOW=24
```

For PowerShell 7 on Windows:

```powershell
# --- Codex account quota ---
$global:YAFP_CODEX_CHECK_INTERVAL = 300
$global:YAFP_CODEX_VALUE_STYLE = 'symbols'
# Optional: $global:YAFP_CODEX_PERCENT_AT_OR_BELOW = 24
```

Run `yafp-reload`. The interval accepts `1` through `86400` seconds; `0` or
an invalid interval disables checks and removes the indicator. Five minutes
is suggested to avoid frequent CLI startup. All three themes attach the block
directly to the username, preserving the host resource block:

```text
percent: USER↤[֍75% 5d9h] @ HOST↦[24% ▦74% 50% 93%]
symbols: USER↤[֍⣷5d9h] @ HOST↦[⣀▦⣶⣦⣿]
```

The `↤[]` frame uses the Git change delimiter colors. The quota token uses a
transparent background and inclusive availability thresholds:

| Green | Yellow   | Red  |
| ----- | -------- | ---- |
| ≥50%  | 25–49%   | <25% |

Braille uses the same eight levels as resources, with fuller cells meaning
more quota available. Colors use the remaining integer percentage, even in
symbolic mode. `YAFP_CODEX_VALUE_STYLE` accepts `percent` or `symbols`;
invalid styles fall back to `percent`.

### Quota display and reset time

When using `symbols`, set `YAFP_CODEX_PERCENT_AT_OR_BELOW=24` (or
`$global:YAFP_CODEX_PERCENT_AT_OR_BELOW = 24` in PowerShell) to show the
numeric percentage at 24% remaining or below. From 25% up, the prompt and
`yafp-screen` show Braille again. At this threshold the switch coincides with
the red quota indicator. The option is unset by default and accepts whole
numbers from 0 to 100 without leading zeros. An invalid value keeps Braille,
and the option has no effect in `percent` mode.

On its first check, the background worker locates `codex` and reads its account
state. Only ChatGPT authentication enables the quota request. Each refresh
checks authentication again, allowing a later login to recover automatically.
YAFP never opens a login flow or starts a conversation. To sign in yourself,
run `codex login`, then wait for the next check. Unix requires Python 3 only
when this optional integration is enabled; Windows uses native PowerShell.

The value is `100 - usedPercent`, rounded down, for the `codex` bucket. When
both primary and secondary windows are available, the smaller remaining
percentage wins. Other model buckets are ignored. The legacy single-bucket
response is supported. Missing windows are ignored; if neither is available,
the token is `֍dh` in red. A missing CLI, missing Python, logged-out or API-key
session, request error, or timeout also produces `֍dh`, never a false 0%.

The hourglass `` introduces the time until the selected window
resets, as in `֍75% 5d9h` or `֍⣷5d9h`. Ties in remaining percentage select
the primary window. The compact countdown uses days/hours (`5d9h`),
hours/minutes (`9h30m`), minutes/seconds (`12m15s`), or seconds (`40s`), with
whole units rounded down. It uses the window's `resetsAt` timestamp and is
updated from cached data at every prompt, without an extra process or request.
An elapsed deadline displays `0s` until another quota sample arrives. A missing
or invalid reset timestamp omits the countdown while preserving the quota.

Requests have a ten-second deadline in the worker. Rendering reads the cached
result without waiting or accessing the network. The initial prompt can show
`֍⟳d⟳h` in gray until the first result is collected at a later prompt. The
`d`/`h` structure anticipates the reset countdown without inventing a duration.
When no data is available, `֍dh` preserves the days/hours structure without
inventing a quota or deadline. Once available, the real countdown uses
the units appropriate to its duration.
Each session keeps at most one quota worker, and reloads reuse it. In zsh, the
worker is disowned
at launch to suppress job notifications. There is no persistent polling timer
or redraw while typing. The last sample remains visible during a refresh;
a failed refresh replaces it with `֍dh`.

The prompt shows a green `` when Git is up to date and a gray `⟳` while
waiting for the first check. When announcing a connection, YAFP brings forward
the next Codex check if enabled. If a Codex query is already running, the
requested check starts after it finishes.
On Unix, a missing temporary quota directory is recreated on the next
scheduled refresh, after any active worker finishes.

### Inspect a quota sample

`yafp-codex` fits its frame to the longest visible line without waiting for a
pending refresh to finish. Lines wrap inside the frame in narrow terminals:

```text
┌──────────────────────┐
│     ֍ yafp-codex     │
├──────────────────────┤
│         Reset: 1d8h │
│         State:  ok │
│     Remaining: 74%  │
└──────────────────────┘
```

`Reset` shows the days and hours remaining until the limiting quota window
resets. `Remaining` always uses a numeric percentage and matches the prompt's
aggregate value, even when the prompt uses Braille. The smaller available
percentage from the primary and secondary windows is selected. `` indicates
that no valid value is available; an elapsed deadline appears as `0d0h`.

` State` distinguishes the query state from the quota amount: ` ok`,
` pending`, ` disabled`, ` logged-out`, ` unsupported-auth`, ` missing-cli`
or ` missing-python`, ` timeout`, and ` unavailable`. The percentage retains
the prompt's green/yellow/red thresholds. When monitoring is disabled, the
hint for enabling it is also retained. Per-window details and sample age are
no longer printed in this summary.

### Debug the quota collector

To inspect the background process, run this in the same terminal:

```bash
yafp-codex --debug
```

This works in Bash, zsh, and PowerShell 7; PowerShell also accepts `-Diagnostics`.
It adds these fields to the frame:

```text
        Worker: idle
    Server PID: 12345 (last started)
         Stage: account/rateLimits/read
        Reason: rpc-error
      Duration: 340ms
```

`Worker` shows `running` with the Unix worker PID or PowerShell job ID, `idle`
when no query is active, and `disabled` when monitoring is disabled.
`Server PID` identifies the last server started for that attempt; it does not
imply that the server is still alive. `Stage` identifies the last stage:
dependency lookup, server startup, `initialize`, `account/read`,
`account/rateLimits/read`, or limit parsing (`parse-limits`).
`Duration` measures the entire attempt in milliseconds, including server
cleanup; while active, it shows an estimate with `~` and `(running)`.

`Reason` distinguishes `in-progress`, `ok`, missing dependencies or
authentication, `timeout`, `server-start-failed`, `server-closed`, `rpc-error`,
`invalid-response`, `no-valid-limits`, and `io-error`. PowerShell can also
report `worker-start-failed` and `cleanup-failed`. `worker-ended` indicates
that the worker ended without publishing a final diagnostic. `no-diagnostics`
means that information for the current attempt is not yet available, is invalid,
or comes from a collector predating this version; wait for the next query.
Reloading YAFP preserves the session's attempt and sample.

The diagnostic reads available progress without waiting or forcing an
additional query. It retains the usual interval and a single worker; run the
command again to see progress. The normal frame may retain the previous sample
while the diagnostic fields describe the new attempt. It is not a continuous
event log and does not display original server messages.

Only percentages, deadlines, states, and diagnostics with fixed stages and
reasons, duration, and process identifiers are stored. YAFP never stores or
prints account identifiers, credentials, or server responses.
