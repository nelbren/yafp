#!/usr/bin/env python3
"""Render block-character art for yafp-screen."""
import argparse
import os
import shutil
import sys

# Digits, period, colon, question mark and O from TheGiftOfLife/PixelFont_5x5.iml.
# Countdown units and status glyphs follow the same five-row grid.
GLYPHS = {
    "0": "##### #...# #...# #...# #####",
    "1": "...## ....# ....# ....# ....#",
    "2": ".###. #...# ...#. ..#.. #####",
    "3": "##### ....# .#### ....# #####",
    "4": "#...# #...# ##### ....# ....#",
    "5": "##### #.... ##### ....# #####",
    "6": "##### #.... ##### #...# #####",
    "7": "##### ....# ...#. ..#.. .#...",
    "8": "##### #...# .###. #...# #####",
    "9": "##### #...# ##### ....# #####",
    ".": "..... ..... ..... ..... ..#..",
    ":": "..... ..#.. ..... ..#.. .....",
    "?": ".###. #...# ..##. ..... ..#..",
    "O": ".###. #...# #...# #...# .###.",
    "F": "##### #.... ####. #.... #....",
    "!": "..#.. ..#.. ..#.. ..... ..#..",
    "⟳": ".###. #.... #..## #...# .###.",
    "d": "....# ....# .#### #...# .####",
    "h": "#.... #.... ####. #...# #...#",
    "%": "##..# ##.#. ..#.. .#.## #..##",
    "s": "..... .#### .###. ....# ####.",
    "m": "..... ..... ##.#. #.#.# #...#",
    " ": "..... ..... ..... ..... .....",
}
ICONS = {
    "CPU": "..#.#.. .#####. ##...## .#####. ..#.#..",
    "RAM": "####### #.#.#.# ####### #.#.#.# #######",
    "SWAP": "....#.. ######. ..#.#.. .###### ..#....",
    "DISK": ".#####. #.....# #.....# ####### #.#...#",
    "Codex": "..###.. .#...#. #..#### #..#... .##....",
}
RESOURCE_ICONS = {
    "CPU": "..#.#.#.. ..#.#.#.. .#######. ###...### .##.#.##. ###...### .#######. ..#.#.#.. ..#.#.#..",
    "RAM": "######### #.#.#.#.# ######### #.#.#.#.# ######### #.#.#.#.# ######### #.#.#.#.# #########",
    "SWAP": "......... ......##. ######### ......##. ......... .##...... ######### .##...... .........",
    "DISK": ".#######. ##.....## #.......# #.......# ######### #.......# #...#.#.# #.......# .#######.",
}
# The 7×7 swirl leaves a gap between each of its four curved arms.
CODEX_SWIRL = ".##..#. #.##..# ...#.## .#####. ##.#... #..##.# .#..##."
# Cell masks sampled from the OpenAI Blossom in Simple Icons 11.15.0.
# Each cell is one █, with twice as many columns as rows for terminal proportions.
# https://github.com/simple-icons/simple-icons/blob/11.15.0/icons/openai.svg
CODEX_LOGO_MASKS = (
    (
        "................###########..................... "
        ".............#################.................. "
        "............####..........#############......... "
        "..........####..........#################....... "
        ".......######.......#######............####..... "
        "....#########....#######................####.... "
        "...####..####....###........#######......####... "
        ".####....####....##......#####.#######....###... "
        ".###.....####....##..######........##########... "
        "####.....####....######..#####........#######... "
        "####.....####....##..........#####.......#####.. "
        ".###.....####....##..........########......####. "
        ".####......########..........##....####.....###. "
        "..#####.......#####..........##....####.....#### "
        "...#######........#####..######....####.....#### "
        "...##########........######..##....####.....###. "
        "...###....#######..#####.....##....####....####. "
        "...####......#######........###....####..####... "
        "....####................#######....#########.... "
        ".....####............#######.......#####........ "
        ".......#################..........####.......... "
        ".........#############..........####............ "
        "..................#################............. "
        ".....................###########................ "
    ),
    (
        "..........#########............. "
        "........####.....########....... "
        ".......##......#####....####.... "
        "...######...#####..........##... "
        ".####.##...##.....######....##.. "
        ".##...##...##..###....#####.##.. "
        "##....##...####..####.....####.. "
        "###...##...##......#####....###. "
        ".###....#####......##...##...### "
        "..####.....####..####...##....## "
        "..##.#####....####.##...##...##. "
        "..##....######.....##...##.####. "
        "...##..........#####...######... "
        "....####....#####......##....... "
        ".......########......###........ "
        ".............#########.......... "
    ),
    (
        ".....######....... "
        "...##...###...##.. "
        ".####.##..###..##. "
        "##.##.#####...###. "
        "##..#.#....#.#..## "
        ".###...#####.##..# "
        ".##..###..##.####. "
        "..##...###...##... "
        ".......######..... "
    ),
)
# Higher resolution countdown masks for the standalone Codex view.
CODEX_GLYPHS = {
    "0": "..###.. .#...#. #.....# #.....# #.....# #..#..# #.....# #.....# #.....# .#...#. ..###..",
    "1": "...#... ..##... .#.#... ...#... ...#... ...#... ...#... ...#... ...#... ...#... .#####.",
    "2": "..###.. .#...#. #.....# ......# .....#. ....#.. ...#... ..#.... .#..... #...... #######",
    "3": ".#####. ......# .....#. ....#.. ..###.. .....#. ......# ......# #.....# .#...#. ..###..",
    "4": ".....#. ....#.. ....#.. ...#... ..#.... ..#..#. .#...#. #....#. ####### .....#. .....#.",
    "5": "####### #...... #...... #...... #####.. .....#. ......# ......# #.....# .#...#. ..###..",
    "6": "...###. ..#.... .#..... #...... #.###.. ##...#. #.....# #.....# #.....# .#...#. ..###..",
    "7": "####### ......# .....#. .....#. ....#.. ....#.. ...#... ...#... ..#.... ..#.... ..#....",
    "8": "..###.. .#...#. #.....# #.....# .#...#. ..###.. .#...#. #.....# #.....# .#...#. ..###..",
    "9": "..###.. .#...#. #.....# #.....# #.....# .#...## ..###.# ......# .....#. ....#.. .###...",
    "d": "......# ......# ......# ..###.# .#...## #.....# #.....# #.....# #.....# .#...## ..###.#",
    "h": "#...... #...... #...... #.###.. ##...#. #.....# #.....# #.....# #.....# #.....# #.....#",
}
RESOURCE_LABELS = (("CPU", "C", ""), ("RAM", "R", "▦"),
                   ("SWAP", "S", ""), ("DISK", "D", ""))


