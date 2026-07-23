#!/usr/bin/env python3
"""Build playable portfolio arc packages from the checked-in source specs.

The source specs contain authored story copy and visual direction. This tool
turns them into runtime metadata and validated puzzle catalogs, and fills any
missing visual slots with compact procedural pixel-art fallbacks. Existing
production artwork is preserved unless procedural replacement is explicitly
requested. Generated package files are committed so release builds never need
Python or Pillow.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SPEC_DIR = ROOT / "tool" / "story_arc_specs"
PORTFOLIO_ORDER = [
    "sun-sail-covenant",
    "where-the-rain-trees-walk",
    "oathstorm-fleet",
    "crimson-ledger",
    "atlas-of-borrowed-winds",
    "treaty-written-in-thorns",
    "inn-at-the-end-of-yesterday",
    "ninth-library",
    "shepherds-of-the-thunderwild",
    "steal-the-seventh-tide",
]
CHAPTER_DIFFICULTIES = [
    "easy",
    "easy",
    "medium",
    "medium",
    "hard",
    "hard",
    "expert",
    "expert",
]
CHAPTER_SIZES = [6, 7, 7, 8, 8, 9, 9, 10]
BOSS_DIFFICULTIES = [
    "easy",
    "medium",
    "medium",
    "hard",
    "hard",
    "expert",
    "expert",
    "expert",
]
BOSS_SIZES = [7, 7, 8, 8, 9, 9, 10, 12]
FINISHER_TRACKS = [
    "crownSlash",
    "tidalAegis",
    "twinSigil",
    "moonlitSever",
    "brassJudgment",
    "cinderfall",
    "skybreak",
    "regaliaNova",
]
STANDARD_MAP_LAYOUT = {
    "columns": 3,
    "pattern": "snake",
    "direction": "leftToRight",
}
FAMILIES = {
    "antlered",
    "rootbound",
    "winged",
    "abyssal",
    "volcanic",
    "clockwork",
    "spectral",
    "cosmic",
}
ENCOUNTER_ORDER_OFFSETS = (2, 5)
CHARACTER_LAYOUTS = {
    1: ((-0.52, 0.68, False),),
    2: ((-0.58, 0.7, False), (0.58, 0.7, True)),
    3: ((-0.66, 0.72, False), (0.0, 0.64, False), (0.66, 0.72, True)),
    4: (
        (-0.78, 0.74, False),
        (-0.28, 0.65, False),
        (0.28, 0.65, True),
        (0.78, 0.74, True),
    ),
}
SLUG_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec-dir", type=Path, default=DEFAULT_SPEC_DIR)
    parser.add_argument("--only", action="append", default=[])
    parser.add_argument("--skip-puzzles", action="store_true")
    parser.add_argument("--skip-assets", action="store_true")
    parser.add_argument(
        "--force-procedural-art",
        action="store_true",
        help=(
            "replace existing chapter, finale, and opponent art with the "
            "deterministic procedural fallbacks"
        ),
    )
    args = parser.parse_args()

    specs = _load_specs(args.spec_dir)
    if args.only:
        selected = set(args.only)
        specs = [spec for spec in specs if spec["slug"] in selected]
        missing = selected.difference(spec["slug"] for spec in specs)
        if missing:
            raise ValueError(f"unknown requested specs: {sorted(missing)}")
    if not specs:
        raise ValueError("no portfolio story specs found")

    for spec in specs:
        _validate_spec(spec)
    _validate_portfolio_identity(specs)

    for spec in specs:
        print(f"Building {spec['title']}...")
        if not args.skip_assets:
            _generate_visual_assets(
                spec, overwrite=args.force_procedural_art
            )
        if not args.skip_puzzles:
            _generate_catalog(spec)
        _write_arc_metadata(spec)

    # Only a complete run owns the common manifest. Targeted runs are useful
    # while iterating art or one package and must not remove sibling entries.
    if not args.only:
        _write_manifest(specs)
    print(f"Built {len(specs)} portfolio arc package(s).")


def _load_specs(spec_dir: Path) -> list[dict[str, Any]]:
    specs = []
    for path in sorted(spec_dir.glob("*.json")):
        with path.open(encoding="utf-8") as source:
            value = json.load(source)
        if not isinstance(value, dict):
            raise ValueError(f"{path} must contain a JSON object")
        value["_source"] = str(path.relative_to(ROOT))
        specs.append(value)
    order = {slug: index for index, slug in enumerate(PORTFOLIO_ORDER)}
    specs.sort(key=lambda spec: order.get(spec.get("slug", ""), 10_000))
    return specs


def _validate_spec(spec: dict[str, Any]) -> None:
    label = spec.get("_source", "story spec")
    required = {
        "slug",
        "title",
        "contentVersion",
        "tagline",
        "environment",
        "seed",
        "theme",
        "storefront",
        "cast",
        "chapters",
        "finaleFrames",
    }
    missing = required.difference(spec)
    if missing:
        raise ValueError(f"{label} is missing {sorted(missing)}")
    content_version = spec["contentVersion"]
    if (
        isinstance(content_version, bool)
        or not isinstance(content_version, int)
        or content_version < 1
    ):
        raise ValueError(f"{label} must define a positive integer contentVersion")
    slug = spec["slug"]
    if slug not in PORTFOLIO_ORDER or slug == "atlas-of-borrowed-winds":
        raise ValueError(f"{label} has unsupported slug {slug!r}")
    chapters = spec["chapters"]
    if not isinstance(chapters, list) or len(chapters) != 8:
        raise ValueError(f"{label} must define exactly eight chapters")
    cast = spec["cast"]
    if not isinstance(cast, list) or not 2 <= len(cast) <= 4:
        raise ValueError(f"{label} must define two to four main characters")
    character_slugs: set[str] = set()
    character_names: set[str] = set()
    for index, character in enumerate(cast):
        if not isinstance(character, dict):
            raise ValueError(f"{label} cast entry {index + 1} must be an object")
        for key in ("slug", "name", "role", "visualDescription", "chromaKey"):
            if not isinstance(character.get(key), str) or not character[key].strip():
                raise ValueError(f"{label} cast entry {index + 1} needs {key}")
        if not SLUG_PATTERN.fullmatch(character["slug"]):
            raise ValueError(
                f"{label} cast entry {index + 1} has invalid slug "
                f"{character['slug']}"
            )
        if character["slug"] in character_slugs:
            raise ValueError(f"{label} repeats character slug {character['slug']}")
        folded_name = character["name"].casefold()
        if folded_name in character_names:
            raise ValueError(f"{label} repeats character name {character['name']}")
        character_slugs.add(character["slug"])
        character_names.add(folded_name)
        _parse_hex(character["chromaKey"])

    families = []
    ids: set[str] = set()
    opponent_slugs: set[str] = set()
    opponent_names: set[str] = set()
    for index, chapter in enumerate(chapters):
        _require_story_frame(chapter, f"{label} chapter {index + 1}")
        chapter_slug = chapter.get("slug")
        if not isinstance(chapter_slug, str) or not chapter_slug:
            raise ValueError(f"{label} chapter {index + 1} needs a slug")
        if chapter_slug in ids:
            raise ValueError(f"{label} repeats chapter slug {chapter_slug}")
        ids.add(chapter_slug)
        boss = chapter.get("boss")
        if not isinstance(boss, dict):
            raise ValueError(f"{label} chapter {index + 1} needs a boss")
        for key in ("slug", "name", "family", "moveName"):
            if not isinstance(boss.get(key), str) or not boss[key].strip():
                raise ValueError(f"{label} chapter {index + 1} boss needs {key}")
        if boss["family"] not in FAMILIES:
            raise ValueError(f"{label} has unknown boss family {boss['family']}")
        _register_opponent_identity(
            label,
            boss,
            slugs=opponent_slugs,
            names=opponent_names,
        )
        families.append(boss["family"])
        if boss["name"] not in " ".join(chapter["paragraphs"]):
            raise ValueError(
                f"{label} chapter {index + 1} copy must introduce {boss['name']}"
            )
        for key in ("primaryColor", "secondaryColor"):
            _parse_hex(chapter[key])
        encounters = chapter.get("encounters")
        if not isinstance(encounters, list) or len(encounters) != 2:
            raise ValueError(
                f"{label} chapter {index + 1} must define exactly two encounters"
            )
        for encounter_index, encounter in enumerate(encounters):
            if not isinstance(encounter, dict):
                raise ValueError(
                    f"{label} chapter {index + 1} encounter "
                    f"{encounter_index + 1} must be an object"
                )
            for key in ("slug", "name", "family"):
                if not isinstance(encounter.get(key), str) or not encounter[key].strip():
                    raise ValueError(
                        f"{label} chapter {index + 1} encounter "
                        f"{encounter_index + 1} needs {key}"
                    )
            description = encounter.get(
                "visualDescription", encounter.get("description")
            )
            if not isinstance(description, str) or not description.strip():
                raise ValueError(
                    f"{label} chapter {index + 1} encounter "
                    f"{encounter_index + 1} needs a visual description"
                )
            if encounter["family"] not in FAMILIES:
                raise ValueError(
                    f"{label} has unknown encounter family {encounter['family']}"
                )
            _register_opponent_identity(
                label,
                encounter,
                slugs=opponent_slugs,
                names=opponent_names,
            )
    if set(families) != FAMILIES:
        raise ValueError(f"{label} must use every combat family exactly once")
    storefront = spec["storefront"]
    if not isinstance(storefront, dict):
        raise ValueError(f"{label} storefront must be an object")
    frames = storefront.get("prologueFrames")
    if not isinstance(frames, list) or len(frames) != 3:
        raise ValueError(f"{label} prologue must contain exactly three frames")
    for index, frame in enumerate(frames):
        _require_story_frame(frame, f"{label} prologue frame {index + 1}")
    finale = spec["finaleFrames"]
    if not isinstance(finale, list) or len(finale) != 2:
        raise ValueError(f"{label} finale must contain exactly two frames")
    for index, frame in enumerate(finale):
        _require_story_frame(frame, f"{label} finale frame {index + 1}")
    theme = spec["theme"]
    theme_colors = {}
    for key in (
        "backgroundColor",
        "surfaceColor",
        "surfaceLowColor",
        "surfaceHighColor",
        "surfaceContainerHighColor",
        "foregroundColor",
        "mutedForegroundColor",
        "outlineColor",
        "outlineVariantColor",
        "inkColor",
        "dangerColor",
    ):
        theme_colors[key] = _parse_hex(theme[key])
    if theme.get("brightness") not in {"light", "dark"}:
        raise ValueError(f"{label} has invalid brightness")
    if _relative_luminance(theme_colors["inkColor"]) >= 0.15:
        raise ValueError(f"{label} inkColor must remain a dark shadow and scrim")
    for surface_key in (
        "backgroundColor",
        "surfaceColor",
        "surfaceLowColor",
        "surfaceHighColor",
        "surfaceContainerHighColor",
    ):
        if (
            _contrast_ratio(
                theme_colors["outlineVariantColor"], theme_colors[surface_key]
            )
            < 3
        ):
            raise ValueError(
                f"{label} outlineVariantColor needs 3:1 contrast on {surface_key}"
            )


def _register_opponent_identity(
    label: str,
    opponent: dict[str, Any],
    *,
    slugs: set[str],
    names: set[str],
) -> None:
    slug = opponent["slug"]
    name = opponent["name"]
    if slug in slugs:
        raise ValueError(f"{label} repeats opponent slug {slug}")
    if name.casefold() in names:
        raise ValueError(f"{label} repeats opponent name {name}")
    slugs.add(slug)
    names.add(name.casefold())


def _validate_portfolio_identity(specs: list[dict[str, Any]]) -> None:
    opponent_names: dict[str, str] = {}
    opponent_slugs: dict[str, str] = {}
    for spec in specs:
        slug = spec["slug"]
        for chapter in spec["chapters"]:
            for opponent in [*chapter["encounters"], chapter["boss"]]:
                folded_name = opponent["name"].casefold()
                previous_name = opponent_names.get(folded_name)
                if previous_name is not None:
                    raise ValueError(
                        f"opponent name {opponent['name']} is shared by "
                        f"{previous_name} and {slug}"
                    )
                previous_slug = opponent_slugs.get(opponent["slug"])
                if previous_slug is not None:
                    raise ValueError(
                        f"opponent slug {opponent['slug']} is shared by "
                        f"{previous_slug} and {slug}"
                    )
                opponent_names[folded_name] = slug
                opponent_slugs[opponent["slug"]] = slug


def _require_story_frame(frame: dict[str, Any], label: str) -> None:
    for key in ("title", "semanticLabel", "actionLabel"):
        if not isinstance(frame.get(key), str) or not frame[key].strip():
            raise ValueError(f"{label} needs non-empty {key}")
    paragraphs = frame.get("paragraphs")
    if (
        not isinstance(paragraphs, list)
        or len(paragraphs) != 2
        or any(not isinstance(value, str) or not value.strip() for value in paragraphs)
    ):
        raise ValueError(f"{label} needs exactly two non-empty paragraphs")


def _generate_catalog(spec: dict[str, Any]) -> None:
    slug = spec["slug"]
    target = ROOT / "assets" / "content" / "arcs" / slug / "catalog.json"
    report = ROOT / "tmp" / "portfolio-arcs" / slug / "validation-report.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "dart",
        "run",
        "tool/generate_puzzles.dart",
        "generate",
        "--catalog",
        str(target.relative_to(ROOT)),
        "--report",
        str(report.relative_to(ROOT)),
        "--seed",
        str(spec["seed"]),
    ]
    subprocess.run(command, cwd=ROOT, check=True)
    _namespace_catalog(spec, target)


def _namespace_catalog(spec: dict[str, Any], target: Path) -> None:
    """Assign an authored arc's durable puzzle and boss IDs to a catalog."""
    slug = spec["slug"]
    with target.open(encoding="utf-8") as source:
        catalog = json.load(source)
    puzzles = catalog.get("puzzles")
    if not isinstance(puzzles, list) or len(puzzles) != 72:
        raise ValueError(f"generator produced an invalid catalog for {slug}")
    bosses = {
        (index + 1) * 9: chapter["boss"]["slug"]
        for index, chapter in enumerate(spec["chapters"])
    }
    for puzzle in puzzles:
        order = puzzle["order"]
        if order in bosses:
            puzzle["id"] = f"regalia:puzzle/{slug}/boss/{bosses[order]}"
        else:
            puzzle["id"] = puzzle["id"].replace(
                "regalia:puzzle/origin/", f"regalia:puzzle/{slug}/", 1
            )
    _write_json(target, catalog)


