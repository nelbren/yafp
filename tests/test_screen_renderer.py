import importlib.util
import re
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location(
    "yafp_screen_renderer", ROOT / "scripts/unix/screen/render.py"
)
RENDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RENDER)


class ScreenRendererTests(unittest.TestCase):
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
