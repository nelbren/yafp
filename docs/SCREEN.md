# Terminal screen

[Documentation index](../README.md#guides)

Run `yafp-screen` to view Codex quota and machine resources together. Use
`yafp-screen-codex` or `yafp-screen-resources` for a single group. Press
**Q** or **Esc** to return to the prompt.

## Backgrounds

Run `yafp-screen-themes` to display a framed table of available backgrounds and
modes, one per row. The equivalent command is `yafp-screen themes`.

![Tron light cycles turning across the terminal grid][tron-preview]

[Watch the eight-background tour (MP4, 48 seconds)][background-tour].
Each scene runs for six seconds in the combined view with the same sample
readings. The name in the lower-right corner is the value to use for
`YAFP_SCREEN_BACKGROUND`.

[tron-preview]: images/yafp-screen-tron.gif
[background-tour]: images/yafp-screen-backgrounds.mp4

Choose a background with `YAFP_SCREEN_BACKGROUND` in any screen view.
For a one-time preview in Bash or zsh, run
`YAFP_SCREEN_BACKGROUND=tron yafp-screen`. In PowerShell, set
`$global:YAFP_SCREEN_BACKGROUND = 'tron'` and run `yafp-screen`.

| Value | Animation |
| --- | --- |
| `matrix` | Falling character streams with bright heads and fading trails. |
| `star_wars` | Accelerating stars and short hyperspace streaks. |
| `star_trek` | Corner scanner arcs, a moving scan line and fading contacts. |
| `tron` | Two light cycles with right-angle trails on a perspective grid. |
| `cyberpunk` | Rain over rooftops, lit windows and a flickering neon sign. |
| `terminator` | A red reticle follows a contact, locks on, then loses it. |
| `robocop` | A blue visor scans contacts and flashes a classified directive. |
| `blade_runner` | A spinner lights up rain above a blinking neon eye. |
| `random` | Cycle through Matrix and all seven scenes in shuffled order. |
| `off` | Display the indicators on a plain background (default). |

Press **B** to toggle the active background name in the lower-right corner.
In `random` mode the scene changes every 15 samples (about 15 seconds).
Each screen session shuffles its own playlist.

These scenes share the drawing margins and shine effects with Matrix.
Compact text mode and `NO_COLOR` keep the display static. Select `off` to
disable the background.

Set `YAFP_SCREEN_BACKGROUND=matrix` in Bash or zsh, or
`$global:YAFP_SCREEN_BACKGROUND = 'matrix'` in PowerShell, to show sparse
character streams behind the drawings. Each stream falls at its own
speed, with a bright head and a short darker trail. The rain leaves two
columns on either side of the artwork and one row above and below it.
Use it alone or with any shine mode, including `random`. The background
defaults to `off`. The compact text view and `NO_COLOR` disable the rain.

## Matrix settings

`YAFP_SCREEN_MATRIX_DENSITY` controls the number of streams: choose `low`
(default), `medium`, or `high`. `YAFP_SCREEN_MATRIX_COLOR` sets their hue:
`green` (default), `cyan`, `blue`, `magenta`, `yellow`, or `red`. The head
uses the terminal's bright shade and the trail uses its standard shade.
Unrecognized values fall back to the respective defaults.

`YAFP_SCREEN_MATRIX_SPEED` controls how fast the rain falls. Use `slow` for
half speed, `normal` (default), or `fast` for double speed. The shine and
metric refresh intervals are independent of this setting.

Set `YAFP_SCREEN_MATRIX_TEXT=labels` (PowerShell:
`$global:YAFP_SCREEN_MATRIX_TEXT = 'labels'`) to make words fall in the rain.
The Codex view shows `CODEX`, the resources view cycles through `CPU`,
`MEMORY`, `SWAP`, and `DISK`, and the combined view uses all five. Each
word reads from top to bottom, with its last letter bright. Choose `ai` for
English AI terms such as `TOKENS`, `PROMPT`, `VECTOR`, and `LLM` in every
view. The default
`random` uses the original mix of letters, numbers, and symbols.

## Shine effects

To enable the metallic shine, add `YAFP_SCREEN_SHINE=diagonal` to
`yafp-cfg.bash` or `yafp-cfg.zsh`. In `yafp-cfg.ps1`, use
`$global:YAFP_SCREEN_SHINE = 'diagonal'`. Run `yafp-reload`, then open
`yafp-screen`. Choose a stripe orientation and sweep direction:

- `diagonal-45` slopes upward to the right (`/`).
- `diagonal-135` slopes downward to the right (`\`). The original `diagonal`
  setting is an alias for this mode.
- `vertical-right` and `vertical-left` move a vertical stripe right or left.
- `horizontal-down` and `horizontal-up` move a horizontal stripe down or up.
- `random` picks one of the six stripes for each pass. After the sweep and
  its pause, it picks a different stripe. The separate `point` mode is
  excluded from the draw.

Both diagonal stripes sweep to the right. The angles describe the character
grid: one row per column. The visible angle depends on the font's cell size.
Each stripe pauses between passes. With `point`, a single white block crosses
each row, reversing direction on the next. Each block regains its color
as the highlight passes. The default is `off`. The compact text view and
sessions with `NO_COLOR` stay static.

## Views and terminal requirements

Run `yafp-screen` from Bash, zsh, or PowerShell 7 to view the live Codex quota
above CPU, RAM, SWAP, and disk. Select `yafp-screen-codex` or
`yafp-screen-resources` to show one group. These are shortcuts for
`yafp-screen codex` and `yafp-screen resources`. The renderer uses block-character
art, including a chip, memory grid, opposing swap arrows, disk, and Codex swirl.
The combined and Codex views draw the hourglass in block art or show `` in
compact text mode. Countdown digits use the 5×5 PixelFont from TheGiftOfLife.
Braille levels retain their two-column, four-row dot matrix. Glyph rows stay
horizontally aligned. The Codex-only and combined views center the
drawing on both axes. In larger windows they use separated Braille dots and
a countdown with a dotted zero. The OpenAI Blossom grows with the digits and
uses individual terminal cells to show its crossings. Smaller windows use a
compact swirl. In the combined view, the Codex and resource graphics share
the same visible width. Spacing adjusts between elements at their current size.
The resources view centers all four metrics vertically and uses each metric's
prompt color. When there is room, it draws separate dots for each Braille level.

The screen reuses YAFP's resource and Codex collectors and their configured
intervals. Local countdowns advance once per second. Resize the terminal to
reflow the centered layout; wide windows keep all four resource pairs on one
row, while narrower windows switch to two pairs per row and then a compact
view with shorter labels as needed. Press `q`, `Esc`, or `Ctrl+C` to return.
The previous screen, cursor,
colors, and input mode are restored on exit. Both input and output must be an
interactive terminal. The on-demand renderer requires Python 3 and is not
loaded during normal prompt startup.
