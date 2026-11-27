#!/usr/bin/env python3
"""Render block-character art for yafp-screen."""
import argparse
from itertools import groupby
import json
import math
import os
import random
import re
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
    "": "##### #.#.# ..#.. .#.#. #####",
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
    "": "####### #.....# #.###.# .#.#.#. ..#.#.. ...#... ..#.#.. .#...#. #..#..# #.###.# #######",
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


# Coefficients of the sweep step (column * dx + row * dy).
# Terminal row numbers increase downward.
SHINE_SWEEPS = {
    "diagonal-45": (1, 1),
    "diagonal-135": (1, -1),
    "diagonal": (1, -1),
    "vertical-right": (1, 0),
    "vertical-left": (-1, 0),
    "horizontal-down": (0, 1),
    "horizontal-up": (0, -1),
}


def stripe_phases(cells, mode):
    dx, dy = SHINE_SWEEPS[mode]
    bands = {}
    for y, x in cells:
        bands.setdefault(x * dx + y * dy, []).append((y, x))
    phases = [bands.get(step, ()) for step in range(min(bands), max(bands) + 1)]
    return phases + [()] * 10  # One second between sweeps.


def shine_frames(art, mode, first_step, sweep_state=None):
    # Each record fits on one transport line. Absolute positions also avoid
    # scrolling at the bottom margin. Start each new sample from its true colors.
    base = "\x1b[H" + "".join(
        f"\x1b[{y};1H{row}\x1b[K" for y, row in enumerate(art, 1)
    ) + "\x1b[J"
    if (mode not in ("point", "random") and mode not in SHINE_SWEEPS) or "NO_COLOR" in os.environ:
        return [base]
    cells = {}
    for y, row in enumerate(art, 1):
        x, color = 1, "0"
        for part in re.split(r"(\x1b\[\d+m)", row):
            if part.startswith("\x1b["):
                color = part[2:-1]
                continue
            for offset, char in enumerate(part):
                if char == "█":
                    cells[y, x + offset] = color
            x += len(part)
    if not cells:
        return [base]

    if mode == "random":
        stripe, phase = sweep_state or ("", 0)
        phases = stripe_phases(cells, stripe) if stripe in SHINE_SWEEPS else []
    elif mode == "point":
        path = sorted(cells, key=lambda pos: (pos[0], pos[1] if pos[0] % 2 else -pos[1]))
        phases = [[pos] for pos in path]
    else:
        phases = stripe_phases(cells, mode)

    records = []
    previous = ()
    for step in range(first_step, first_step + 10):
        if mode == "random":
            if phase >= len(phases):
                stripe = random.choice([name for name in SHINE_SWEEPS
                                        if name not in ("diagonal", stripe)])
                phases = stripe_phases(cells, stripe)
                phase = 0
            current = phases[phase]
            phase += 1
        else:
            current = phases[step % len(phases)]
        changes = [base] if not records else []
        for positions, highlight in ((previous, False), (current, True)):
            for y, x in positions:
                color = "97" if highlight else cells[y, x]
                changes.append(f"\x1b[{y};{x}H\x1b[{color}m█")
        records.append("".join(changes) + "\x1b[0m")
        previous = current
    if mode == "random" and sweep_state is not None:
        sweep_state[:] = [stripe, phase]
    return records


def matrix_margins(art):
    """Reserve each drawing's bounding box, including its interior holes."""
    rows = [re.sub(r"\x1b\[\d+m", "", row) for row in art]
    protected = set()
    for occupied, band in groupby(enumerate(rows, 1), key=lambda item: bool(item[1].strip())):
        if not occupied:
            continue
        band = list(band)
        columns = sorted({x for _, row in band for x, char in enumerate(row, 1)
                          if not char.isspace()})
        for _, run in groupby(enumerate(columns), key=lambda item: item[1] - item[0]):
            xs = [x for _, x in run]
            protected.update((y, x) for y in range(band[0][0] - 1, band[-1][0] + 2)
                             for x in range(xs[0] - 2, xs[-1] + 3))
    return protected


MATRIX_SPACING = {"low": 5, "medium": 3, "high": 2}
MATRIX_COLORS = {
    "green": (92, 32), "cyan": (96, 36), "blue": (94, 34),
    "magenta": (95, 35), "yellow": (93, 33), "red": (91, 31),
}


