#!/usr/bin/env python3
"""Normalize a chroma-keyed generated reaction sheet for the combat renderer."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


OUTPUT_SIZE = (768, 1152)
COLUMNS = 4
ROWS = 6
GUTTER = 8


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    with Image.open(args.input) as source:
        image = source.convert("RGBA")
    aspect_error = abs((image.width / image.height) - (2 / 3))
    if aspect_error > 0.05:
        raise ValueError(
            f"expected an approximately 2:3 reaction sheet, got "
            f"{image.width}x{image.height}"
        )

    image = image.resize(OUTPUT_SIZE, Image.Resampling.NEAREST)
    pixels = image.load()
    assert pixels is not None
    cell_width = image.width // COLUMNS
    cell_height = image.height // ROWS
    for y in range(image.height):
        local_y = y % cell_height
        for x in range(image.width):
            local_x = x % cell_width
            red, green, blue, alpha = pixels[x, y]
            in_gutter = (
                local_x < GUTTER
                or local_x >= cell_width - GUTTER
                or local_y < GUTTER
                or local_y >= cell_height - GUTTER
            )
            chroma_fringe = red > 210 and blue > 210 and green < 130
            if in_gutter or alpha < 128 or chroma_fringe:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, 255)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.out, format="PNG", optimize=True)
    print(f"Wrote {args.out} ({image.width}x{image.height}, {COLUMNS}x{ROWS})")


if __name__ == "__main__":
    main()
