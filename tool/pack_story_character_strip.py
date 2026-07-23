#!/usr/bin/env python3
"""Pack an authored horizontal character strip into the story sprite ABI."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


COLUMNS = 4
CELL_WIDTH = 192
CELL_HEIGHT = 288
GUTTER_X = 12
GUTTER_TOP = 16
GUTTER_BOTTOM = 16
TRANSPARENT = (0, 0, 0, 0)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Split four evenly spaced authored poses, trim their transparent "
            "margins, and pack them into a 768x288 hard-alpha story strip."
        )
    )
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    with Image.open(args.input) as source_image:
        source = source_image.convert("RGBA")

    frames = []
    for column in range(COLUMNS):
        left = round(source.width * column / COLUMNS)
        right = round(source.width * (column + 1) / COLUMNS)
        frame = source.crop((left, 0, right, source.height))
        bounds = _visible_bounds(frame)
        if bounds is None:
            raise ValueError(f"frame {column} contains no visible character pixels")
        frames.append(frame.crop(bounds))

    max_width = max(frame.width for frame in frames)
    max_height = max(frame.height for frame in frames)
    scale = min(
        (CELL_WIDTH - GUTTER_X * 2) / max_width,
        (CELL_HEIGHT - GUTTER_TOP - GUTTER_BOTTOM) / max_height,
    )
    if scale <= 0:
        raise ValueError("the requested story sprite geometry has no usable area")

    atlas = Image.new(
        "RGBA", (CELL_WIDTH * COLUMNS, CELL_HEIGHT), TRANSPARENT
    )
    for column, frame in enumerate(frames):
        resized = frame.resize(
            (
                max(1, round(frame.width * scale)),
                max(1, round(frame.height * scale)),
            ),
            Image.Resampling.NEAREST,
        )
        _harden_alpha(resized)
        x = column * CELL_WIDTH + (CELL_WIDTH - resized.width) // 2
        y = CELL_HEIGHT - GUTTER_BOTTOM - resized.height
        atlas.alpha_composite(resized, (x, y))

    _clear_gutters(atlas)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.out, format="PNG", optimize=True)
    print(
        f"Wrote {args.out} ({atlas.width}x{atlas.height}, "
        f"{COLUMNS} frames, scale {scale:.4f})"
    )


def _harden_alpha(image: Image.Image) -> None:
    pixels = image.load()
    assert pixels is not None
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (
                (red, green, blue, 255)
                if alpha >= 128
                else TRANSPARENT
            )


def _visible_bounds(image: Image.Image) -> tuple[int, int, int, int] | None:
    visible_alpha = image.getchannel("A").point(
        lambda alpha: 255 if alpha >= 128 else 0
    )
    return visible_alpha.getbbox()


def _clear_gutters(image: Image.Image) -> None:
    pixels = image.load()
    assert pixels is not None
    for y in range(image.height):
        for x in range(image.width):
            local_x = x % CELL_WIDTH
            if (
                local_x < GUTTER_X
                or local_x >= CELL_WIDTH - GUTTER_X
                or y < GUTTER_TOP
                or y >= CELL_HEIGHT - GUTTER_BOTTOM
            ):
                pixels[x, y] = TRANSPARENT


if __name__ == "__main__":
    main()