RESOURCE_WORDS = ("CPU", "MEMORY", "SWAP", "DISK")
AI_WORDS = (
    "TOKENS", "PROMPT", "CONTEXT", "MODEL", "CHAT", "REPLY",
    "NEURAL", "LAYER", "WEIGHT", "BIAS", "TENSOR", "ATTENTION",
    "TRAIN", "LEARN", "BATCH", "EPOCH", "LOSS", "GRADIENT",
    "INFER", "DECODE", "SAMPLE", "LOGITS", "TOPK", "SEED",
    "EMBED", "VECTOR", "QUERY", "INDEX", "RANK", "RETRIEVE",
    "AGENT", "TOOL", "PLAN", "REASON", "ACTION", "MEMORY",
    "AI", "ML", "LLM", "NLP", "RAG", "GPU", "MOE", "RLHF",
)
MATRIX_WORDS = {"codex": ("CODEX",), "resources": RESOURCE_WORDS,
                "all": ("CODEX",) + RESOURCE_WORDS}


def matrix_frames(art, frames, columns, lines, first_step, density="low", color="green",
                  text="random", view="all", speed="normal"):
    if "NO_COLOR" in os.environ or not any("█" in row for row in art):
        return frames
    protected = matrix_margins(art)
    # The same lanes and offsets survive the next sample's renderer process.
    rng = random.Random(133)
    streams = []
    spacing = MATRIX_SPACING.get(density, MATRIX_SPACING["low"])
    numerator, denominator = {"slow": (1, 2), "fast": (2, 1)}.get(speed, (1, 1))
    head_color, trail_color = MATRIX_COLORS.get(color, MATRIX_COLORS["green"])
    for start in range(1, columns, spacing):
        x = start + rng.randrange(spacing - 1)
        if x < columns:
            streams.append((x, rng.randrange(2, 5), rng.randrange(3, 7), rng.randrange(1000)))

    records = []
    previous = {}
    alphabet = "01ABCDEFGHIJKLMNOPQRSTUVWXYZ:;+=*"
    words = {"ai": AI_WORDS, "labels": MATRIX_WORDS[view]}.get(text, ())
    if words:
        # Let even the longest word leave the screen before starting the next.
        cycle_length = lines + max(map(len, words)) + 3
    for index in range(10):
        current = {}
        for x, lane_delay, length, offset in streams:
            tick = (first_step + index) * numerator // (lane_delay * denominator) + offset
            if words:
                descent, head = divmod(tick, cycle_length)
                word = words[(offset + descent) % len(words)]
                length = len(word)
            else:
                head = tick % (lines + length + 3)
            for depth in range(length):
                y = head - depth
                if 1 <= y < lines and (y, x) not in protected:
                    char = (word[-1 - depth] if words else
                            alphabet[(tick * 7 + depth * 11 + x) % len(alphabet)])
                    current[y, x] = (head_color if depth == 0 else trail_color, char)
        base = frames[index] if index < len(frames) else ""
        records.append(background_update(base, previous, current))
        previous = current
    return records


def background_update(base, previous, current):
    updates = [base]
    for y, x in previous.keys() - current.keys():
        updates.append(f"\x1b[{y};{x}H ")
    for (y, x), style in current.items():
        if previous.get((y, x)) != style:
            color, char = style
            updates.append(f"\x1b[{y};{x}H\x1b[{color}m{char}")
    return "".join(updates) + "\x1b[0m"


