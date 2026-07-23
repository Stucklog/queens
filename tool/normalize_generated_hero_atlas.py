#!/usr/bin/env python3
"""Pack transparent generated protagonist sheets into the combat ABIs."""

from __future__ import annotations

import argparse
from collections.abc import Callable
from pathlib import Path

from PIL import Image


TRANSPARENT = (0, 0, 0, 0)
SOURCE_GUTTER = 4
COMBAT_X = (0, 240, 490, 685, 900, 1110, 1310, 1520, 1774)
COMBAT_Y = (0, 220, 415, 605, 887)
COMBAT_ANCHORS = (130, 350, 575, 790, 1000, 1200, 1405, 1620)
COMBAT_BASELINES = (190, 390, 580, 780)
FINISHER_COLUMNS = 6
FINISHER_ROWS = 8
FINISHER_CELL = 296


def main() -> None:
    parser = argparse.ArgumentParser()
    sources = parser.add_mutually_exclusive_group(required=True)
    sources.add_argument("--input", type=Path)
    sources.add_argument(
        "--row-input",
        action="append",
        type=Path,
        help=(
            "transparent single-row source; repeat four times for combat or "
            "eight times for finishers"
        ),
    )
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--kind", required=True, choices=("combat", "finishers"))
    parser.add_argument(
        "--allow-tight-row-gaps",
        action="store_true",
        help=(
            "accept genuine 2px transparent separators in --row-input strips; "
            "the packed atlas still enforces its full output gutters"
        ),
    )
    args = parser.parse_args()

    if args.allow_tight_row_gaps and not args.row_input:
        parser.error("--allow-tight-row-gaps requires --row-input")

    if args.row_input:
        expected_rows = 4 if args.kind == "combat" else 8
        if len(args.row_input) != expected_rows:
            raise ValueError(
                f"{args.kind} needs exactly {expected_rows} --row-input values"
            )
        row_sources = [_load_rgba(path) for path in args.row_input]
        atlas = (
            _pack_combat_rows(
                row_sources,
                allow_tight_gaps=args.allow_tight_row_gaps,
            )
            if args.kind == "combat"
            else _pack_finisher_rows(
                row_sources,
                allow_tight_gaps=args.allow_tight_row_gaps,
            )
        )
    else:
        source = _load_rgba(args.input)
        atlas = (
            _pack_combat(source)
            if args.kind == "combat"
            else _pack_finishers(source)
        )
    _harden_alpha(atlas)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.out, format="PNG", optimize=True)
    print(f"Wrote {args.out} ({atlas.width}x{atlas.height}, {args.kind})")


def _load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as source_image:
        return source_image.convert("RGBA")


def _pack_combat(source: Image.Image) -> Image.Image:
    return _pack_combat_from_cells(
        lambda row, column: _source_cell(
            source, columns=8, rows=4, column=column, row=row
        )
    )


def _pack_combat_rows(
    sources: list[Image.Image], *, allow_tight_gaps: bool = False
) -> Image.Image:
    minimum_gap = 2 if allow_tight_gaps else SOURCE_GUTTER * 2
    cells = [
        _split_source_row(
            source,
            columns=4 if row == 3 else 8,
            minimum_gap=minimum_gap,
        )
        for row, source in enumerate(sources)
    ]
    return _pack_combat_from_cells(
        lambda row, column: cells[row][column],
        source_gutter=1 if allow_tight_gaps else SOURCE_GUTTER,
    )