def _write_arc_metadata(spec: dict[str, Any]) -> None:
    slug = spec["slug"]
    arc_id = f"regalia:arc/{slug}"
    map_id = f"regalia:map/{slug}/main-route"
    finale_unlock = f"regalia:unlock/{slug}/finale"
    puzzle_ids = _catalog_puzzle_ids_by_order(slug)
    chapters = []
    scenes = []
    for index, source in enumerate(spec["chapters"]):
        chapter_id = f"regalia:chapter/{slug}/{source['slug']}"
        scene_id = f"regalia:scene/{slug}/{source['slug']}"
        boss = source["boss"]
        background = _chapter_background_path(slug, index, source["slug"])
        next_unlock = (
            f"regalia:chapter/{slug}/{spec['chapters'][index + 1]['slug']}"
            if index + 1 < len(spec["chapters"])
            else finale_unlock
        )
        encounters = []
        for encounter, offset in zip(
            source["encounters"], ENCOUNTER_ORDER_OFFSETS
        ):
            puzzle_order = index * 9 + offset + 1
            encounters.append(
                {
                    "id": f"regalia:enemy/{slug}/{encounter['slug']}",
                    "name": encounter["name"],
                    "puzzleId": puzzle_ids[puzzle_order],
                    "spriteFamily": encounter["family"],
                    "spriteAsset": _opponent_asset_path(
                        slug, encounter["slug"]
                    ),
                }
            )
        chapters.append(
            {
                "id": chapter_id,
                "mapId": map_id,
                "sceneId": scene_id,
                "artKey": source["slug"],
                "artAsset": background,
                "visualIndex": index,
                "title": source["title"],
                "caption": source["caption"],
                "startOrder": index * 9 + 1,
                "endOrder": (index + 1) * 9,
                "difficulty": CHAPTER_DIFFICULTIES[index],
                "size": CHAPTER_SIZES[index],
                "mapLayout": STANDARD_MAP_LAYOUT.copy(),
                "boss": {
                    "id": f"regalia:boss/{slug}/{boss['slug']}",
                    "name": boss["name"],
                    "puzzleId": f"regalia:puzzle/{slug}/boss/{boss['slug']}",
                    "spriteFamily": boss["family"],
                    "spriteAsset": (
                        f"assets/art/arcs/{slug}/combat/opponents/"
                        f"{boss['slug']}.png"
                    ),
                    "spectacleLevel": index + 1,
                    "finisher": {
                        "track": FINISHER_TRACKS[index],
                        "moveName": boss["moveName"],
                        "effectLevel": index + 1,
                    },
                    "size": BOSS_SIZES[index],
                    "targetDifficulty": BOSS_DIFFICULTIES[index],
                    "unlocks": next_unlock,
                },
                "encounters": encounters,
                "primaryColor": source["primaryColor"],
                "secondaryColor": source["secondaryColor"],
            }
        )
        scenes.append(
            {
                "id": scene_id,
                "role": "chapter",
                "defaults": {
                    "background": {"asset": background, "fit": "cover"},
                    "characters": _character_layers_for_text(
                        spec,
                        " ".join(
                            [
                                source["caption"],
                                *source["paragraphs"],
                                source["semanticLabel"],
                            ]
                        ),
                    ),
                },
                "frames": [
                    {
                        "id": f"chapter-{index + 1}-arrival",
                        "title": source["title"],
                        "paragraphs": source["paragraphs"],
                        "semanticLabel": source["semanticLabel"],
                        "actionLabel": source["actionLabel"],
                    }
                ],
            }
        )
    finale_frames = []
    for index, source in enumerate(spec["finaleFrames"]):
        frame = {
            "id": source.get("id", f"finale-{index + 1}"),
            "title": source["title"],
            "paragraphs": source["paragraphs"],
            "semanticLabel": source["semanticLabel"],
            "actionLabel": source["actionLabel"],
        }
        if index == 1:
            frame["background"] = {
                "asset": _finale_background_path(slug, resolved=True),
                "fit": "cover",
            }
        finale_frames.append(frame)
    scenes.append(
        {
            "id": f"regalia:scene/{slug}/finale",
            "role": "finale",
            "defaults": {
                "background": {
                    "asset": _finale_background_path(slug, resolved=False),
                    "fit": "cover",
                },
                "characters": _character_layers(spec, spec["cast"]),
            },
            "frames": finale_frames,
        }
    )
    metadata = {
        "schemaVersion": 1,
        "id": arc_id,
        "contentVersion": spec["contentVersion"],
        "title": spec["title"],
        "hero": _hero_descriptor(spec),
        "theme": spec["theme"],
        "mapId": map_id,
        "puzzleCatalogAsset": f"assets/content/arcs/{slug}/catalog.json",
        "unlocks": {
            "fullMap": f"regalia:unlock/{slug}/full-map",
            "finale": finale_unlock,
        },
        "chapters": chapters,
        "scenes": scenes,
    }
    target = ROOT / "assets" / "content" / "arcs" / slug / "arc.json"
    _write_json(target, metadata)


