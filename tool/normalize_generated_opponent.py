#!/usr/bin/env python3
"""Normalize a transparent authored reaction sheet for the combat renderer."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


OUTPUT_SIZE = (768, 1152)
COLUMNS = 4
ROWS = 6
GUTTER = 8
SOURCE_GUTTER = 4
TRANSPARENT = (0, 0, 0, 0)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    with Image.open(args.input) as source:
        image = source.convert("RGBA")
    if (
        image.width < COLUMNS * SOURCE_GUTTER * 4
        or image.height < ROWS * SOURCE_GUTTER * 4
    ):
        raise ValueError(
            f"reaction sheet is too small to contain a {COLUMNS}x{ROWS} grid: "
            f"{image.width}x{image.height}"
        )

    image = _pack_cells(image)
    _harden_alpha(image)
    _validate_output_gutters(image)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.out, format="PNG", optimize=True)
    print(f"Wrote {args.out} ({image.width}x{image.height}, {COLUMNS}x{ROWS})")


def _pack_cells(source: Image.Image) -> Image.Image:
    atlas = Image.new("RGBA", OUTPUT_SIZE, TRANSPARENT)
    output_cell_width = OUTPUT_SIZE[0] // COLUMNS
    output_cell_height = OUTPUT_SIZE[1] // ROWS
    y_boundaries = _transparent_boundaries(source, partitions=ROWS, axis="y")
    for row in range(ROWS):
        top = y_boundaries[row]
        bottom = y_boundaries[row + 1]
        row_source = source.crop((0, top, source.width, bottom))
        x_boundaries = _transparent_boundaries(
            row_source, partitions=COLUMNS, axis="x"
        )
        for column in range(COLUMNS):
            left = x_boundaries[column]
            right = x_boundaries[column + 1]
            cell = row_source.crop((left, 0, right, row_source.height))
            _validate_source_gutter(cell, row=row, column=column)
            fitted = cell.resize(
                (output_cell_width, output_cell_height),
                Image.Resampling.NEAREST,
            )
            fitted = _position_inside_output_gutter(
                fitted, row=row, column=column
            )
            atlas.alpha_composite(
                fitted,
                (
                    column * output_cell_width,
                    row * output_cell_height,
                ),
            )
    return atlas


def _transparent_boundaries(
    source: Image.Image, *, partitions: int, axis: str
) -> list[int]:
    """Find real grid separators near the nominal generated-sheet divisions."""
    alpha = source.getchannel("A")
    extent = source.width if axis == "x" else source.height
    cross_extent = source.height if axis == "x" else source.width
    occupied = []
    for position in range(extent):
        occupied.append(
            any(
                alpha.getpixel(
                    (position, cross) if axis == "x" else (cross, position)
                )
                >= 128
                for cross in range(cross_extent)
            )
        )
    nominal = extent / partitions
    boundaries = [0]
    for index in range(1, partitions):
        ideal = round(index * nominal)
        radius = max(8, round(nominal * 0.32))
        start = max(boundaries[-1] + SOURCE_GUTTER * 2, ideal - radius)
        end = min(extent - SOURCE_GUTTER * 2, ideal + radius)
        gaps: list[tuple[int, int]] = []
        gap_start: int | None = None
        for position in range(start, end):
            if not occupied[position] and gap_start is None:
                gap_start = position
            elif occupied[position] and gap_start is not None:
                if position - gap_start >= SOURCE_GUTTER * 2:
                    gaps.append((gap_start, position))
                gap_start = None
        if gap_start is not None and end - gap_start >= SOURCE_GUTTER * 2:
            gaps.append((gap_start, end))
        if not gaps:
            raise ValueError(
                f"source sheet has no transparent {axis}-separator near "
                f"grid division {index}"
            )
        gap = min(
            gaps,
            key=lambda value: abs(((value[0] + value[1]) / 2) - ideal),
        )
        boundaries.append((gap[0] + gap[1]) // 2)
    boundaries.append(extent)
    return boundaries


def _position_inside_output_gutter(
    cell: Image.Image, *, row: int, column: int
) -> Image.Image:
    bounds = _visible_bounds(cell)
    if bounds is None:
        raise ValueError(f"source row {row} frame {column} is empty")
    left, top, right, bottom = bounds
    available_width = cell.width - GUTTER * 2
    available_height = cell.height - GUTTER * 2
    if right - left > available_width or bottom - top > available_height:
        visible = cell.crop((left, top, right, bottom))
        scale = min(
            available_width / visible.width,
            available_height / visible.height,
        )
        resized = visible.resize(
            (
                max(1, round(visible.width * scale)),
                max(1, round(visible.height * scale)),
            ),
            Image.Resampling.NEAREST,
        )
        positioned = Image.new("RGBA", cell.size, TRANSPARENT)
        positioned.alpha_composite(
            resized,
            (
                (cell.width - resized.width) // 2,
                cell.height - GUTTER - resized.height,
            ),
        )
        return positioned

    offset_x = GUTTER - left if left < GUTTER else 0
    if right + offset_x > cell.width - GUTTER:
        offset_x = cell.width - GUTTER - right
    offset_y = GUTTER - top if top < GUTTER else 0
    if bottom + offset_y > cell.height - GUTTER:
        offset_y = cell.height - GUTTER - bottom

    positioned = Image.new("RGBA", cell.size, TRANSPARENT)
    positioned.alpha_composite(cell, (offset_x, offset_y))
    return positioned


def _validate_source_gutter(
    cell: Image.Image, *, row: int, column: int
) -> None:
    alpha = cell.getchannel("A")
    occupied = 0
    for y in range(cell.height):
        for x in range(cell.width):
            in_gutter = (
                x < SOURCE_GUTTER
                or x >= cell.width - SOURCE_GUTTER
                or y < SOURCE_GUTTER
                or y >= cell.height - SOURCE_GUTTER
            )
            if in_gutter and alpha.getpixel((x, y)) >= 128:
                occupied += 1
    if occupied:
        raise ValueError(
            f"source row {row} frame {column} crosses its natural cell "
            f"gutter with {occupied} visible pixels; refit the authored "
            "pose instead of erasing it"
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


def _visible_bounds(image: Image.Image) -> tuple[int, int, int, int] | None:
    visible_alpha = image.getchannel("A").point(
        lambda alpha: 255 if alpha >= 128 else 0
    )
    return visible_alpha.getbbox()


def _validate_output_gutters(image: Image.Image) -> None:
    pixels = image.load()
    assert pixels is not None
    cell_width = image.width // COLUMNS
    cell_height = image.height // ROWS
    occupied = 0
    for y in range(image.height):
        local_y = y % cell_height
        for x in range(image.width):
            local_x = x % cell_width
            in_gutter = (
                local_x < GUTTER
                or local_x >= cell_width - GUTTER
                or local_y < GUTTER
                or local_y >= cell_height - GUTTER
            )
            if in_gutter and pixels[x, y][3] != 0:
                occupied += 1
    if occupied:
        raise ValueError(
            f"normalized atlas crosses its output gutters with {occupied} "
            "visible pixels"
        )


if __name__ == "__main__":
    main()