def _pack_combat_from_cells(
    cell_at: Callable[[int, int], Image.Image],
    *,
    source_gutter: int = SOURCE_GUTTER,
) -> Image.Image:
    atlas = Image.new("RGBA", (COMBAT_X[-1], COMBAT_Y[-1]), TRANSPARENT)
    for row in range(4):
        for column in range(8):
            if row == 3 and column >= 4:
                continue
            cell = cell_at(row, column)
            sprite = _trimmed_sprite(
                cell,
                row=row,
                column=column,
                source_gutter=source_gutter,
            )
            left = COMBAT_X[column]
            right = COMBAT_X[column + 1]
            top = COMBAT_Y[row]
            bottom = COMBAT_Y[row + 1]
            fitted = _fit(
                sprite,
                max_width=right - left - 24,
                max_height=bottom - top - 24,
            )
            x = round(COMBAT_ANCHORS[column] - fitted.width / 2)
            y = round(COMBAT_BASELINES[row] - fitted.height)
            x = min(max(x, left + 12), right - 12 - fitted.width)
            y = min(max(y, top + 12), bottom - 12 - fitted.height)
            atlas.alpha_composite(fitted, (x, y))
    _validate_gutters(
        atlas,
        x_boundaries=COMBAT_X,
        y_boundaries=COMBAT_Y,
        gutter=10,
        active_cells={
            (row, column)
            for row in range(4)
            for column in range(8)
            if row < 3 or column < 4
        },
    )
    return atlas


def _pack_finishers(source: Image.Image) -> Image.Image:
    return _pack_finishers_from_cells(
        lambda row, column: _source_cell(
            source,
            columns=FINISHER_COLUMNS,
            rows=FINISHER_ROWS,
            column=column,
            row=row,
        )
    )


def _pack_finisher_rows(
    sources: list[Image.Image], *, allow_tight_gaps: bool = False
) -> Image.Image:
    minimum_gap = 2 if allow_tight_gaps else SOURCE_GUTTER * 2
    cells = [
        _split_source_row(
            source,
            columns=FINISHER_COLUMNS,
            minimum_gap=minimum_gap,
        )
        for source in sources
    ]
    return _pack_finishers_from_cells(
        lambda row, column: cells[row][column],
        source_gutter=1 if allow_tight_gaps else SOURCE_GUTTER,
    )


def _pack_finishers_from_cells(
    cell_at: Callable[[int, int], Image.Image],
    *,
    source_gutter: int = SOURCE_GUTTER,
) -> Image.Image:
    atlas = Image.new(
        "RGBA",
        (FINISHER_COLUMNS * FINISHER_CELL, FINISHER_ROWS * FINISHER_CELL),
        TRANSPARENT,
    )
    for row in range(FINISHER_ROWS):
        for column in range(FINISHER_COLUMNS):
            cell = cell_at(row, column)
            sprite = _trimmed_sprite(
                cell,
                row=row,
                column=column,
                source_gutter=source_gutter,
            )
            fitted = _fit(
                sprite,
                max_width=FINISHER_CELL - 48,
                max_height=FINISHER_CELL - 48,
            )
            x = column * FINISHER_CELL + (FINISHER_CELL - fitted.width) // 2
            y = (row + 1) * FINISHER_CELL - 24 - fitted.height
            atlas.alpha_composite(fitted, (x, y))
    boundaries_x = tuple(
        index * FINISHER_CELL for index in range(FINISHER_COLUMNS + 1)
    )
    boundaries_y = tuple(
        index * FINISHER_CELL for index in range(FINISHER_ROWS + 1)
    )
    _validate_gutters(
        atlas,
        x_boundaries=boundaries_x,
        y_boundaries=boundaries_y,
        gutter=24,
        active_cells={
            (row, column)
            for row in range(FINISHER_ROWS)
            for column in range(FINISHER_COLUMNS)
        },
    )
    return atlas


def _source_cell(
    source: Image.Image,
    *,
    columns: int,
    rows: int,
    column: int,
    row: int,
) -> Image.Image:
    left = round(source.width * column / columns)
    right = round(source.width * (column + 1) / columns)
    top = round(source.height * row / rows)
    bottom = round(source.height * (row + 1) / rows)
    return source.crop((left, top, right, bottom))