def bitmap(pattern):
    return tuple(row.replace(".", " ").replace("#", "█") for row in pattern.split())


def braille(char):
    dots = ord(char) - 0x2800
    return tuple(
        "".join("█" if dots & (1 << bit) else " " for bit in pair)
        for pair in ((0, 3), (1, 4), (2, 5), (6, 7))
    )


def glyph_tiles(text, icon=None):
    glyphs = [bitmap(ICONS[icon])] if icon else []
    for char in text:
        if 0x2800 <= ord(char) <= 0x28FF:
            # Align the bottom of the four-dot matrix with the text baseline.
            glyphs.append(("  ", *braille(char)))
        else:
            glyphs.append(bitmap(GLYPHS.get(char.replace("", "!"), GLYPHS["?"])))
    return glyphs


def tile(text, icon=None):
    # Keep each glyph's full width on every row, including empty rows.
    return [" ".join(row) for row in zip(*glyph_tiles(text, icon))] or [""] * 5


def codex_detail_tiles(text):
    height = 14
    glyphs = [bitmap(CODEX_SWIRL)]
    for char in text:
        if 0x2800 <= ord(char) <= 0x28FF:
            dots = []
            for pair in braille(char):
                row = "   ".join(pixel * 2 for pixel in pair)
                dots.extend((row, row, " " * 7, " " * 7))
            glyphs.append(tuple(dots[:-2]))
        elif char in CODEX_GLYPHS:
            glyphs.append(bitmap(CODEX_GLYPHS[char]))
        else:
            # Keep the compact font's other units and status glyphs legible.
            rows = tile(char)
            glyphs.append(tuple(row for row in rows for _ in range(2)))

    padded = []
    for glyph in glyphs:
        top = (height - len(glyph)) // 2
        empty = (" " * len(glyph[0]),)
        padded.append(empty * top + glyph + empty * (height - len(glyph) - top))
    return padded