def _catalog_puzzle_ids_by_order(slug: str) -> dict[int, str]:
    path = ROOT / "assets" / "content" / "arcs" / slug / "catalog.json"
    with path.open(encoding="utf-8") as source:
        catalog = json.load(source)
    puzzles = catalog.get("puzzles")
    if not isinstance(puzzles, list) or len(puzzles) != 72:
        raise ValueError(f"{path} must contain 72 puzzles before metadata is built")
    return {puzzle["order"]: puzzle["id"] for puzzle in puzzles}


def _hero_descriptor(spec: dict[str, Any]) -> dict[str, Any]:
    slug = spec["slug"]
    hero = spec["cast"][0]
    return {
        "id": f"{slug}/{hero['slug']}",
        "name": hero["name"],
        "semanticLabel": f"{hero['name']}, {hero['role']}",
        "storySpriteAsset": _character_story_asset_path(slug, hero["slug"]),
        "combatSpriteAsset": _character_combat_asset_path(slug, hero["slug"]),
        "finisherSpriteAsset": _character_finisher_asset_path(
            slug, hero["slug"]
        ),
    }


def _character_layers_for_text(
    spec: dict[str, Any], text: str
) -> list[dict[str, Any]]:
    folded = text.casefold()
    selected = [
        character
        for character in spec["cast"]
        if re.search(
            rf"(?<![a-z0-9])"
            rf"{re.escape(character['name'].split()[0].casefold())}"
            rf"(?![a-z0-9])",
            folded,
        )
    ]
    if not selected:
        selected = [spec["cast"][0]]
    return _character_layers(spec, selected)


