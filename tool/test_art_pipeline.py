#!/usr/bin/env python3
"""Regression tests for production-art preservation and packing contracts."""

from __future__ import annotations

import subprocess
import sys
import unittest
from copy import deepcopy
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from PIL import Image, ImageDraw

TOOL_DIR = Path(__file__).resolve().parent
ROOT = TOOL_DIR.parent
if str(TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_DIR))

import generate_portfolio_arcs as portfolio


SENTINEL = b"checked-in-production-art"
AUTHORED_PURPLE = (255, 64, 255, 255)


class _FakeAtlas:
    def save(self, target: Path, optimize: bool = True) -> None:
        del optimize
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(b"procedural-opponent")


class ArtPipelineTest(unittest.TestCase):
    def test_portfolio_specs_define_complete_unique_casts_and_rosters(self) -> None:
        specs = portfolio._load_specs(portfolio.DEFAULT_SPEC_DIR)
        self.assertEqual(len(specs), 9)
        for spec in specs:
            portfolio._validate_spec(spec)
            opponents = [
                opponent
                for chapter in spec["chapters"]
                for opponent in [*chapter["encounters"], chapter["boss"]]
            ]
            self.assertEqual(len(opponents), 24, spec["slug"])
            self.assertEqual(
                len({opponent["slug"] for opponent in opponents}),
                24,
                spec["slug"],
            )
            hero = portfolio._hero_descriptor(spec)
            self.assertTrue(hero["id"].startswith(f"{spec['slug']}/"))
            self.assertTrue(hero["storySpriteAsset"].endswith("_story_idle.png"))
            self.assertTrue(hero["combatSpriteAsset"].endswith("_combat.png"))
            self.assertTrue(hero["finisherSpriteAsset"].endswith("_finishers.png"))
        portfolio._validate_portfolio_identity(specs)

        invalid = deepcopy(specs[0])
        invalid["cast"][0]["slug"] = "../foreign-hero"
        with self.assertRaisesRegex(ValueError, "invalid slug"):
            portfolio._validate_spec(invalid)

    def test_portfolio_generator_preserves_and_explicitly_replaces_art(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            spec = _portfolio_spec()
            storefront, replaceable = _visual_targets(root, spec)
            self.assertEqual(len(storefront), 2)
            self.assertEqual(
                len(replaceable),
                34,
                "eight backgrounds, 24 opponents, and two finales",
            )
            for target in (*storefront, *replaceable):
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(SENTINEL)

            with _patched_generator(root):
                portfolio._generate_visual_assets(spec)
                self.assertTrue(
                    all(target.read_bytes() == SENTINEL for target in storefront)
                )
                self.assertTrue(
                    all(target.read_bytes() == SENTINEL for target in replaceable)
                )

                missing_background = replaceable[0]
                missing_opponent = replaceable[8]
                missing_background.unlink()
                missing_opponent.unlink()
                portfolio._generate_visual_assets(spec)
                self.assertEqual(
                    missing_background.read_bytes(), b"procedural-background"
                )
                self.assertEqual(
                    missing_opponent.read_bytes(), b"procedural-opponent"
                )
                for target in replaceable:
                    target.write_bytes(SENTINEL)

                portfolio._generate_visual_assets(spec, overwrite=True)
                self.assertTrue(
                    all(target.read_bytes() == SENTINEL for target in storefront)
                )
                self.assertTrue(
                    all(target.read_bytes() != SENTINEL for target in replaceable)
                )

    def test_storefront_hero_is_the_first_complete_story_frame(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            spec = _portfolio_spec()
            hero_slug = str(spec["cast"][0]["slug"])
            source_path = (
                root
                / portfolio._character_story_asset_path(
                    str(spec["slug"]), hero_slug
                )
            )
            source_path.parent.mkdir(parents=True, exist_ok=True)
            source = Image.new("RGBA", (768, 288), (0, 0, 0, 0))
            draw = ImageDraw.Draw(source)
            for column, color in enumerate(
                (
                    (220, 60, 90, 255),
                    (60, 180, 220, 255),
                    (230, 180, 40, 255),
                    (100, 60, 170, 255),
                )
            ):
                draw.rectangle(
                    (column * 192 + 16, 20, column * 192 + 175, 271),
                    fill=color,
                )
            source.save(source_path)

            with patch.object(portfolio, "ROOT", root):
                portfolio._export_storefront_hero(spec)

            target = (
                root
                / portfolio._storefront_hero_asset_path(
                    str(spec["slug"]), hero_slug
                )
            )
            exported = Image.open(target).convert("RGBA")
            self.assertEqual(exported.size, (192, 288))
            self.assertEqual(
                exported.tobytes(), source.crop((0, 0, 192, 288)).tobytes()
            )

    def test_story_packer_preserves_authored_purple_subject_pixels(self) -> None:
        with TemporaryDirectory() as directory:
            temp = Path(directory)
            source = Image.new("RGBA", (400, 120), (0, 0, 0, 0))
            draw = ImageDraw.Draw(source)
            colors = [
                AUTHORED_PURPLE,
                (40, 180, 220, 255),
                (230, 180, 40, 255),
                (100, 60, 170, 255),
            ]
            for column, color in enumerate(colors):
                left = column * 100 + 24
                draw.rectangle((left, 12, left + 52, 108), fill=color)
            input_path = temp / "story-source.png"
            output_path = temp / "story-strip.png"
            source.save(input_path)

            _run_tool(
                "pack_story_character_strip.py",
                "--input",
                input_path,
                "--out",
                output_path,
            )
            packed = Image.open(output_path).convert("RGBA")
            self.assertEqual(packed.size, (768, 288))
            self.assertEqual({pixel[3] for pixel in packed.getdata()}, {0, 255})
            self.assertGreater(
                sum(
                    1
                    for red, green, blue, alpha in packed.getdata()
                    if alpha and (red, green, blue) == AUTHORED_PURPLE[:3]
                ),
                0,
            )
            for column in range(4):
                cell = packed.crop((column * 192, 0, (column + 1) * 192, 288))
                self.assertIsNotNone(cell.getchannel("A").getbbox())

            source.putpixel((5, 5), (255, 255, 255, 1))
            source.save(input_path)
            _run_tool(
                "pack_story_character_strip.py",
                "--input",
                input_path,
                "--out",
                output_path,
            )
            noisy = Image.open(output_path).convert("RGBA")
            self.assertEqual(packed.tobytes(), noisy.tobytes())

    def test_opponent_normalizer_repositions_safe_cells_and_rejects_crops(self) -> None:
        with TemporaryDirectory() as directory:
            temp = Path(directory)
            source = Image.new("RGBA", (1024, 1536), (0, 0, 0, 0))
            draw = ImageDraw.Draw(source)
            for row in range(6):
                for column in range(4):
                    left = column * 256
                    top = row * 256
                    color = (
                        AUTHORED_PURPLE
                        if row == 0 and column == 0
                        else (40 + row * 20, 100 + column * 20, 180, 255)
                    )
                    draw.rectangle(
                        (left + 18, top + 20, left + 226, top + 230),
                        fill=color,
                    )
            input_path = temp / "opponent-source.png"
            output_path = temp / "opponent-atlas.png"
            source.save(input_path)

            _run_tool(
                "normalize_generated_opponent.py",
                "--input",
                input_path,
                "--out",
                output_path,
            )
            atlas = Image.open(output_path).convert("RGBA")
            self.assertEqual(atlas.size, (768, 1152))
            self.assertEqual({pixel[3] for pixel in atlas.getdata()}, {0, 255})
            self.assertGreater(
                sum(
                    1
                    for red, green, blue, alpha in atlas.getdata()
                    if alpha and (red, green, blue) == AUTHORED_PURPLE[:3]
                ),
                0,
            )
            _assert_empty_cell_gutters(self, atlas)

            source.putpixel((5, 5), (255, 255, 255, 1))
            source.save(input_path)
            _run_tool(
                "normalize_generated_opponent.py",
                "--input",
                input_path,
                "--out",
                output_path,
            )
            noisy = Image.open(output_path).convert("RGBA")
            self.assertEqual(atlas.tobytes(), noisy.tobytes())
            source.putpixel((5, 5), (0, 0, 0, 0))

            ImageDraw.Draw(source).rectangle((0, 80, 2, 130), fill=(255, 220, 80, 255))
            source.save(input_path)
            failed = _run_tool(
                "normalize_generated_opponent.py",
                "--input",
                input_path,
                "--out",
                output_path,
                check=False,
            )
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn(
                "crosses its natural cell gutter", failed.stdout + failed.stderr
            )

    def test_hero_normalizer_packs_the_combat_and_finisher_abis(self) -> None:
        with TemporaryDirectory() as directory:
            temp = Path(directory)
            combat_source = _hero_source(
                columns=8,
                rows=4,
                active_cells={
                    (row, column)
                    for row in range(4)
                    for column in range(8)
                    if row < 3 or column < 4
                },
            )
            combat_input = temp / "hero-combat-source.png"
            combat_output = temp / "hero-combat.png"
            combat_source.save(combat_input)

            _run_tool(
                "normalize_generated_hero_atlas.py",
                "--input",
                combat_input,
                "--out",
                combat_output,
                "--kind",
                "combat",
            )
            combat = Image.open(combat_output).convert("RGBA")
            combat_x = (0, 240, 490, 685, 900, 1110, 1310, 1520, 1774)
            combat_y = (0, 220, 415, 605, 887)
            combat_cells = {
                (row, column)
                for row in range(4)
                for column in range(8)
                if row < 3 or column < 4
            }
            self.assertEqual(combat.size, (1774, 887))
            _assert_hard_alpha(self, combat)
            _assert_cell_occupancy(
                self,
                combat,
                x_boundaries=combat_x,
                y_boundaries=combat_y,
                active_cells=combat_cells,
            )
            _assert_cell_gutters(
                self,
                combat,
                x_boundaries=combat_x,
                y_boundaries=combat_y,
                active_cells=combat_cells,
                gutter=10,
            )

            combat_source.putpixel((5, 5), (255, 255, 255, 1))
            combat_source.save(combat_input)
            _run_tool(
                "normalize_generated_hero_atlas.py",
                "--input",
                combat_input,
                "--out",
                combat_output,
                "--kind",
                "combat",
            )
            noisy_combat = Image.open(combat_output).convert("RGBA")
            self.assertEqual(combat.tobytes(), noisy_combat.tobytes())
            combat_source.putpixel((5, 5), (0, 0, 0, 0))

            finisher_source = _hero_source(
                columns=6,
                rows=8,
                active_cells={
                    (row, column)
                    for row in range(8)
                    for column in range(6)
                },
            )
            finisher_input = temp / "hero-finisher-source.png"
            finisher_output = temp / "hero-finishers.png"
            finisher_source.save(finisher_input)

            _run_tool(
                "normalize_generated_hero_atlas.py",
                "--input",
                finisher_input,
                "--out",
                finisher_output,
                "--kind",
                "finishers",
            )
            finishers = Image.open(finisher_output).convert("RGBA")
            finisher_x = tuple(index * 296 for index in range(7))
            finisher_y = tuple(index * 296 for index in range(9))
            finisher_cells = {
                (row, column)
                for row in range(8)
                for column in range(6)
            }
            self.assertEqual(finishers.size, (1776, 2368))
            _assert_hard_alpha(self, finishers)
            _assert_cell_occupancy(
                self,
                finishers,
                x_boundaries=finisher_x,
                y_boundaries=finisher_y,
                active_cells=finisher_cells,
            )
            _assert_cell_gutters(
                self,
                finishers,
                x_boundaries=finisher_x,
                y_boundaries=finisher_y,
                active_cells=finisher_cells,
                gutter=24,
            )

            ImageDraw.Draw(combat_source).rectangle(
                (0, 20, 2, 70), fill=(255, 220, 80, 255)
            )
            combat_source.save(combat_input)
            failed = _run_tool(
                "normalize_generated_hero_atlas.py",
                "--input",
                combat_input,
                "--out",
                combat_output,
                "--kind",
                "combat",
                check=False,
            )
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn(
                "crosses its natural cell gutter", failed.stdout + failed.stderr
            )

    def test_hero_row_packer_can_opt_into_genuine_tight_separators(self) -> None:
        with TemporaryDirectory() as directory:
            temp = Path(directory)
            row_inputs: list[Path] = []
            for row in range(8):
                source = Image.new("RGBA", (600, 100), (0, 0, 0, 0))
                draw = ImageDraw.Draw(source)
                for column in range(6):
                    draw.rectangle(
                        (
                            column * 100 + 1,
                            8,
                            (column + 1) * 100 - 2,
                            91,
                        ),
                        fill=(40 + row * 18, 90 + column * 12, 180, 255),
                    )
                row_path = temp / f"finisher-row-{row}.png"
                source.save(row_path)
                row_inputs.append(row_path)

            output = temp / "hero-finishers.png"
            arguments: list[object] = []
            for row_input in row_inputs:
                arguments.extend(("--row-input", row_input))
            strict = _run_tool(
                "normalize_generated_hero_atlas.py",
                *arguments,
                "--out",
                output,
                "--kind",
                "finishers",
                check=False,
            )
            self.assertNotEqual(strict.returncode, 0)
            self.assertIn(
                "no transparent separator", strict.stdout + strict.stderr
            )

            _run_tool(
                "normalize_generated_hero_atlas.py",
                *arguments,
                "--out",
                output,
                "--kind",
                "finishers",
                "--allow-tight-row-gaps",
            )
            finishers = Image.open(output).convert("RGBA")
            finisher_x = tuple(index * 296 for index in range(7))
            finisher_y = tuple(index * 296 for index in range(9))
            active_cells = {
                (row, column)
                for row in range(8)
                for column in range(6)
            }
            self.assertEqual(finishers.size, (1776, 2368))
            _assert_hard_alpha(self, finishers)
            _assert_cell_occupancy(
                self,
                finishers,
                x_boundaries=finisher_x,
                y_boundaries=finisher_y,
                active_cells=active_cells,
            )
            _assert_cell_gutters(
                self,
                finishers,
                x_boundaries=finisher_x,
                y_boundaries=finisher_y,
                active_cells=active_cells,
                gutter=24,
            )

    def test_character_mentions_match_names_as_words(self) -> None:
        spec = {
            "slug": "sun-sail-covenant",
            "cast": [
                {"slug": "nera-venn", "name": "Nera Venn", "role": "Courier"},
                {"slug": "kest-arlo", "name": "Kest Arlo", "role": "Pilot"},
                {"slug": "tor-axiom", "name": "Tor Axiom", "role": "Envoy"},
            ],
        }
        unrelated = portfolio._character_layers_for_text(
            spec,
            "The storm-torn observatories watch a reactor flare.",
        )
        self.assertEqual([layer["id"] for layer in unrelated], ["nera-venn"])

        mentioned = portfolio._character_layers_for_text(
            spec,
            "Tor's warning sends Nera toward the harbor.",
        )
        self.assertEqual(
            [layer["id"] for layer in mentioned],
            ["nera-venn", "tor-axiom"],
        )

        tide = next(
            spec
            for spec in portfolio._load_specs(portfolio.DEFAULT_SPEC_DIR)
            if spec["slug"] == "steal-the-seventh-tide"
        )
        crew_scene = " ".join(tide["chapters"][0]["paragraphs"])
        self.assertEqual(
            [
                layer["id"]
                for layer in portfolio._character_layers_for_text(
                    tide, crew_scene
                )
            ],
            ["selke-marr", "nima-coral", "iri-sable", "jory-venn"],
        )


def _portfolio_spec() -> dict[str, object]:
    families = sorted(portfolio.FAMILIES)
    return {
        "slug": "sun-sail-covenant",
        "storefront": {},
        "cast": [{"slug": "test-hero"}],
        "chapters": [
            {
                "slug": f"chapter-{index}",
                "primaryColor": "#112233",
                "secondaryColor": "#ddeeff",
                "encounters": [
                    {
                        "slug": f"encounter-{index}-{encounter_index}",
                        "name": f"Encounter {index}-{encounter_index}",
                        "family": families[
                            (index + encounter_index + 1) % len(families)
                        ],
                        "visualDescription": "A complete authored opponent.",
                    }
                    for encounter_index in range(2)
                ],
                "boss": {
                    "slug": f"boss-{index}",
                    "name": f"Boss {index}",
                    "family": families[index],
                },
            }
            for index in range(8)
        ],
    }


def _visual_targets(
    root: Path, spec: dict[str, object]
) -> tuple[list[Path], list[Path]]:
    slug = str(spec["slug"])
    chapters = spec["chapters"]
    assert isinstance(chapters, list)
    storefront = [
        root / "assets" / "storefront" / slug / "prologue.jpg",
        root / "assets" / "storefront" / slug / "tile.jpg",
    ]
    backgrounds = [
        root
        / portfolio._chapter_background_path(
            slug, index, str(chapter["slug"])
        )
        for index, chapter in enumerate(chapters)
    ]
    opponents = []
    for chapter in chapters:
        chapter_opponents = [*chapter["encounters"], chapter["boss"]]
        opponents.extend(
            root
            / "assets"
            / "art"
            / "arcs"
            / slug
            / "combat"
            / "opponents"
            / f"{opponent['slug']}.png"
            for opponent in chapter_opponents
        )
    finales = [
        root / portfolio._finale_background_path(slug, resolved=False),
        root / portfolio._finale_background_path(slug, resolved=True),
    ]
    return storefront, [*backgrounds, *opponents, *finales]


def _patched_generator(root: Path):
    def save_background(_source, target: Path, _size) -> None:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(b"procedural-background")

    return patch.multiple(
        portfolio,
        ROOT=root,
        _paint_environment=lambda *args, **kwargs: object(),
        _save_scaled_jpeg=save_background,
        _paint_creature=lambda *args, **kwargs: object(),
        _build_reaction_atlas=lambda *args, **kwargs: _FakeAtlas(),
    )


def _run_tool(
    script: str, *arguments: object, check: bool = True
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(ROOT / "tool" / script), *map(str, arguments)],
        cwd=ROOT,
        check=check,
        capture_output=True,
        text=True,
    )


def _assert_empty_cell_gutters(
    test: unittest.TestCase, atlas: Image.Image
) -> None:
    alpha = atlas.getchannel("A")
    for row in range(6):
        for column in range(4):
            left = column * 192
            top = row * 192
            for y in range(192):
                for x in range(192):
                    in_gutter = x < 8 or x >= 184 or y < 8 or y >= 184
                    if in_gutter:
                        test.assertEqual(alpha.getpixel((left + x, top + y)), 0)


def _hero_source(
    *, columns: int, rows: int, active_cells: set[tuple[int, int]]
) -> Image.Image:
    cell_size = 100
    source = Image.new(
        "RGBA", (columns * cell_size, rows * cell_size), (0, 0, 0, 0)
    )
    draw = ImageDraw.Draw(source)
    for row, column in active_cells:
        color = (
            AUTHORED_PURPLE
            if row == 0 and column == 0
            else (40 + row * 18, 90 + column * 12, 180, 255)
        )
        left = column * cell_size
        top = row * cell_size
        draw.rectangle(
            (left + 12, top + 10, left + 86, top + 88),
            fill=color,
        )
    return source


def _assert_hard_alpha(test: unittest.TestCase, atlas: Image.Image) -> None:
    test.assertEqual(set(atlas.getchannel("A").getdata()), {0, 255})


def _assert_cell_occupancy(
    test: unittest.TestCase,
    atlas: Image.Image,
    *,
    x_boundaries: tuple[int, ...],
    y_boundaries: tuple[int, ...],
    active_cells: set[tuple[int, int]],
) -> None:
    alpha = atlas.getchannel("A")
    for row in range(len(y_boundaries) - 1):
        for column in range(len(x_boundaries) - 1):
            bounds = (
                x_boundaries[column],
                y_boundaries[row],
                x_boundaries[column + 1],
                y_boundaries[row + 1],
            )
            occupied = alpha.crop(bounds).getbbox() is not None
            test.assertEqual(
                occupied,
                (row, column) in active_cells,
                f"unexpected occupancy for row {row}, frame {column}",
            )


def _assert_cell_gutters(
    test: unittest.TestCase,
    atlas: Image.Image,
    *,
    x_boundaries: tuple[int, ...],
    y_boundaries: tuple[int, ...],
    active_cells: set[tuple[int, int]],
    gutter: int,
) -> None:
    alpha = atlas.getchannel("A")
    for row, column in active_cells:
        left = x_boundaries[column]
        right = x_boundaries[column + 1]
        top = y_boundaries[row]
        bottom = y_boundaries[row + 1]
        gutter_regions = (
            (left, top, right, top + gutter),
            (left, bottom - gutter, right, bottom),
            (left, top, left + gutter, bottom),
            (right - gutter, top, right, bottom),
        )
        for bounds in gutter_regions:
            test.assertIsNone(
                alpha.crop(bounds).getbbox(),
                f"row {row}, frame {column} crosses its output gutter",
            )


if __name__ == "__main__":
    unittest.main()
