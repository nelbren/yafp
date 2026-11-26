import importlib.util
import io
import re
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location(
    "yafp_screen_renderer", ROOT / "scripts/unix/screen/render.py"
)
RENDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RENDER)


class ScreenRendererTests(unittest.TestCase):
    def test_matrix_rain_preserves_holes_margins_and_shine(self):
        art = [""] * 4 + ["          \x1b[93m█████\x1b[0m"] + [
            "          \x1b[93m█   █\x1b[0m"] * 3 + ["          \x1b[93m█████\x1b[0m"]
        with patch.dict(RENDER.os.environ, clear=True):
            foreground = RENDER.shine_frames(art, "random", 0, ["", 0])
            records = RENDER.matrix_frames(art, foreground, 65, 24, 0)
            static = RENDER.shine_frames(art, "off", 0)
            rain_only = RENDER.matrix_frames(art, static, 65, 24, 0)
        self.assertEqual(len(records), 10)
        self.assertEqual(len(rain_only), 10)
        self.assertTrue(any("\x1b[92m" in frame for frame in rain_only))
        self.assertTrue(any("\x1b[32m" in frame for frame in rain_only))
        for index, (frame, shine) in enumerate(zip(records, foreground)):
            self.assertTrue(frame.startswith(shine))
            rain = frame[len(shine):]
            self.assertEqual(rain, rain_only[index][len(static[0]) if index == 0 else 0:])
            for row, col in re.findall(r"\x1b\[(\d+);(\d+)H", rain):
                y, x = int(row), int(col)
                self.assertTrue(1 <= y < 24 and 1 <= x < 65)
                self.assertFalse(4 <= y <= 10 and 9 <= x <= 17)
        self.assertTrue(any(re.search(r"H ", frame) for frame in rain_only[1:]))

    def test_matrix_density_color_and_fallbacks(self):
        args = (["█"], ["base"], 121, 40, 0)
        with patch.dict(RENDER.os.environ, clear=True):
            original = RENDER.matrix_frames(*args)
            self.assertEqual(original, RENDER.matrix_frames(*args, "low", "green"))
            self.assertEqual(original, RENDER.matrix_frames(*args, "unknown", "unknown"))
            lanes = []
            for density in ("low", "medium", "high"):
                batch = "".join(RENDER.matrix_frames(*args, density, "green"))
                lanes.append(len(set(re.findall(r"\x1b\[\d+;(\d+)H\x1b\[", batch))))
            self.assertLess(lanes[0], lanes[1])
            self.assertLess(lanes[1], lanes[2])
            for hue, head, trail in (("cyan", 96, 36), ("blue", 94, 34),
                                     ("magenta", 95, 35), ("yellow", 93, 33), ("red", 91, 31)):
                with self.subTest(hue=hue):
                    expected = [frame.replace("\x1b[92m", f"\x1b[{head}m")
                                .replace("\x1b[32m", f"\x1b[{trail}m") for frame in original]
                    self.assertEqual(expected, RENDER.matrix_frames(*args, "low", hue))

    def test_matrix_labels_match_view_and_keep_word_order(self):
        vocabularies = {"codex": {"CODEX"}, "resources": {"CPU", "MEMORY", "SWAP", "DISK"},
                        "all": {"CODEX", "CPU", "MEMORY", "SWAP", "DISK"}}
        args = (["█"], ["base"], 121, 40)
        cell = re.compile(r"\x1b\[(\d+);(\d+)H\x1b\[(92|32)m(.)")
        with patch.dict(RENDER.os.environ, clear=True):
            original = RENDER.matrix_frames(*args, 0)
            for setting in ("random", "unknown"):
                self.assertEqual(original, RENDER.matrix_frames(*args, 0, text=setting))
            for view, words in vocabularies.items():
                seen = set()
                for step in (0, 10, 20):
                    frame = RENDER.matrix_frames(*args, step, text="labels", view=view)[0]
                    lanes = {}
                    for y, x, color, char in cell.findall(frame):
                        lanes.setdefault(x, []).append((int(y), color, char))
                    for lane in lanes.values():
                        lane.sort()
                        if lane[0][0] <= 2 or lane[-1][0] == 39:
                            continue  # Ignore partially clipped words.
                        self.assertEqual([c for _, c, _ in lane], ["32"] * (len(lane) - 1) + ["92"])
                        seen.add("".join(char for _, _, char in lane))
                self.assertEqual(seen, words)

    def test_matrix_respects_compact_text_and_no_color(self):
        base = ["static frame"]
        self.assertEqual(RENDER.matrix_frames(["CPU OFF"], base, 15, 4, 0), base)
        with patch.dict(RENDER.os.environ, {"NO_COLOR": ""}):
            self.assertEqual(RENDER.matrix_frames(["█"], base, 80, 24, 0), base)

    def test_matrix_ai_words_fall_in_every_view(self):
        args = (["█"], ["base"], 121, 40, 0)
        with patch.dict(RENDER.os.environ, clear=True):
            frames = RENDER.matrix_frames(*args, text="ai")
            for view in ("codex", "resources"):
                self.assertEqual(frames, RENDER.matrix_frames(*args, text="ai", view=view))
        lanes = {}
        for y, x, color, char in re.findall(r"\x1b\[(\d+);(\d+)H\x1b\[(92|32)m(.)", frames[0]):
            lanes.setdefault(x, []).append((int(y), color, char))
        words = set()
        for lane in lanes.values():
            lane.sort()
            if lane[0][0] <= 2 or lane[-1][0] == 39:
                continue
            self.assertEqual(lane[-1][1], "92")
            words.add("".join(char for _, _, char in lane))
        self.assertGreater(len(words), 1)
        self.assertTrue(words.issubset(RENDER.AI_WORDS))
        self.assertIn("TOKENS", RENDER.AI_WORDS)

    def test_point_moves_across_rows_and_restores_each_color(self):
        art = ["\x1b[91m██\x1b[0m", " \x1b[93m█\x1b[0m"]
        with patch.dict(RENDER.os.environ, clear=True):
            frames = RENDER.shine_frames(art, "point", 0)
            next_batch = RENDER.shine_frames(art, "point", len(frames))
        self.assertEqual(len(frames), 10)
        self.assertTrue(all(frame.count("\x1b[97m") == 1 for frame in frames))
        self.assertIn("\x1b[1;1H\x1b[91m█\x1b[1;2H\x1b[97m█", frames[1])
        self.assertIn("\x1b[2;2H\x1b[97m█", frames[2])
        self.assertIn("\x1b[2;2H\x1b[93m█", frames[3])
        self.assertIn("\x1b[1;2H\x1b[97m█", next_batch[0])

    def test_diagonal_highlights_only_ink_then_pauses(self):
        art = ["\x1b[92m███\x1b[0m", " \x1b[91m█ █\x1b[0m"]
        with patch.dict(RENDER.os.environ, clear=True):
            frames = RENDER.shine_frames(art, "diagonal", 0)
            self.assertEqual(len(RENDER.shine_frames(art, "off", 0)), 1)
            self.assertEqual(len(RENDER.shine_frames(["CPU OFF"], "point", 0)), 1)
        self.assertIn("\x1b[1;1H\x1b[97m█\x1b[2;2H\x1b[97m█", frames[0])
        self.assertIn("\x1b[2;2H\x1b[91m█", frames[1])
        self.assertEqual(frames[1].count("\x1b[97m"), 1)
        self.assertTrue(all("\x1b[97m" not in frame for frame in frames[3:]))
        with patch.dict(RENDER.os.environ, {"NO_COLOR": ""}):
            self.assertEqual(len(RENDER.shine_frames(art, "diagonal", 0)), 1)

    def test_stripe_orientation_and_travel(self):
        art = ["██", "██"]
        expected = {
            "diagonal-45": [["11"], ["12", "21"], ["22"]],
            "diagonal-135": [["21"], ["11", "22"], ["12"]],
            "vertical-right": [["11", "21"], ["12", "22"]],
            "vertical-left": [["12", "22"], ["11", "21"]],
            "horizontal-down": [["11", "12"], ["21", "22"]],
            "horizontal-up": [["21", "22"], ["11", "12"]],
        }
        with patch.dict(RENDER.os.environ, clear=True):
            for mode, sweep in expected.items():
                with self.subTest(mode=mode):
                    frames = RENDER.shine_frames(art, mode, 0)
                    positions = [
                        [y + x for y, x in re.findall(r"\x1b\[(\d+);(\d+)H\x1b\[97m█", frame)]
                        for frame in frames
                    ]
                    self.assertEqual(positions, sweep + [[]] * (len(frames) - len(sweep)))
            self.assertEqual(RENDER.shine_frames(art, "diagonal", 0),
                             RENDER.shine_frames(art, "diagonal-135", 0))

    def test_random_finishes_sweep_and_pause_across_batches(self):
        art = ["██", "██"]
        state = ["", 0]
        with patch.dict(RENDER.os.environ, clear=True), patch.object(
            RENDER.random, "choice", side_effect=["vertical-right", "horizontal-up"]
        ) as choose:
            first = RENDER.shine_frames(art, "random", 0, state)
            self.assertEqual(first, RENDER.shine_frames(art, "vertical-right", 0))
            self.assertEqual(state, ["vertical-right", 10])
            second = RENDER.shine_frames(art, "random", 10, state)
            self.assertTrue(all("\x1b[97m" not in frame for frame in second[:2]))
            self.assertIn("\x1b[2;1H\x1b[97m█", second[2])
            self.assertEqual(state, ["horizontal-up", 8])
            options = set(RENDER.SHINE_SWEEPS) - {"diagonal"}
            self.assertEqual(set(choose.call_args_list[0][0][0]), options)
            self.assertEqual(set(choose.call_args_list[1][0][0]), options - {"vertical-right"})

    def test_single_console_frame(self):
        output = io.StringIO()
        with patch.object(sys, "argv", ["render.py", "--frame", "--columns", "80",
                                        "--lines", "24"]), patch.object(sys, "stdout", output), \
                patch.object(sys.stdin, "isatty", return_value=True), \
                patch.object(output, "isatty", return_value=True):
            self.assertEqual(RENDER.main(), 0)
        frame = output.getvalue()
        self.assertTrue(frame.startswith("\x1b[H\x1b[2K"))
        self.assertIn("█", frame)
        self.assertTrue(frame.endswith("\x1b[J"))
        self.assertLess(frame.count("\n"), 24)

    def test_braille_cells_use_bottom_row_positions(self):
        expected = {
            "⡀": ("  ", "  ", "  ", "█ "),
            "⣀": ("  ", "  ", "  ", "██"),
            "⣄": ("  ", "  ", "█ ", "██"),
            "⣤": ("  ", "  ", "██", "██"),
            "⣦": ("  ", "█ ", "██", "██"),
            "⣶": ("  ", "██", "██", "██"),
            "⣷": ("█ ", "██", "██", "██"),
            "⣿": ("██", "██", "██", "██"),
        }
        self.assertEqual({char: RENDER.braille(char) for char in expected}, expected)

    def test_three_views(self):
        values = ("⣀", "▦⣶", "⡀", "⣷")
        resources = RENDER.compose("resources", "֍⣄3d4h", values, 120, 40)
        codex = RENDER.compose("codex", "֍⣄3d4h", values, 120, 40)
        combined = RENDER.compose("all", "֍⣄3d4h", values, 120, 40)
        self.assertNotEqual(resources, codex)
        self.assertNotEqual(combined, resources)

    def test_block_pixels_use_single_cells_and_stay_centered(self):
        art = RENDER.compose("all", "֍⣄3d4h", ("⣀", "▦⣶", "⡀", "⣷"), 120, 40)
        self.assertTrue(all(len(line) < 120 for line in art))
        self.assertTrue(all(line.startswith(" ") for line in art if line))

    def test_countdown_uses_pixelfont_and_keeps_columns_at_each_scale(self):
        expected_three = ("█████", "    █", " ████", "    █", "█████")
        expected_four = ("█   █", "█   █", "█████", "    █", "    █")
        for wide, tall, columns, lines in ((1, 1, 39, 10), (2, 1, 78, 24),
                                           (4, 2, 146, 13), (4, 2, 218, 11)):
            art = RENDER.compose("codex", "֍⣄3d4h", (), columns, lines)
            top = (lines - 5 * tall) // 2
            left = (columns - 34 * wide) // 2
            self.assertEqual(art[:top], [""] * top)
            self.assertEqual(len(art), top + 5 * tall)
            self.assertTrue(all(len(line) < columns for line in art))
            for offset, digit in ((11, expected_three), (23, expected_four)):
                start = left + offset * wide
                for row, pattern in enumerate(digit):
                    enlarged = "".join(pixel * wide for pixel in pattern)
                    for line in art[top + row * tall:top + (row + 1) * tall]:
                        self.assertEqual(line[start:start + 5 * wide].ljust(5 * wide), enlarged)

    def test_detailed_codex_has_separate_braille_dots_and_dotted_zero(self):
        rows = ["  ".join(row) for row in zip(*RENDER.codex_detail_tiles("⣷4d0h"))]
        self.assertEqual(len(rows), 14)
        self.assertEqual([row[9:16] for row in rows[::2]],
                         ["██     ", "       ", "██   ██", "       ",
                          "██   ██", "       ", "██   ██"])
        self.assertEqual(rows[6][36:43], "█  █  █")
        art = RENDER.compose("codex", "֍⣷4d0h", (), 156, 26)
        self.assertEqual(art[:6], [""] * 6)
        self.assertEqual(len(art), 20)
        self.assertEqual(art[6].count("█"), 4)
        self.assertEqual(len(RENDER.compose("codex", "֍⣷4d0h", (), 156, 14)), 12)

    def test_codex_swirl_is_smaller_and_centered_beside_digits(self):
        rows = ["  ".join(row) for row in zip(*RENDER.codex_detail_tiles("⣷4d0h"))]
        swirl = [row[:7] for row in rows]
        digit = [row[18:25] for row in rows]
        self.assertEqual([i for i, row in enumerate(swirl) if row.strip()], list(range(3, 10)))
        self.assertEqual([i for i, row in enumerate(digit) if row.strip()], list(range(1, 12)))
        self.assertEqual(swirl[5], "   █ ██")
        self.assertEqual(swirl[7], "██ █   ")

    def test_codex_uses_the_largest_logo_that_fits_without_shrinking_text(self):
        for columns, lines, scale, mask in (
            (109, 19, 1, RENDER.CODEX_LOGO_MASKS[2]),
            (213, 29, 2, RENDER.CODEX_LOGO_MASKS[1]),
            (319, 43, 3, RENDER.CODEX_LOGO_MASKS[0]),
        ):
            with self.subTest(columns=columns, lines=lines):
                art = RENDER.compose("codex", "֍⣷4d0h", (), columns, lines)
                bitmap = RENDER.bitmap(mask)
                left = (columns - len(bitmap[0]) - 90 * scale) // 2
                top = (lines - 14 * scale) // 2 + (14 * scale - len(bitmap)) // 2
                self.assertEqual(
                    tuple(line[left:left + len(bitmap[0])] for line in art[top:top + len(bitmap)]),
                    bitmap,
                )
                self.assertTrue(all(len(line) < columns for line in art))

    def test_codex_keeps_the_small_swirl_when_the_logo_cannot_fit(self):
        art = RENDER.compose("codex", "֍⣷4d0h", (), 108, 19)
        self.assertEqual(art[5][2:16], "  ████    ██  ")

    def test_codex_logo_grows_past_the_largest_native_mask(self):
        columns, lines, scale = 550, 76, 5
        art = RENDER.compose("codex", "֍⣷4d0h", (), columns, lines)
        logo = RENDER.codex_logo(9 * scale)
        left = (columns - 108 * scale) // 2
        top = (lines - 14 * scale) // 2 + (14 * scale - len(logo)) // 2
        self.assertEqual(len(logo), 45)
        self.assertEqual(tuple(row[left:left + 90] for row in art[top:top + 45]), logo)
        self.assertTrue(all(len(row) < columns for row in art))

    def test_combined_centers_the_detailed_logo_above_all_resources(self):
        values = ("⣀", "⣶", "⣄", "⣷")
        colors = ("93", "92", "92", "91", "92")
        for columns, lines, scale, resource_height in ((109, 24, 1, 5), (272, 54, 2, 9)):
            with self.subTest(columns=columns, lines=lines):
                art = RENDER.compose("all", "֍⣷4d0h", values, columns, lines, colors)
                plain = [re.sub(r"\x1b\[\d+m", "", row).rstrip() for row in art]
                top = (lines - (15 + resource_height) * scale) // 2
                separator = top + 14 * scale
                self.assertEqual(art[:top], [""] * top)
                self.assertEqual(art[separator:separator + scale], [""] * scale)
                self.assertEqual(len(art), top + (15 + resource_height) * scale)
                logo = RENDER.codex_logo(9 * scale)
                upper = [row for row in plain[top:separator] if row]
                lower = [row for row in plain[separator + scale:] if row]
                x = min(len(row) - len(row.lstrip()) for row in upper)
                self.assertEqual(x, min(len(row) - len(row.lstrip()) for row in lower))
                self.assertEqual(max(map(len, upper)), max(map(len, lower)))
                y = top + (14 * scale - len(logo)) // 2
                self.assertEqual(
                    tuple(row[x:x + len(logo[0])] for row in plain[y:y + len(logo)]),
                    logo,
                )
                self.assertTrue(all(len(row) < columns for row in plain))
                self.assertTrue(all(
                    set(re.findall(r"\x1b\[(9[0-3])m", row)) <= {"93"}
                    for row in art[top:separator]
                ))
                self.assertIn(list(colors[1:]), [
                    re.findall(r"\x1b\[(9[0-3])m", row) for row in art[separator + scale:]
                ])

    def test_combined_distributes_gap_cells_evenly_between_visible_tiles(self):
        upper = [(("██", None), (" █ ", None), ("███", None))]
        lower = [(("█", None), ("██", None), ("██", None), ("█", None))]
        art = RENDER.draw_combined(upper, lower, 20, 4, 1, 1, 2)
        self.assertEqual(art, ["  ██    █     ███", "", "  █   ██   ██   █"])

    def test_centered_codex_retains_its_color_after_empty_rows(self):
        colored = RENDER.compose("codex", "֍⣷4d0h", (), 120, 24,
                                 ("93", "90", "90", "90", "90"))
        self.assertEqual(colored[0], "")
        self.assertTrue(all(line.lstrip().startswith("\x1b[93m") for line in colored if line))

    def test_resource_label_does_not_shift_its_level(self):
        values = ("⣀", "⣶", "⡀", "⣷")
        art = RENDER.compose("resources", "", values, 60, 6)
        tagged = ("⣀", "R⣶", "⡀", "D⣷")
        self.assertEqual(art, RENDER.compose("resources", "", tagged, 60, 6))
        left = (60 - 49) // 2
        for index, char in enumerate(values):
            column = left + 13 * index + 8
            pixels = tuple(line[column:column + 2].ljust(2) for line in art[1:])
            self.assertEqual(pixels, RENDER.braille(char))

    def test_tile_does_not_double_empty_pixel_spacing(self):
        art = RENDER.tile("⣿")
        self.assertEqual(art, ["  ", "██", "██", "██", "██"])

    def test_missing_values_remain_visible_and_layouts_fit(self):
        missing = ("", "", "", "")
        self.assertTrue(any("█" in line for line in RENDER.tile("")))
        self.assertTrue(any("█" in line for line in RENDER.tile("⟳")))
        self.assertTrue(any("█" in line for line in RENDER.tile("OFF")))
        for width in (14, 28, 120):
            art = RENDER.compose("all", "֍dh", missing, width, 24)
            self.assertTrue(all(len(line) <= width for line in art))
        wide = RENDER.compose("resources", "", missing, 120, 40)
        narrow = RENDER.compose("resources", "", missing, 28, 40)
        self.assertTrue(all(len(line) <= 120 for line in wide))
        self.assertTrue(all(len(line) <= 28 for line in narrow))

    def test_resource_pairs_change_rows_at_terminal_width_threshold(self):
        values = ("⣀", "▦⣶", "⡀", "⣷")
        wide = RENDER.compose("resources", "", values, 240, 6)
        narrow = RENDER.compose("resources", "", values, 30, 12)
        compact = RENDER.compose("resources", "", values, 14, 12)
        self.assertEqual(len(wide), 5)
        self.assertEqual(len(narrow), 11)
        self.assertEqual([line.strip() for line in compact if line],
                         ["CPU ⣀", "RAM ⣶", "SWAP ⡀", "DISK ⣷"])

    def test_resources_center_color_each_metric_and_separate_dots(self):
        values = ("⣀", "⣶", "⣄", "⣷")
        colors = (None, "92", "93", "91", "90")
        art = RENDER.compose("resources", "", values, 160, 24, colors)
        self.assertEqual(art[:7], [""] * 7)
        self.assertEqual(len(art), 16)
        self.assertEqual(re.findall(r"\x1b\[(9[0-3])m", art[10]), list(colors[1:]))
        cpu = RENDER.resource_tile("CPU", "⣀")
        self.assertEqual([row[-3:] for row in cpu], ["   "] * 7 + ["█ █", "   "])

    def test_short_resource_window_packs_all_four_samples(self):
        values = ("⣀", "⣶", "⣄", "⣷")
        packed = RENDER.compose("resources", "", values, 10, 3)
        self.assertEqual([line.strip() for line in packed], ["C⣀  R⣶", "S⣄  D⣷"])
        labels = RENDER.compose("resources", "", values, 5, 2)
        self.assertEqual(labels, ["CRSD"])


if __name__ == "__main__":
    unittest.main()