def _character_layers(
    spec: dict[str, Any], characters: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    slug = spec["slug"]
    layout = CHARACTER_LAYOUTS[len(characters)]
    layers = []
    for index, (character, placement) in enumerate(zip(characters, layout)):
        x, y, mirrored = placement
        layers.append(
            {
                "id": character["slug"],
                "source": {
                    "type": "asset",
                    "asset": _character_story_asset_path(
                        slug, character["slug"]
                    ),
                },
                "alignment": {"x": x, "y": y},
                "size": {"width": 112, "height": 168},
                "mirrored": mirrored,
                "semanticLabel": (
                    f"{character['name']}, {character['role']}"
                ),
                "zOrder": index + 1,
                "animation": {
                    "frameCount": 4,
                    "columns": 4,
                    "rows": 1,
                    "frameDurationMs": 190,
                    "loop": False,
                    "reducedMotion": "firstFrame",
                },
            }
        )
    return layers


def _write_manifest(specs: list[dict[str, Any]]) -> None:
    target = ROOT / "assets" / "content" / "manifest.json"
    with target.open(encoding="utf-8") as source:
        manifest = json.load(source)
    existing = {entry["arcId"].split("/")[-1]: entry for entry in manifest["arcs"]}

    atlas = existing.get("atlas-of-borrowed-winds")
    if atlas is None:
        raise ValueError("the Atlas descriptor is missing from the manifest")
    atlas["channels"] = ["paidPlatform"]
    atlas["lockedPreviewChannels"] = ["web"]
    atlas["storefront"]["lockedTileSubtitle"] = (
        "Preview the prologue · Available in the apps"
    )

    generated = {spec["slug"]: _manifest_descriptor(spec) for spec in specs}
    ordered = [existing["origin"]]
    for slug in PORTFOLIO_ORDER:
        if slug == "atlas-of-borrowed-winds":
            ordered.append(atlas)
        else:
            descriptor = generated.get(slug)
            if descriptor is None:
                raise ValueError(f"missing complete portfolio spec for {slug}")
            ordered.append(descriptor)
    manifest["arcs"] = ordered
    _write_json(target, manifest)


def _manifest_descriptor(spec: dict[str, Any]) -> dict[str, Any]:
    slug = spec["slug"]
    storefront = spec["storefront"]
    theme = spec["theme"]
    return {
        "arcId": f"regalia:arc/{slug}",
        "metadataAsset": f"assets/content/arcs/{slug}/arc.json",
        "entitlementId": f"regalia:entitlement/base/{slug}",
        "channels": ["paidPlatform"],
        "lockedPreviewChannels": ["web"],
        "storefront": {
            "title": spec["title"],
            "tileSubtitle": storefront["tileSubtitle"],
            "lockedTileSubtitle": (
                "Preview the prologue · Available in the apps"
            ),
            "tileArtAsset": f"assets/storefront/{slug}/tile.jpg",
            "tileForegroundAsset": _storefront_hero_asset_path(
                slug, spec["cast"][0]["slug"]
            ),
            "theme": {
                "backgroundColor": theme["backgroundColor"],
                "surfaceColor": theme["surfaceColor"],
                "primaryColor": spec["chapters"][0]["primaryColor"],
                "secondaryColor": spec["chapters"][0]["secondaryColor"],
            },
            "prologuePreview": {
                "id": f"regalia:scene/{slug}/opening",
                "role": "opening",
                "defaults": {
                    "background": {
                        "asset": f"assets/storefront/{slug}/prologue.jpg",
                        "fit": "cover",
                    },
                    "characters": [],
                },
                "frames": storefront["prologueFrames"],
            },
        },
    }


def _generate_visual_assets(
    spec: dict[str, Any], *, overwrite: bool = False
) -> None:
    slug = spec["slug"]
    storefront = ROOT / "assets" / "storefront" / slug
    backgrounds = ROOT / "assets" / "art" / "arcs" / slug / "backgrounds"
    opponents = ROOT / "assets" / "art" / "arcs" / slug / "combat" / "opponents"
    characters = ROOT / "assets" / "art" / "arcs" / slug / "characters"
    storefront.mkdir(parents=True, exist_ok=True)
    backgrounds.mkdir(parents=True, exist_ok=True)
    opponents.mkdir(parents=True, exist_ok=True)
    characters.mkdir(parents=True, exist_ok=True)

    # Storefront key art is hand-authored separately from this deterministic
    # package generator. Supply the procedural fallback only when an arc does
    # not already have checked-in key art, so a routine catalog/background
    # regeneration cannot overwrite the production illustration.
    prologue_target = storefront / "prologue.jpg"
    if not prologue_target.exists():
        opening = _paint_environment(
            spec, chapter_index=0, width=256, height=384, opening=True
        )
        _save_scaled_jpeg(opening, prologue_target, (1024, 1536))
    tile_target = storefront / "tile.jpg"
    if not tile_target.exists():
        tile = _paint_environment(
            spec, chapter_index=0, width=256, height=256, opening=True
        )
        _save_scaled_jpeg(tile, tile_target, (1024, 1024))

    _export_storefront_hero(spec)

    for index, chapter in enumerate(spec["chapters"]):
        target = ROOT / _chapter_background_path(slug, index, chapter["slug"])
        if overwrite or not target.exists():
            background = _paint_environment(
                spec, chapter_index=index, width=256, height=256, opening=False
            )
            _save_scaled_jpeg(background, target, (1024, 1024))

        for opponent in [*chapter["encounters"], chapter["boss"]]:
            opponent_target = opponents / f"{opponent['slug']}.png"
            if overwrite or not opponent_target.exists():
                base = _paint_creature(
                    family=opponent["family"],
                    primary=_parse_hex(chapter["primaryColor"]),
                    secondary=_parse_hex(chapter["secondaryColor"]),
                    seed=_stable_seed(slug, opponent["slug"]),
                )
                atlas = _build_reaction_atlas(
                    base,
                    _stable_seed(slug, str(index), opponent["slug"]),
                )
                atlas.save(opponent_target, optimize=True)

    crisis_target = ROOT / _finale_background_path(slug, resolved=False)
    if overwrite or not crisis_target.exists():
        crisis = _paint_environment(
            spec,
            chapter_index=7,
            width=256,
            height=384,
            opening=False,
            crisis=True,
        )
        _save_scaled_jpeg(crisis, crisis_target, (1024, 1536))

    resolved_target = ROOT / _finale_background_path(slug, resolved=True)
    if overwrite or not resolved_target.exists():
        resolved = _paint_environment(
            spec,
            chapter_index=8,
            width=256,
            height=384,
            opening=False,
            resolved=True,
        )
        _save_scaled_jpeg(resolved, resolved_target, (1024, 1536))


def _paint_environment(
    spec: dict[str, Any],
    *,
    chapter_index: int,
    width: int,
    height: int,
    opening: bool,
    crisis: bool = False,
    resolved: bool = False,
) -> Image.Image:
    seed = int(spec["seed"]) * 97 + chapter_index * 1009 + height
    rng = random.Random(seed)
    theme = spec["theme"]
    chapter = spec["chapters"][min(chapter_index, 7)]
    background = _parse_hex(theme["backgroundColor"])
    surface = _parse_hex(theme["surfaceColor"])
    primary = _parse_hex(chapter["primaryColor"])
    secondary = _parse_hex(chapter["secondaryColor"])
    if resolved:
        background = _mix(background, (244, 214, 142), 0.36)
        primary = _mix(primary, (120, 220, 170), 0.28)
    if crisis:
        background = _mix(background, (25, 16, 32), 0.48)
        secondary = _mix(secondary, (220, 54, 72), 0.25)

    image = Image.new("RGB", (width, height), background)
    pixels = image.load()
    top = _mix(background, primary, 0.18 if not crisis else 0.08)
    bottom = _mix(surface, secondary, 0.12)
    for y in range(height):
        ratio = y / max(1, height - 1)
        color = _mix(top, bottom, ratio)
        for x in range(width):
            jitter = rng.choice((-3, -2, -1, 0, 0, 0, 1, 2, 3))
            pixels[x, y] = tuple(max(0, min(255, channel + jitter)) for channel in color)
    draw = ImageDraw.Draw(image)
    environment = spec["environment"]
    painter = {
        "space": _paint_space,
        "forest": _paint_forest,
        "ice": _paint_ice,
        "gothic": _paint_gothic,
        "thorns": _paint_thorns,
        "inn": _paint_inn,
        "library": _paint_library,
        "thunderwild": _paint_thunderwild,
        "ocean": _paint_ocean,
    }.get(environment)
    if painter is None:
        raise ValueError(f"unknown environment {environment!r}")
    painter(draw, width, height, chapter_index, rng, primary, secondary, crisis, resolved)
    _add_foreground_vignette(draw, width, height, _parse_hex(theme["inkColor"]), opening)
    return image


def _paint_space(draw, w, h, index, rng, primary, secondary, crisis, resolved):
    for _ in range(90 + index * 8):
        x, y = rng.randrange(w), rng.randrange(max(1, int(h * 0.78)))
        size = 1 if rng.random() < 0.84 else 2
        draw.rectangle((x, y, x + size, y + size), fill=_mix((248, 231, 176), primary, rng.random() * 0.35))
    sun_x, sun_y = int(w * (0.70 - index * 0.035)), int(h * 0.23)
    radius = max(12, int(min(w, h) * (0.12 - index * 0.004)))
    sun = _mix((255, 202, 66), secondary, 0.18)
    draw.ellipse((sun_x - radius, sun_y - radius, sun_x + radius, sun_y + radius), fill=sun)
    if crisis or index >= 5:
        draw.ellipse((sun_x - radius // 2, sun_y - radius, sun_x + radius, sun_y + radius), fill=(50, 28, 52))
    for lane in range(3):
        points = []
        for step in range(7):
            x = -12 + step * (w + 24) / 6
            y = h * (0.42 + lane * 0.13) + math.sin(step + index + lane) * 10
            points.append((int(x), int(y)))
        draw.line(points, fill=_mix(primary, (255, 224, 120), 0.32), width=2 + lane)
    for ship in range(2 + index // 2):
        x = int(w * (0.12 + 0.16 * ship)) + rng.randrange(-8, 9)
        y = int(h * (0.50 + 0.055 * ship))
        draw.polygon([(x, y), (x + 20, y + 4), (x + 3, y + 8)], fill=(224, 216, 191))
        draw.polygon([(x + 5, y - 18), (x + 17, y + 2), (x + 7, y + 1)], fill=secondary)


def _paint_forest(draw, w, h, index, rng, primary, secondary, crisis, resolved):
    horizon = int(h * 0.55)
    for layer in range(5):
        y = horizon + layer * 14
        color = _mix(primary, (28, 70, 48), layer / 7)
        draw.polygon([(0, y + 15), (w, y - rng.randrange(2, 10)), (w, h), (0, h)], fill=color)
        for x in range(-10, w + 20, 24):
            top = y - rng.randrange(22, 48)
            draw.line((x, y + 12, x + rng.randrange(-5, 6), top), fill=_mix(color, (56, 34, 24), 0.35), width=4)
            draw.ellipse((x - 10, top - 8, x + 12, top + 12), fill=_mix(color, secondary, 0.16))
    for terrace in range(5):
        y = int(h * 0.64) + terrace * 15
        draw.line((0, y, w, y - terrace * 2), fill=_mix((197, 143, 74), primary, 0.25), width=3)
    for root in range(7):
        x = rng.randrange(w)
        draw.arc((x - 34, h - 66, x + 38, h + 16), 190, 340, fill=secondary, width=3)
    cloud = (220, 231, 218) if not crisis else (111, 108, 117)
    for x in range(18, w, 54):
        y = 30 + rng.randrange(0, 45)
        draw.ellipse((x, y, x + 42, y + 18), fill=cloud)


def _paint_ice(draw, w, h, index, rng, primary, secondary, crisis, resolved):
    for band in range(4):
        y = 18 + band * 12
        points = [(0, y)]
        for x in range(0, w + 24, 24):
            points.append((x, y + int(math.sin(x / 24 + index + band) * (5 + band))))
        draw.line(points, fill=_mix(primary, secondary, band / 5), width=3)
    horizon = int(h * 0.58)
    for mountain in range(8):
        x = mountain * w // 7 - 25
        peak = horizon - rng.randrange(40, 105)
        color = _mix(primary, (220, 232, 236), mountain / 10)
        draw.polygon([(x - 40, horizon + 18), (x, peak), (x + 50, horizon + 18)], fill=color)
        draw.polygon([(x, peak), (x + 10, peak + 25), (x - 8, peak + 19)], fill=(235, 241, 236))
    draw.rectangle((0, horizon, w, h), fill=_mix((215, 233, 232), primary, 0.18))
    for crack in range(16 + index * 2):
        x = rng.randrange(w)
        y = rng.randrange(horizon, h)
        draw.line((x, y, x + rng.randrange(-18, 19), y + rng.randrange(7, 24)), fill=_mix(secondary, (35, 70, 92), 0.25), width=2)
    hull_y = int(h * 0.73)
    draw.polygon([(w * 0.18, hull_y), (w * 0.68, hull_y + 4), (w * 0.58, hull_y + 18), (w * 0.25, hull_y + 15)], fill=(41, 34, 35))
    draw.line((w * 0.42, hull_y, w * 0.42, hull_y - 45), fill=(105, 72, 48), width=4)


def _paint_gothic(draw, w, h, index, rng, primary, secondary, crisis, resolved):
    for _ in range(70):
        x, y = rng.randrange(w), rng.randrange(h)
        draw.line((x, y, x - 5, y + 15), fill=_mix((150, 164, 173), primary, 0.2), width=1)
    street = int(h * 0.72)
    draw.rectangle((0, street, w, h), fill=_mix((32, 31, 38), secondary, 0.12))
    for building in range(8):
        left = building * w // 7 - 16
        bw = rng.randrange(34, 58)
        top = rng.randrange(int(h * 0.25), int(h * 0.52))
        fill = _mix((38, 31, 42), primary, building / 18)
        draw.rectangle((left, top, left + bw, street), fill=fill)
        if building in {2, 5}:
            draw.polygon([(left, top), (left + bw // 2, top - 48), (left + bw, top)], fill=fill)
        for wy in range(top + 12, street - 8, 18):
            for wx in range(left + 8, left + bw - 5, 14):
                draw.rectangle((wx, wy, wx + 5, wy + 9), fill=_mix((226, 160, 61), secondary, 0.15))
    reservoir = int(w * (0.25 + index * 0.055))
    draw.ellipse((reservoir - 15, street - 13, reservoir + 15, street + 17), outline=secondary, width=3)
    draw.line((reservoir, street - 13, reservoir, street + 17), fill=secondary, width=2)


def _paint_thorns(draw, w, h, index, rng, primary, secondary, crisis, resolved):
    horizon = int(h * 0.58)
    draw.rectangle((0, horizon, w, h), fill=_mix((84, 72, 46), primary, 0.28))
    for castle_x in (int(w * 0.18), int(w * 0.72)):
        base = horizon + 8
        color = _mix((82, 75, 83), secondary, 0.16)
        draw.rectangle((castle_x - 22, base - 52, castle_x + 22, base), fill=color)
        draw.rectangle((castle_x - 30, base - 38, castle_x - 18, base), fill=color)
        draw.rectangle((castle_x + 18, base - 38, castle_x + 30, base), fill=color)
    vine_color = _mix(primary, (34, 88, 48), 0.5)
    for vine in range(7 + index):
        points = []
        offset = rng.randrange(-20, 20)
        for step in range(8):
            x = int(w * step / 7)
            y = int(h * (0.35 + vine * 0.045)) + int(math.sin(step + vine) * 10) + offset
            points.append((x, y))
        draw.line(points, fill=vine_color, width=3)
        for x, y in points[1:-1:2]:
            draw.polygon([(x, y), (x - 6, y - 5), (x - 2, y + 4)], fill=secondary)
    for _ in range(12 if resolved else 5):
        x, y = rng.randrange(w), rng.randrange(horizon, h)
        draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=_mix((210, 57, 104), secondary, 0.25))


def _paint_inn(draw, w, h, index, rng, primary, secondary, crisis, resolved):
    floor = int(h * 0.72)
    draw.rectangle((0, floor, w, h), fill=_mix((77, 47, 33), primary, 0.22))
    for beam in range(0, w, 42):
        draw.rectangle((beam, 0, beam + 5, floor), fill=_mix((73, 42, 31), secondary, 0.12))
    draw.rectangle((14, 18, w - 14, floor), outline=_mix((118, 74, 42), secondary, 0.18), width=5)
    for door in range(3):
        x = 30 + door * (w - 60) // 2
        top = 62 + (door + index) % 3 * 12
        glow = _mix((245, 183, 82), primary, door / 8)
        draw.rounded_rectangle((x - 18, top, x + 18, floor), radius=10, fill=_mix((62, 43, 48), secondary, 0.1), outline=glow, width=3)
        draw.rectangle((x - 12, top + 10, x + 12, top + 44), fill=glow)
    table_y = floor + 28
    draw.rectangle((30, table_y, w - 30, table_y + 10), fill=(96, 57, 35))
    draw.rectangle((42, table_y + 10, 50, h), fill=(78, 45, 31))
    draw.rectangle((w - 50, table_y + 10, w - 42, h), fill=(78, 45, 31))
    for clock in range(4 + index // 2):
        x = 35 + clock * 45
        y = 35 + (clock % 2) * 25
        draw.ellipse((x - 8, y - 8, x + 8, y + 8), outline=secondary, width=2)
        draw.line((x, y, x + (clock % 3) - 4, y - 5), fill=secondary, width=1)


def _paint_library(draw, w, h, index, rng, primary, secondary, crisis, resolved):
    floor = int(h * 0.80)
    draw.rectangle((0, floor, w, h), fill=_mix((51, 36, 43), primary, 0.2))
    for shelf in range(5):
        left = shelf * w // 4 - 14
        draw.rectangle((left, 30, left + 44, floor), fill=_mix((60, 40, 39), secondary, shelf / 16))
        for y in range(43, floor - 10, 22):
            draw.rectangle((left + 4, y, left + 40, y + 3), fill=(106, 72, 51))
            for book in range(5):
                bx = left + 6 + book * 7
                color = _mix(primary, secondary, ((book + shelf + index) % 6) / 6)
                draw.rectangle((bx, y - 14 - (book % 3), bx + 5, y), fill=color)
    center = w // 2
    draw.rounded_rectangle((center - 28, 48, center + 28, floor), radius=26, outline=_mix((222, 192, 126), secondary, 0.25), width=4)
    for card in range(9 + index):
        x = center + rng.randrange(-55, 56)
        y = rng.randrange(35, floor)
        draw.rectangle((x - 4, y - 3, x + 4, y + 3), fill=_mix((226, 216, 178), primary, 0.12))
    shadow = (25, 20, 38)
    draw.ellipse((center - 16, floor - 43, center + 16, floor - 12), fill=shadow)
    draw.polygon([(center - 19, floor - 22), (center + 19, floor - 22), (center + 30, floor), (center - 30, floor)], fill=shadow)


def _paint_thunderwild(draw, w, h, index, rng, primary, secondary, crisis, resolved):
    horizon = int(h * 0.61)
    for cloud in range(11):
        x = rng.randrange(-20, w)
        y = rng.randrange(18, horizon - 35)
        color = _mix((73, 83, 103), primary, cloud / 28)
        draw.ellipse((x, y, x + rng.randrange(30, 62), y + rng.randrange(14, 28)), fill=color)
    for bolt in range(2 + index // 3):
        x = rng.randrange(20, w - 20)
        y = rng.randrange(45, horizon - 25)
        draw.line((x, y, x - 8, y + 18, x + 2, y + 17, x - 5, y + 38), fill=_mix((250, 224, 98), secondary, 0.2), width=2)
    draw.rectangle((0, horizon, w, h), fill=_mix((97, 111, 62), primary, 0.28))
    for ridge in range(5):
        y = horizon + ridge * 18
        draw.line((0, y, w, y + rng.randrange(-7, 8)), fill=_mix((69, 82, 47), secondary, ridge / 11), width=4)
    for beast in range(3 + index // 2):
        x = 25 + beast * 48 + rng.randrange(-5, 6)
        y = horizon + 25 + (beast % 2) * 18
        color = _mix((39, 48, 52), primary, beast / 14)
        draw.ellipse((x, y, x + 34, y + 18), fill=color)
        draw.rectangle((x + 6, y + 14, x + 10, y + 30), fill=color)
        draw.rectangle((x + 25, y + 14, x + 29, y + 30), fill=color)
        draw.line((x + 28, y + 4, x + 42, y - 10), fill=secondary, width=3)


def _paint_ocean(draw, w, h, index, rng, primary, secondary, crisis, resolved):
    for band in range(12):
        y = band * h // 12
        draw.arc((-30, y - 12, w + 30, y + 28), 0, 180, fill=_mix(primary, secondary, band / 15), width=2)
    floor = int(h * 0.74)
    draw.rectangle((0, floor, w, h), fill=_mix((35, 83, 91), primary, 0.33))
    for coral in range(18):
        x = rng.randrange(w)
        y = rng.randrange(floor, h)
        color = _mix(secondary, (224, 93, 112), rng.random() * 0.35)
        draw.line((x, y, x + rng.randrange(-8, 9), y - rng.randrange(9, 32)), fill=color, width=3)
        draw.line((x, y - 12, x + rng.randrange(-12, 13), y - rng.randrange(16, 35)), fill=color, width=2)
    palace_y = int(h * 0.48)
    draw.polygon([(w * 0.35, floor), (w * 0.42, palace_y), (w * 0.50, floor)], fill=_mix((197, 181, 152), primary, 0.2))
    draw.polygon([(w * 0.48, floor), (w * 0.58, palace_y - 22), (w * 0.67, floor)], fill=_mix((213, 194, 164), secondary, 0.2))
    for fish in range(8 + index):
        x, y = rng.randrange(w), rng.randrange(24, floor)
        draw.polygon([(x, y), (x + 7, y - 3), (x + 7, y + 3)], fill=_mix((194, 224, 214), secondary, rng.random() * 0.25))


def _add_foreground_vignette(draw, w, h, ink, opening):
    strength = 0.22 if opening else 0.16
    edge = _mix(ink, (0, 0, 0), 0.32)
    bands = max(4, min(w, h) // 28)
    for band in range(bands):
        alpha = (bands - band) / bands * strength
        color = _mix(edge, (255, 255, 255), 1 - alpha)
        # Sparse pixel corners preserve a game-art vignette without flattening
        # the scene or placing a dark veil behind narrative text.
        for x in range(band, w - band, 7):
            if (x + band) % 3 == 0:
                draw.point((x, band), fill=color)
                draw.point((x, h - 1 - band), fill=color)


def _paint_creature(*, family: str, primary, secondary, seed: int) -> Image.Image:
    rng = random.Random(seed)
    scale = 2
    image = Image.new("RGBA", (80, 88), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    outline = _mix(primary, (14, 12, 20), 0.72)
    light = _mix(secondary, (255, 231, 168), 0.30)
    dark = _mix(primary, (24, 22, 30), 0.48)
    if family == "antlered":
        draw.ellipse((18, 34, 61, 62), fill=primary, outline=outline, width=3)
        draw.ellipse((47, 20, 68, 42), fill=secondary, outline=outline, width=3)
        for x in (26, 50):
            draw.rectangle((x, 57, x + 6, 76), fill=dark, outline=outline, width=2)
        for side in (-1, 1):
            ox = 55 + side * 6
            draw.line((ox, 23, ox + side * 9, 7, ox + side * 15, 3), fill=light, width=3)
            draw.line((ox + side * 5, 14, ox + side * 14, 12), fill=light, width=2)
    elif family == "rootbound":
        draw.polygon([(24, 68), (29, 27), (39, 15), (50, 28), (57, 68)], fill=primary, outline=outline)
        for x in (23, 34, 46, 58):
            draw.line((40, 52, x + rng.randrange(-4, 5), 79), fill=dark, width=4)
        for side in (-1, 1):
            draw.line((39, 30, 39 + side * 21, 18), fill=secondary, width=4)
            draw.ellipse((34 + side * 20, 10, 46 + side * 20, 23), fill=light)
    elif family == "winged":
        draw.ellipse((28, 27, 54, 63), fill=primary, outline=outline, width=3)
        draw.polygon([(31, 37), (5, 20), (17, 56), (36, 50)], fill=secondary, outline=outline)
        draw.polygon([(51, 36), (75, 17), (66, 57), (47, 50)], fill=secondary, outline=outline)
        draw.polygon([(52, 29), (68, 35), (53, 39)], fill=light, outline=outline)
        draw.line((36, 60, 30, 75), fill=outline, width=3)
        draw.line((47, 60, 53, 75), fill=outline, width=3)
    elif family == "abyssal":
        draw.ellipse((21, 13, 59, 45), fill=primary, outline=outline, width=3)
        draw.polygon([(20, 35), (60, 35), (70, 68), (10, 68)], fill=secondary, outline=outline)
        for x in range(16, 69, 10):
            draw.arc((x - 6, 59, x + 8, 82), 0, 180, fill=light, width=3)
        draw.ellipse((29, 26, 34, 32), fill=light)
        draw.ellipse((46, 26, 51, 32), fill=light)
    elif family == "volcanic":
        draw.rectangle((23, 28, 57, 64), fill=primary, outline=outline, width=3)
        draw.polygon([(28, 29), (34, 12), (50, 14), (55, 29)], fill=secondary, outline=outline)
        draw.rectangle((10, 34, 25, 58), fill=dark, outline=outline, width=3)
        draw.rectangle((55, 34, 70, 58), fill=dark, outline=outline, width=3)
        draw.rectangle((25, 61, 37, 80), fill=dark, outline=outline, width=3)
        draw.rectangle((44, 61, 56, 80), fill=dark, outline=outline, width=3)
        draw.line((32, 35, 42, 45, 36, 56), fill=light, width=3)
    elif family == "clockwork":
        draw.rounded_rectangle((20, 26, 60, 67), radius=8, fill=primary, outline=outline, width=3)
        draw.rectangle((27, 11, 53, 33), fill=secondary, outline=outline, width=3)
        draw.ellipse((31, 17, 37, 23), fill=light)
        draw.ellipse((44, 17, 50, 23), fill=light)
        for x in (11, 62):
            draw.ellipse((x, 34, x + 15, 53), fill=secondary, outline=outline, width=3)
        draw.line((40, 11, 40, 4), fill=light, width=2)
        draw.ellipse((37, 1, 43, 7), fill=light)
        for x in (27, 48):
            draw.rectangle((x, 64, x + 7, 81), fill=dark, outline=outline, width=2)
    elif family == "spectral":
        draw.ellipse((25, 12, 55, 39), fill=outline)
        draw.ellipse((31, 19, 49, 35), fill=primary)
        draw.polygon([(22, 32), (58, 32), (70, 75), (54, 68), (41, 80), (27, 69), (11, 75)], fill=secondary, outline=outline)
        draw.ellipse((33, 24, 37, 29), fill=light)
        draw.ellipse((44, 24, 48, 29), fill=light)
        for x in (18, 40, 61):
            draw.arc((x - 9, 63, x + 9, 86), 180, 355, fill=light, width=2)
    elif family == "cosmic":
        draw.ellipse((18, 18, 62, 66), fill=primary, outline=outline, width=3)
        points = []
        for point in range(10):
            angle = -math.pi / 2 + point * math.pi / 5
            radius = 22 if point % 2 == 0 else 9
            points.append((40 + math.cos(angle) * radius, 42 + math.sin(angle) * radius))
        draw.polygon(points, fill=secondary, outline=outline)
        draw.ellipse((34, 36, 46, 48), fill=light)
        draw.arc((7, 8, 73, 74), 200, 515, fill=light, width=3)
        draw.line((23, 65, 12, 78), fill=secondary, width=4)
    else:
        raise ValueError(f"unknown family {family}")
    # A small deterministic crest makes same-family silhouettes distinct.
    crest_x = 34 + rng.randrange(-8, 9)
    draw.polygon(
        [(crest_x, 12), (crest_x + 5, 2), (crest_x + 10, 13)],
        fill=_mix(light, secondary, 0.35),
        outline=outline,
    )
    return image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)


def _build_reaction_atlas(base: Image.Image, seed: int) -> Image.Image:
    cell = 192
    atlas = Image.new("RGBA", (cell * 4, cell * 6), (0, 0, 0, 0))
    rng = random.Random(seed)
    scales = (
        (0.88, 0.93, 0.98, 0.92),
        (0.91, 0.96, 0.89, 0.82),
        (0.90, 0.95, 1.00, 0.94),
        (0.91, 0.86, 0.96, 0.83),
        (0.88, 0.94, 0.99, 0.92),
        (0.86, 0.78, 0.68, 0.57),
    )
    rotations = (
        (0, -2, 2, 0),
        (3, -5, -9, -14),
        (-2, 1, 3, 0),
        (5, -6, 8, -10),
        (0, 3, -3, 0),
        (10, 28, 53, 78),
    )
    for row in range(6):
        for frame in range(4):
            sprite = base.copy()
            factor = scales[row][frame]
            sprite = sprite.resize(
                (max(1, round(sprite.width * factor)), max(1, round(sprite.height * factor))),
                Image.Resampling.NEAREST,
            )
            rotation = rotations[row][frame]
            if rotation:
                sprite = sprite.rotate(
                    rotation,
                    resample=Image.Resampling.NEAREST,
                    expand=True,
                    fillcolor=(0, 0, 0, 0),
                )
            if row == 3:
                sprite = _damage_tint(sprite, 28 + frame * 18)
            cell_image = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
            effects = ImageDraw.Draw(cell_image)
            _paint_reaction_effects(effects, cell, row, frame, rng)
            offset_x = ((0, 2, -2, 1), (7, -4, -12, -19), (1, 4, 8, 3), (0, 7, -8, 4), (0, -2, 2, 0), (2, 8, 14, 19))[row][frame]
            offset_y = ((3, 0, -3, 1), (2, 0, 1, 4), (5, 1, -2, 3), (2, -2, 4, 1), (4, 0, -3, 1), (10, 20, 34, 48))[row][frame]
            x = cell // 2 - sprite.width // 2 + offset_x
            y = cell // 2 - sprite.height // 2 + offset_y
            cell_image.alpha_composite(sprite, (x, y))
            _paint_reaction_foreground(ImageDraw.Draw(cell_image), cell, row, frame)
            atlas.alpha_composite(cell_image, (frame * cell, row * cell))
    _clear_atlas_gutters(atlas, cell=cell, gutter=8)
    _harden_alpha(atlas)
    return atlas


def _paint_reaction_effects(draw, cell, row, frame, rng):
    center = cell // 2
    accent = (82, 225, 230, 255)
    gold = (244, 190, 67, 255)
    if row == 2:
        radius = 58 + frame * 6
        draw.arc((center - radius, center - radius, center + radius, center + radius), 145 - frame * 9, 226 + frame * 13, fill=accent, width=4)
    elif row == 4:
        radius = 43 + frame * 8
        draw.ellipse((center - radius, center - radius, center + radius, center + radius), outline=accent, width=3)
        draw.arc((center - radius - 7, center - radius + 5, center + radius + 7, center + radius - 5), 205 + frame * 20, 330 + frame * 20, fill=gold, width=4)


def _paint_reaction_foreground(draw, cell, row, frame):
    center = cell // 2
    if row == 1 and frame:
        reach = 34 + frame * 14
        draw.line((center - 14, center - 22, center - reach, center + 17), fill=(255, 214, 95, 255), width=5)
    elif row == 3:
        x = center - 46 + frame * 5
        y = center - 33 + (frame % 2) * 8
        draw.rectangle((x - 3, y - 12, x + 3, y + 12), fill=(255, 235, 150, 255))
        draw.rectangle((x - 12, y - 3, x + 12, y + 3), fill=(255, 235, 150, 255))
    elif row == 5:
        for spark in range(frame + 1):
            x = center - 35 + spark * 21
            y = center - 48 + (spark % 2) * 13
            draw.rectangle((x, y, x + 4, y + 4), fill=(255, 226, 102, 255))


def _damage_tint(image: Image.Image, amount: int) -> Image.Image:
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha:
                pixels[x, y] = (
                    min(255, red + amount),
                    max(0, green - amount // 5),
                    max(0, blue - amount // 6),
                    alpha,
                )
    return image


def _clear_atlas_gutters(image: Image.Image, *, cell: int, gutter: int) -> None:
    pixels = image.load()
    for y in range(image.height):
        local_y = y % cell
        for x in range(image.width):
            local_x = x % cell
            if (
                local_x < gutter
                or local_x >= cell - gutter
                or local_y < gutter
                or local_y >= cell - gutter
            ):
                pixels[x, y] = (0, 0, 0, 0)


def _harden_alpha(image: Image.Image) -> None:
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (red, green, blue, 255) if alpha >= 128 else (0, 0, 0, 0)


def _save_scaled_jpeg(source: Image.Image, target: Path, size: tuple[int, int]) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    scaled = source.resize(size, Image.Resampling.NEAREST)
    scaled.save(target, format="JPEG", quality=88, optimize=True, progressive=True)


def _chapter_background_path(slug: str, index: int, chapter_slug: str) -> str:
    filename = f"chapter_{index + 1:02d}_{chapter_slug.replace('-', '_')}.jpg"
    return f"assets/art/arcs/{slug}/backgrounds/{filename}"


def _opponent_asset_path(slug: str, opponent_slug: str) -> str:
    return (
        f"assets/art/arcs/{slug}/combat/opponents/{opponent_slug}.png"
    )


def _character_story_asset_path(slug: str, character_slug: str) -> str:
    return (
        f"assets/art/arcs/{slug}/characters/"
        f"{character_slug}_story_idle.png"
    )


def _storefront_hero_asset_path(slug: str, character_slug: str) -> str:
    return f"assets/storefront/{slug}/{character_slug}.png"


def _export_storefront_hero(spec: dict[str, Any]) -> None:
    slug = spec["slug"]
    hero_slug = spec["cast"][0]["slug"]
    source_path = ROOT / _character_story_asset_path(slug, hero_slug)
    if not source_path.exists():
        return

    with Image.open(source_path) as source_image:
        source = source_image.convert("RGBA")
    if source.width % 4 != 0:
        raise ValueError(
            f"{source_path} width must contain four equal story frames"
        )
    frame_width = source.width // 4
    if (frame_width, source.height) != (192, 288):
        raise ValueError(
            f"{source_path} story frames must be 192x288, got "
            f"{frame_width}x{source.height}"
        )

    target = ROOT / _storefront_hero_asset_path(slug, hero_slug)
    target.parent.mkdir(parents=True, exist_ok=True)
    source.crop((0, 0, frame_width, source.height)).save(
        target, format="PNG", optimize=True
    )


def _character_combat_asset_path(slug: str, character_slug: str) -> str:
    return (
        f"assets/art/arcs/{slug}/characters/"
        f"{character_slug}_combat.png"
    )


def _character_finisher_asset_path(slug: str, character_slug: str) -> str:
    return (
        f"assets/art/arcs/{slug}/characters/"
        f"{character_slug}_finishers.png"
    )


def _finale_background_path(slug: str, *, resolved: bool) -> str:
    name = "finale_resolution.jpg" if resolved else "finale_crisis.jpg"
    return f"assets/art/arcs/{slug}/backgrounds/{name}"


def _parse_hex(value: str) -> tuple[int, int, int]:
    if not isinstance(value, str) or len(value) != 7 or not value.startswith("#"):
        raise ValueError(f"invalid color {value!r}")
    try:
        return tuple(int(value[index : index + 2], 16) for index in (1, 3, 5))
    except ValueError as error:
        raise ValueError(f"invalid color {value!r}") from error


def _relative_luminance(color: tuple[int, int, int]) -> float:
    channels = [value / 255 for value in color]
    linear = [
        value / 12.92
        if value <= 0.04045
        else ((value + 0.055) / 1.055) ** 2.4
        for value in channels
    ]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def _contrast_ratio(
    first: tuple[int, int, int], second: tuple[int, int, int]
) -> float:
    first_luminance = _relative_luminance(first)
    second_luminance = _relative_luminance(second)
    lighter = max(first_luminance, second_luminance)
    darker = min(first_luminance, second_luminance)
    return (lighter + 0.05) / (darker + 0.05)


def _mix(first, second, ratio: float) -> tuple[int, int, int]:
    ratio = max(0.0, min(1.0, ratio))
    return tuple(round(a * (1 - ratio) + b * ratio) for a, b in zip(first, second))


def _stable_seed(*values: str) -> int:
    digest = hashlib.sha256("\0".join(values).encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big")


def _write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as target:
        json.dump(value, target, ensure_ascii=False, indent=2)
        target.write("\n")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"portfolio generation failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