def _split_source_row(
    source: Image.Image,
    *,
    columns: int,
    minimum_gap: int = SOURCE_GUTTER * 2,
) -> list[Image.Image]:
    """Split a generated strip at real transparent gaps near its ideal cells."""
    alpha = source.getchannel("A")
    occupied = [
        any(alpha.getpixel((x, y)) >= 128 for y in range(source.height))
        for x in range(source.width)
    ]
    nominal_width = source.width / columns
    boundaries = [0]
    for index in range(1, columns):
        ideal = round(index * nominal_width)
        radius = max(8, round(nominal_width * 0.32))
        start = max(boundaries[-1] + minimum_gap, ideal - radius)
        end = min(source.width - minimum_gap, ideal + radius)
        gaps: list[tuple[int, int]] = []
        gap_start: int | None = None
        for x in range(start, end):
            if not occupied[x] and gap_start is None:
                gap_start = x
            elif occupied[x] and gap_start is not None:
                if x - gap_start >= minimum_gap:
                    gaps.append((gap_start, x))
                gap_start = None
        if gap_start is not None and end - gap_start >= minimum_gap:
            gaps.append((gap_start, end))
        if not gaps:
            raise ValueError(
                f"source strip has no transparent separator near frame {index}"
            )
        gap = min(
            gaps,
            key=lambda value: abs(((value[0] + value[1]) / 2) - ideal),
        )
        boundaries.append((gap[0] + gap[1]) // 2)
    boundaries.append(source.width)
    return [
        source.crop((boundaries[index], 0, boundaries[index + 1], source.height))
        for index in range(columns)
    ]


def _trimmed_sprite(
    cell: Image.Image,
    *,
    row: int,
    column: int,
    source_gutter: int = SOURCE_GUTTER,
) -> Image.Image:
    alpha = cell.getchannel("A")
    for y in range(cell.height):
        for x in range(cell.width):
            in_gutter = (
                x < source_gutter
                or x >= cell.width - source_gutter
                or y < source_gutter
                or y >= cell.height - source_gutter
            )
            if in_gutter and alpha.getpixel((x, y)) >= 128:
                raise ValueError(
                    f"source row {row} frame {column} crosses its natural "
                    "cell gutter; regenerate or refit the complete pose"
                )
    bounds = alpha.point(lambda value: 255 if value >= 128 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"source row {row} frame {column} is empty")
    return cell.crop(bounds)


def _fit(sprite: Image.Image, *, max_width: int, max_height: int) -> Image.Image:
    scale = min(max_width / sprite.width, max_height / sprite.height)
    return sprite.resize(
        (
            max(1, round(sprite.width * scale)),
            max(1, round(sprite.height * scale)),
        ),
        Image.Resampling.NEAREST,
    )


def _harden_alpha(image: Image.Image) -> None:
    pixels = image.load()
    assert pixels is not None
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (
                (red, green, blue, 255) if alpha >= 128 else TRANSPARENT
            )


def _validate_gutters(
    image: Image.Image,
    *,
    x_boundaries: tuple[int, ...],
    y_boundaries: tuple[int, ...],
    gutter: int,
    active_cells: set[tuple[int, int]],
) -> None:
    alpha = image.getchannel("A")
    for row in range(len(y_boundaries) - 1):
        for column in range(len(x_boundaries) - 1):
            if (row, column) not in active_cells:
                continue
            left = x_boundaries[column]
            right = x_boundaries[column + 1]
            top = y_boundaries[row]
            bottom = y_boundaries[row + 1]
            for y in range(top, bottom):
                for x in range(left, right):
                    in_gutter = (
                        x < left + gutter
                        or x >= right - gutter
                        or y < top + gutter
                        or y >= bottom - gutter
                    )
                    if in_gutter and alpha.getpixel((x, y)) != 0:
                        raise ValueError(
                            f"packed row {row} frame {column} crosses its "
                            f"{gutter}px output gutter"
                        )


if __name__ == "__main__":
    main()
