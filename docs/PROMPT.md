# Prompt themes and commands

[Documentation index](../README.md#guides)

See the [visual comparison](../README.md#gallery) for the three themes.

## Icons and colors

OS indicators use Nerd Font glyphs: `` (`U+F179`) for macOS, ``
(`U+F17A`) for Windows, and `` (`U+F17C`) for Linux. Server detection
preserves Debian `` and Kali `㉿`
using the exact `ID` in `/etc/os-release`. Other distributions, including
Ubuntu, and missing or unknown IDs use the Tux symbol ``.
Unix server and client indicators use these glyphs;
WSL, Cygwin, and Git Bash client indicators retain their environment markers.
PowerShell uses the Windows glyph where its themes show an OS indicator.
In `minimal` and `light`, the leading icon reflects CPU, RAM, swap, and disk
status. It appears red if any resource is red, yellow if there is a warning,
and white otherwise. Red takes precedence. The icon stays white while waiting
for the first sample or when monitoring is disabled.

Repository markers use `` (`U+F1D3`) and `` (`U+F1D2`) in all shells and
themes. The marker sits directly before the branch name.
Directory markers use the open-folder glyph `` (`U+F07C`) instead of `⌂`.
The current timestamp uses the clock glyph `` (`U+F017`) in all three themes.
Previous glyph assignments remain commented beside the active code. The
terminal must use a Nerd Font containing these private-use glyphs; SSH clients
render them using the font installed locally, independently of the remote OS.

Status, Git counter, Python, user/host, and diagnostic icons use Font Awesome
through Nerd Fonts. The glyph catalog and code points are listed in
[FONTS.md](FONTS.md#prompt-icons). Exit codes, thresholds, and meanings
remain unchanged. All themes use `` and `` for success and error.
Files, commands, and other user text are displayed without replacing their
emoji.

Color also reflects the server role (development or production) and user
privileges (`#` for root, `$` for a regular user).

## :window: PowerShell themes

PowerShell now supports the `default`, `minimal`, and `light` themes. Select
one in `yafp-cfg.ps1` before loading `yafp-ps.ps1`:

```powershell
$global:YAFP_THEME = 'minimal'
```

If the selected theme does not exist, YAFP falls back to the `default` theme.

Set `YAFP_DARKC` to `1` to use darker background variants in the Bash and
PowerShell `default` and `minimal` themes. Set it to `0` for brighter
backgrounds:

```bash
YAFP_DARKC=1
```

```powershell
$global:YAFP_DARKC = 1
```

The option does not affect `light`, which renders without colored backgrounds,
including the separator spaces between prompt segments.

The previous-command error symbol and exit code use intense red text on a
transparent background in every theme. This command-status style is independent
from error banners, which retain their contrasting foreground and background.

## Indicator blocks

Codex quota, machine resources, Git remote status, and Git change counters
use bracketed frames in every shell and theme.

```text
USER↤[֍⣷5d9h]
HOST↦[⣀▦⣶⣦⣿]
[⡀]↤master↦[21]
master↦[21]
```

`↤` associates the username with its Codex quota and the remote frame with
its branch. `↦` connects the hostname and branch to resources and changes.
The arrows and brackets use the theme's Git delimiter colors. Each inner
indicator retains its own severity color.
The Codex hourglass follows a Braille cell directly or a percentage with a space.
Resources use their configured separators. The Git remote countdown and status
are adjacent inside one frame: symbolic `[⣦]↤` or numeric `[(175)]↤`. Refresh,
tracking, warning, and error states use the same frame. Empty remote and
counter blocks produce no frame. The `light` theme retains its clean-worktree
check mark, while the other themes retain their existing clean-state behavior.
All themes display changes as `↦[123]`. The ``, ``, and `` icons
identify deleted, modified, and new files with red, yellow, and cyan text on a
transparent background. Each count sits directly beside its icon.
The remote frame precedes the Git icon and branch with no spaces between them.
A repository without a remote omits the frame.

`` marks a background refresh in Git and machine resources. `⟳` is a
placeholder for the first pending values in machine resources and Codex quota.
Resource refresh icons and initial placeholders are gray; Git refresh icons
retain their existing warning colors.

Remote and staged banners remain aligned with their corresponding indicators,
including when other counters appear before the staged count.

For the paths behind each counter, see the [Git guide](GIT.md#changed-files).

## Clock display

Set `YAFP_CLOCK` to `1` to display prompt timestamps or to `0` to hide them.
The option applies to every Bash and PowerShell theme.

For Bash, set the value in `yafp-cfg.bash`:

```bash
YAFP_CLOCK=1
```

For PowerShell, set the value in `yafp-cfg.ps1`:

```powershell
$global:YAFP_CLOCK = 1
```

## Help and banners

Use `yafp-help` to list the main YAFP commands with a short description:

```text
┌──────────────────────────────────────────────────────────────────────┐
│                              yafp-help                              │
├──────────────────────────────────────────────────────────────────────┤
│ yafp-status • Show remote status and refresh timer.                  │
│ yafp-git • List files behind the Git counters.                       │
│ yafp-refresh • Request an immediate remote refresh.                  │
│ yafp-ack • Acknowledge the current remote error alert.               │
│ yafp-reload • Reload YAFP in the current shell.                      │
│ yafp-stats • Show command execution statistics.                      │
│ yafp-msgs • Show all prompt banners in severity order.               │
│ yafp-help • Show available YAFP commands.                            │
│ yafp-codex • Show cached Codex quota and authentication status.      │
│ yafp-resources • Show the latest RAM, swap, CPU, and disk sample.    │
│ yafp-screen • Show live Codex quota and machine resources.           │
│ yafp-screen-codex • Show only the live Codex quota screen.           │
│ yafp-screen-resources • Show only the live machine resources screen. │
│ yafp-screen-themes • List available screen background themes.        │
│ yafp-resources-fix • Show process termination commands.              │
│ yafp-demo-resources • Simulate resource load and colors.             │
└──────────────────────────────────────────────────────────────────────┘
```

`yafp-help` and `yafp-msgs` fit their gray frames to the longest visible line
in Bash, zsh, and PowerShell. Help retains yellow names, neutral
separators, and white descriptions. The catalog preserves success, warning,
and error order, parentheses, and each banner's background colors, including
light/dark variants. Long lines wrap inside the frame; margins and borders
reset to their own color.

Use `yafp-msgs` in Bash, zsh, or PowerShell to preview all prompt banners, including
their detailed and compact variants. It prints green banners first, then
yellow warnings, and finally red errors, using the prompt's severity colors
and `( MESSAGE )` spacing. The examples use one commit or staged file and
`origin/main`; they do not query Git or change the remote cache, timer, or
alert acknowledgement. Run `yafp-reload` to make the command available in an
already open shell after updating YAFP.
Every banner begins with `` for success, `` for warnings, or `` for errors
inside its opening parenthesis, for example `(  PUSH PENDING: 1 )`.
One space separates the severity symbol from the message text.

## Session statistics

`yafp-stats` counts completed commands in the current shell session. Empty
input and internal prompt renders are excluded, and `yafp-reload` preserves the
counters. A zero exit status counts as succeeded; every nonzero status,
including an interrupted command, counts as failed:

```text
┌────────────────────────┐
│      ∑ yafp-stats      │
├────────────────────────┤
│  Succeeded: 38 (090%) │
│  Failed:     4 (010%) │
│ ━━━━━━━━━━━━━━━━━━━━━━ │
│ ∑ Total:     42 (100%) │
└────────────────────────┘
```

`yafp-stats` and the automatic exit report fit the gray frame to the longest
visible line. In a narrow terminal, lines wrap inside the frame.

The names use intense green, intense red, and intense white respectively; the
separator uses normal white. YAFP prints the same report during a normal shell
exit, including `exit` and end-of-input. Disable only the automatic exit report
with:

```bash
YAFP_STATS_ON_EXIT=0
```

```powershell
$global:YAFP_STATS_ON_EXIT = 0
```

Statistics remain in memory and are discarded when the shell process ends.
Forced termination cannot run the exit report.

## Preview the current prompt

Use `yafp-demo` to print a fresh `yafp-status` report and a live preview of the
configured prompt every four seconds until you stop it with `Ctrl+C`. Each
iteration renders the current theme and local context under the boxed title
` yafp-demo · Prompt preview`,
then displays `Control+C to break this  loop  (4s)` as a reminder. The
preview omits OSC 133 lifecycle markers because it does not begin an interactive
command block. In Bash, the preview expands PS1 display escapes before printing,
so ANSI colors and the user or root prompt mark render as they do in the active
prompt instead of appearing as literal backslash sequences.

The `yafp-demo` preview sits inside a Unicode `┌─┐│└─┘` frame, including
prompt lines and the `$` or `#` mark. It preserves colors and wraps long lines
across interior rows. The frame fits the longest visible row and leaves at
least one free column on the right to prevent automatic border wrapping.
Git banners and erase controls are resolved inside the frame; cursor movements
that could alter its borders are not emitted. Terminals narrower than seven
columns use the unframed preview. The interactive prompt, key bindings, and
loop pause remain unchanged.