def star_wars(width, height, step, focus):
    cx, cy = focus
    rng = random.Random(1977)
    warp = step % 100 >= 90
    for _ in range(min(220, 12 + width * height // 75)):
        angle = rng.random() * math.tau
        dx, dy = math.cos(angle), math.sin(angle) / 2
        # Project each ray to the nearest edge, then accelerate along it.
        reach = min((width - cx if dx > 0 else 1 - cx) / dx if dx else math.inf,
                    (height - cy if dy > 0 else 1 - cy) / dy if dy else math.inf)
        age = (rng.randrange(80) + step) % 80
        distance = reach * (age / 79) ** 2
        stroke = "─" if abs(dx) > 4 * abs(dy) else "│" if abs(dx) < abs(dy) else (
            "╲" if dx * dy > 0 else "╱")
        for tail in range(1 + (min(8, int(distance)) if warp else 0)):
            yield (round(cy + dy * (distance - tail)), round(cx + dx * (distance - tail)),
                   97 if tail == 0 and age > 50 else 90, stroke if warp else "·")


def star_trek(width, height, step, focus):
    sweep = step % width + 1
    for y in range(2, height, 2):
        yield y, sweep, 36, "┊"
    for edge, direction, color in ((1, 1, 33), (width, -1, 35)):
        for radius in (3, 5):
            for degree in range(0, 91, 4):
                angle = math.radians(degree)
                yield (1 + round(radius * math.sin(angle)),
                       edge + direction * round(2 * radius * math.cos(angle)), color, "▪")
    rng = random.Random(1701)
    for _ in range(max(4, width // 6)):
        x, y = rng.randint(1, width), rng.randint(1, height)
        elapsed = (sweep - x) % width
        if elapsed < 14:
            yield y, x, 93 if elapsed < 3 else 90, "✧" if elapsed < 3 else "·"


def tron(width, height, step, focus):
    horizon = max(1, height * 2 // 3)
    depth = max(1, height - horizon)
    for y in range(horizon, height + 1):
        for lane in range(-7, 8):
            x = round(width / 2 + lane * (1 + (y - horizon) * width / (8 * depth)))
            yield y, x, 34, "│" if lane == 0 else "╱" if lane < 0 else "╲"
    for row in {horizon, horizon + depth // 4, horizon + depth // 2, height}:
        for x in range(1, width + 1):
            yield row, x, 34, "─"
    for bike, color in enumerate((96, 33)):
        left = 1 + bike * width // 2
        span, rise = max(1, width // 2 - 2), max(1, depth - 2)
        perimeter = 2 * (span + rise)
        for tail in range(min(12, perimeter - 1), -1, -1):
            t = (step + bike * span - tail) % perimeter
            x = left + min(t, span) - min(max(0, t - span - rise), span)
            y = horizon + 1 + min(max(0, t - span), rise) - max(0, t - 2 * span - rise)
            trail = "│" if span < t <= span + rise or t > 2 * span + rise else "─"
            yield y, x, color, "◆" if tail == 0 else trail


def cyberpunk(width, height, step, focus):
    rng = random.Random(2077)
    left = 1
    while left <= width:
        span = rng.randint(5, 10)
        roof = height - rng.randint(max(1, height // 6), max(2, height // 2))
        for x in range(left, left + span):
            yield roof, x, 35, "─"
        for y in range(roof + 1, height + 1):
            yield y, left, 35, "│"
            if (y - roof) % 2:
                for x in range(left + 2, left + span - 1, 3):
                    if (x * 7 + y + step // 8) % 5:
                        yield y, x, 36, "▪"
        left += span
    for _ in range(min(150, 4 + width * height // 65)):
        y = (rng.randrange(height) + step) % height
        x = (rng.randrange(width) - y) % width
        yield y + 1, x + 1, 90, "╱"
    for offset, char in enumerate("NEON"):
        if offset != 2 or step % 60 not in (0, 1, 4, 5):
            yield max(1, height * 3 // 4), 3 + offset, 95, char


def terminator(width, height, step, focus):
    cycle, phase = divmod(step, 60)
    # Pause the contact for acquisition, then let it slip the lock.
    def contact(tick):
        travel = cycle * 42 + min(tick, 28) + max(0, tick - 46)
        x = 1 + round((width - 1) * (0.5 + 0.43 * math.sin(travel / 16)))
        y = 2 + round(height * (0.10 + 0.08 * math.cos(travel / 12)))
        return x, y

    x, y = contact(phase)
    aim_x, aim_y = contact(max(0, phase - 1) // 3 * 3 if phase < 46 else phase - 1)
    radius = max(2, 7 - max(0, phase - 24) // 3) if phase < 47 else 7
    for dx, dy, corner in ((-1, -1, "⌜"), (1, -1, "⌝"), (-1, 1, "⌞"), (1, 1, "⌟")):
        yield aim_y + dy, aim_x + dx * radius, 91, corner
    yield y, x, 97, "•"
    yield 1, 1 + step % width, 31, "▾"


def robocop(width, height, step, focus):
    cycle, phase = divmod(step, 96)
    scan = 1 + min(phase, 35) * (height - 1) // 35
    for x in range(1 + step % 4, width + 1, 4):
        yield scan, x, 34, "─"
    x, y = 2 + width * (1 + cycle % 3) // 5, max(2, height // 5)
    if phase > 12:
        for dx, dy, corner in ((-2, -1, "┌"), (2, -1, "┐"), (-2, 1, "└"), (2, 1, "┘")):
            yield y + dy, x + dx, 96, corner
        yield y, x, 97, "+"
    label = "SCAN" if phase < 35 else "MATCH"
    if cycle % 3 == 2 and phase >= 55:
        label = "DIRECTIVE 4" if phase < 73 else "CLASSIFIED"
    for offset, char in enumerate(label):
        yield 2, max(1, width - len(label)) + offset, 96, char


def blade_runner(width, height, step, focus):
    fly_x = step // 2 % (width + 8) - 3
    fly_y = max(2, height // 6)
    sign_x = max(3, width // 4)
    for x in range(1, width + 1):
        tower = (x - 1) // 8
        roof = height - (2 + (tower * 13 + 3) % max(3, height // 2))
        yield roof, x, 90, "─"
        if x % 8 == 1:
            for y in range(roof + 1, height + 1):
                yield y, x, 90, "│"
    for y in range(fly_y + 1, height + 1):
        reach = y - fly_y
        center = fly_x + reach
        for x in range(center - reach // 3, center + reach // 3 + 1):
            if (3 * x + 5 * y + step) % 11 == 0:
                yield y, x, 36, "╱"
    for offset, char in enumerate("•━•"):
        yield fly_y, fly_x + offset, 93, char
    eye = "─────" if 0 <= fly_x - sign_x <= 1 else "◁─◉─▷"
    for offset, char in enumerate(eye):
        yield max(2, height * 3 // 4), sign_x + offset, 95, char


SCENES = {scene.__name__: scene for scene in
          (star_wars, star_trek, tron, cyberpunk, terminator, robocop, blade_runner)}


BACKGROUNDS = ("matrix", *SCENES)


def active_background(setting, seed, turn):
    if setting == "random":
        order = list(BACKGROUNDS)
        random.Random(seed).shuffle(order)
        return order[turn % len(order)]
    return setting if setting in BACKGROUNDS else "off"


def scene_frames(name, art, frames, columns, lines, first_step, view):
    if "NO_COLOR" in os.environ or not any("█" in row for row in art):
        return frames
    width, height = columns - 1, lines - 1
    protected = matrix_margins(art)
    focus = ((width + 1) / 2, (height + 1) / 2)
    if name == "star_wars" and view == "codex":
        # Locate the leftmost glyph (the Blossom) at the current drawing scale.
        occupied = sorted({x for y, x in protected if 1 <= x <= width})
        left = occupied[0]
        right = next((x for x, nxt in zip(occupied, occupied[1:]) if nxt > x + 1),
                     min(width, left + height))
        focus = ((left + right) / 2, focus[1])
    previous = {}
    records = []
    for index in range(10):
        cells = SCENES[name](width, height, first_step + index, focus)
        current = {(y, x): (color, char) for y, x, color, char in cells
                   if 1 <= x <= width and 1 <= y <= height and (y, x) not in protected}
        base = frames[index] if index < len(frames) else ""
        records.append(background_update(base, previous, current))
        previous = current
    return records


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--view", choices=("all", "codex", "resources"), default="all")
    parser.add_argument("--codex", default="֍⟳d⟳h")
    parser.add_argument("--resources", nargs=4, default=("⟳", "⟳", "⟳", "⟳"))
    parser.add_argument("--colors", nargs=5, default=("90", "90", "90", "90", "90"))
    parser.add_argument("--columns", type=int)
    parser.add_argument("--lines", type=int)
    output = parser.add_mutually_exclusive_group()
    output.add_argument("--list-themes", action="store_true")
    output.add_argument("--plain", action="store_true")
    output.add_argument("--frame", action="store_true")
    output.add_argument("--frames", choices=("lines", "json"))
    parser.add_argument("--shine", default="off")
    parser.add_argument("--background", default="off")
    parser.add_argument("--background-seed", type=int, default=0)
    parser.add_argument("--background-turn", type=int, default=0)
    parser.add_argument("--show-background", action="store_true")
    parser.add_argument("--matrix-density", default="low")
    parser.add_argument("--matrix-speed", default="normal")
    parser.add_argument("--matrix-color", default="green")
    parser.add_argument("--matrix-text", default="random")
    parser.add_argument("--step", type=int, default=0)
    parser.add_argument("--sweep-state", default=":0")
    args = parser.parse_args()
    if args.list_themes:
        print(*BACKGROUNDS, "random", "off", sep="\n")
        return 0
    if not (args.plain or args.frames) and (not sys.stdin.isatty() or not sys.stdout.isatty()):
        print("yafp-screen requires an interactive terminal.", file=sys.stderr)
        return 1
    colors = tuple(args.colors) if os.environ.get("NO_COLOR") is None else (None,) * 5
    if args.plain or args.frame or args.frames:
        size = terminal_size(args)
        art = compose(args.view, args.codex, args.resources, size.columns, size.lines, colors)
        if args.frames:
            stripe, phase = args.sweep_state.split(":")
            state = [stripe, int(phase)]
            frames = shine_frames(art, args.shine, args.step, state)
            background = active_background(args.background, args.background_seed, args.background_turn)
            if background == "matrix":
                frames = matrix_frames(art, frames, size.columns, size.lines, args.step,
                                       args.matrix_density, args.matrix_color,
                                       args.matrix_text, args.view, args.matrix_speed)
            elif background in SCENES:
                frames = scene_frames(background, art, frames, size.columns, size.lines,
                                      args.step, args.view)
            if args.show_background and size.lines > 1 and size.columns > 1:
                label = background[:size.columns - 1]
                frames[0] += f"\x1b[{size.lines};{size.columns - len(label)}H\x1b[0m{label}"
            if args.shine == "random":
                frames.insert(0, f"{state[0]}:{state[1]}")
            print(json.dumps(frames) if args.frames == "json" else "\n".join(frames))
        elif args.frame:
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