def resource_tile(name, value):
    icon = bitmap(RESOURCE_ICONS[name])
    if len(value) == 1 and 0x2800 <= ord(value) <= 0x28FF:
        dots = []
        for pair in braille(value):
            if dots:
                dots.append("   ")
            dots.append(" ".join(pair))
        level = ("   ", *dots, "   ")
    else:
        rows = tile(value)
        empty = " " * len(rows[0])
        level = (empty, empty, *rows, empty, empty)
    return [f"{shape}  {sample}" for shape, sample in zip(icon, level)]


def join_tiles(tiles):
    tiles, colors = zip(*tiles)
    return [tuple(zip(row, colors)) for row in zip(*tiles)]


def center_vertically(rows, lines):
    return [""] * ((lines - len(rows)) // 2) + rows if rows else rows


def row_width(row, gap):
    return sum(len(text) for text, _ in row) + max(0, len(row) - 1) * gap


def draw(rows, cols, horizontal=1, vertical=1, gap=3):
    art = []
    for row in rows:
        width = row_width(row, gap) * horizontal
        left = (cols - width) // 2
        segments = []
        for text, color in row:
            pixels = "".join(pixel * horizontal for pixel in text)
            if color and pixels.strip():
                pixels = f"\033[{color}m{pixels}\033[0m"
            segments.append(pixels)
        line = (" " * left + (" " * (gap * horizontal)).join(segments)).rstrip()
        art.extend([line] * vertical)
    return art


def codex_logo(height):
    # Prefer a native mask at its original size, then sample the finest mask
    # at intermediate and larger sizes.
    masks = [bitmap(pattern) for pattern in CODEX_LOGO_MASKS]
    for mask in masks:
        if len(mask) == height:
            return mask
    source = masks[0]
    size = len(source)
    return tuple(
        "".join(source[(2 * y + 1) * size // (2 * height)][(2 * x + 1) * size // (2 * height)]
                for x in range(2 * height))
        for y in range(height)
    )


def codex_detail_scale(codex_width, resource_width, width, rows, height):
    # Reserve one extra logical column for the logo at every scale. When
    # only the original bitmap fits, keep the compact swirl at scale 1.
    scale = min(width // (2 * max(codex_width + 1, resource_width)), height // rows)
    if not scale and width >= 2 * max(codex_width, resource_width) and height >= rows:
        return 1
    return scale


def scale_rows(rows, horizontal, vertical):
    return [
        tuple(("".join(pixel * horizontal for pixel in text), color) for text, color in row)
        for row in rows for _ in range(vertical)
    ]


def scaled_codex_tiles(detail, color, cols, scale):
    tiles = [
        (tuple("".join(pixel * (2 * scale) for pixel in row)
               for row in glyph for _ in range(scale)), color)
        for glyph in detail
    ]
    text_width = sum(len(glyph[0]) + 4 * scale for glyph, _ in tiles[1:])
    # Keep the logo close to the 11-row digit height and inside the viewport.
    logo_height = min(9 * scale, (cols - 1 - text_width) // 2)
    if logo_height >= 9:
        logo = codex_logo(logo_height)
        height = len(tiles[0][0])
        top = (height - len(logo)) // 2
        empty = (" " * len(logo[0]),)
        tiles[0] = (empty * top + logo + empty * (height - len(logo) - top), color)
    return tiles


def trim_band(rows):
    # Trim a tile's unused side columns across its whole height so the gaps
    # are measured from the visible art and do not change from row to row.
    tiles = []
    for column in zip(*rows):
        ink = [text for text, _ in column if text.strip()]
        if ink:
            left = min(len(text) - len(text.lstrip()) for text in ink)
            right = max(len(text.rstrip()) for text in ink)
            column = tuple((text[left:right], color) for text, color in column)
        tiles.append(column)
    return tiles


def draw_combined(upper, resources, cols, lines, horizontal, vertical, upper_gap):
    bands = [(trim_band(upper), upper_gap)]
    if () in resources:
        split = resources.index(())
        resource_bands = (resources[:split], resources[split + 1:])
    else:
        resource_bands = (resources,)
    for rows in resource_bands:
        bands.append((trim_band(scale_rows(rows, horizontal, vertical)), 3 * horizontal))

    widths = [sum(len(tile[0][0]) for tile in tiles) for tiles, _ in bands]
    target = max(width + gap * (len(tiles) - 1)
                 for (tiles, gap), width in zip(bands, widths))
    art = []
    for (tiles, _), width in zip(bands, widths):
        if art:
            art.extend([""] * vertical)
        count = len(tiles) - 1
        if count:
            gap, extra = divmod(target - width, count)
            # Spread any remainder over the available gaps.
            spaces = [" " * (gap + ((i + 1) * extra // count - i * extra // count))
                      for i in range(count)] + [""]
            tiles = [tuple((text + space, color) for text, color in tile)
                     for tile, space in zip(tiles, spaces)]
        art.extend(draw(zip(*tiles), cols, gap=0))
    return center_vertically(art, lines)


def compact_rows(codex, codex_color, resources, width, height):
    # Try full names first, then pack shorter labels when rows are scarce.
    prefix = [((f"Codex {codex}"[:width], codex_color),)] if codex is not None else []
    for short in (False, True):
        pairs = [
            (f"{name[:1]}{value}" if short else f"{name} {value}", color)
            for name, value, color in resources
        ]
        if all(len(text) <= width for text, _ in pairs):
            stacked = [(pair,) for pair in pairs]
            if len(prefix) + len(stacked) <= height:
                return prefix + stacked, 2
            packed = []
            for pair in pairs:
                if packed and row_width((*packed[-1], pair), 2) <= width:
                    packed[-1] = (*packed[-1], pair)
                else:
                    packed.append((pair,))
            if len(prefix) + len(packed) <= height:
                return prefix + packed, 2
    # If even the short values exceed the viewport, keep each metric's label.
    pairs = [(name[0], color) for name, _, color in resources]
    labels = [tuple(pairs[i:i + width]) for i in range(0, len(pairs), width)]
    return (prefix + labels)[:height], 0


def compose(view, codex, resources, cols, lines=24, colors=(None,) * 5):
    # Reserve a column against autowrap and a row for the final newline.
    width, height = max(0, cols - 1), max(0, lines - 1)
    if not width or not height:
        return []
    codex_text = codex[1:] if codex.startswith("֍") else codex
    resource_values = []
    for index, (name, letter, symbol) in enumerate(RESOURCE_LABELS):
        token = resources[index] if index < len(resources) else "!"
        value = token[1:] if token.startswith((letter, symbol)) else token
        resource_values.append((name, (value or "!").replace("", "!"), colors[index + 1]))

    codex_rows = join_tiles([(tile(codex_text, "Codex"), colors[0])])
    candidates = []
    if view != "resources":
        codex_bitmap = codex_detail_tiles(codex_text)
        codex_width = row_width(tuple((glyph[0], None) for glyph in codex_bitmap), 2)
        codex_height = len(codex_bitmap[0])

    if view == "codex":
        scale = codex_detail_scale(codex_width, 0, width, codex_height, height)
        if scale:
            tiles = scaled_codex_tiles(codex_bitmap, colors[0], cols, scale)
            return center_vertically(draw(join_tiles(tiles), cols, gap=4 * scale), lines)
        candidates = [(codex_rows, False)]
    else:
        basic = [(tile(value, name), color) for name, value, color in resource_values]
        detail = [(resource_tile(name, value), color) for name, value, color in resource_values]
        for start in (4, 2):
            for parts in (detail, basic):
                rows = join_tiles(parts[:start])
                if start == 2:
                    rows += [()] + join_tiles(parts[start:])
                candidates.append((rows, parts is detail))

        if view == "all":
            for rows, _ in candidates:
                resource_width = max(row_width(row, 3) for row in rows)
                canvas_height = codex_height + 1 + len(rows)
                scale = codex_detail_scale(codex_width, resource_width, width, canvas_height, height)
                if scale:
                    tiles = scaled_codex_tiles(codex_bitmap, colors[0], cols, scale)
                    return draw_combined(join_tiles(tiles), rows, cols, lines,
                                         2 * scale, scale, 4 * scale)
            candidates = [(codex_rows + [()] + rows, detailed) for rows, detailed in candidates]

    for rows, detailed in candidates:
        canvas_width = max(row_width(row, 3) for row in rows)
        horizontal = width // canvas_width
        vertical = height // len(rows)
        if horizontal >= 2:
            vertical = min(horizontal // 2, vertical)
            horizontal = 2 * vertical
        elif not detailed:
            vertical = min(horizontal, vertical)
            horizontal = vertical
        else:
            continue
        if vertical:
            if view == "all":
                upper = join_tiles([(glyph, colors[0]) for glyph in glyph_tiles(codex_text, "Codex")])
                upper = scale_rows(upper, horizontal, vertical)
                return draw_combined(upper, rows[len(codex_rows) + 1:], cols, lines,
                                     horizontal, vertical, horizontal)
            return center_vertically(draw(rows, cols, horizontal, vertical), lines)

    compact, gap = compact_rows(
        codex_text if view != "resources" else None,
        colors[0], resource_values if view != "codex" else [],
        width, height,
    )
    return center_vertically(draw(compact, cols, gap=gap), lines)


def write_frame(art, lines):
    sys.stdout.write("\x1b[H")
    for line in art[:max(1, lines - 1)]:
        sys.stdout.write("\x1b[2K" + line + "\n")
    sys.stdout.write("\x1b[J")
    sys.stdout.flush()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--view", choices=("all", "codex", "resources"), default="all")
    parser.add_argument("--codex", default="֍⟳d⟳h")
    parser.add_argument("--resources", nargs=4, default=("⟳", "⟳", "⟳", "⟳"))
    parser.add_argument("--colors", nargs=5, default=("90", "90", "90", "90", "90"))
    parser.add_argument("--columns", type=int)
    parser.add_argument("--lines", type=int)
    output = parser.add_mutually_exclusive_group()
    output.add_argument("--plain", action="store_true")
    output.add_argument("--frame", action="store_true")
    args = parser.parse_args()
    if not args.plain and (not sys.stdin.isatty() or not sys.stdout.isatty()):
        print("yafp-screen requiere una terminal interactiva.", file=sys.stderr)
        return 1
    colors = tuple(args.colors) if os.environ.get("NO_COLOR") is None else (None,) * 5
    if args.plain or args.frame:
        size = terminal_size(args)
        art = compose(args.view, args.codex, args.resources, size.columns, size.lines, colors)
        if args.frame:
            write_frame(art, size.lines)
        else:
            print("\n".join(art))
        return 0
    stream = sys.stdin
    fd = stream.fileno()
    import termios
    old = termios.tcgetattr(fd)
    try:
        mode = termios.tcgetattr(fd)
        mode[3] &= ~(termios.ECHO | termios.ICANON | termios.ISIG)
        mode[6][termios.VMIN] = 0
        mode[6][termios.VTIME] = 0
        termios.tcsetattr(fd, termios.TCSANOW, mode)
        sys.stdout.write("\x1b7\x1b[?1049h\x1b[?25l")
        sys.stdout.flush()
        while True:
            size = terminal_size(args)
            art = compose(args.view, args.codex, args.resources, size.columns, size.lines, colors)
            write_frame(art, size.lines)
            import select
            ready, _, _ = select.select([fd], [], [], 1)
            if ready:
                key = os.read(fd, 1)
                if key in (b"q", b"Q", b"\x1b", b"\x03"):
                    break
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        sys.stdout.write("\x1b[0m\x1b[?25h\x1b[?1049l\x1b8")
        sys.stdout.flush()
    return 0


def terminal_size(args):
    detected = shutil.get_terminal_size((80, 24))
    return os.terminal_size((args.columns or detected.columns, args.lines or detected.lines))


if __name__ == "__main__":
    raise SystemExit(main())
