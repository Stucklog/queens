#!/usr/bin/env python3
"""Build the combat renderer's 4x6 reaction atlas from one pixel-art cutout."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


CELL = 192
COLUMNS = 4
ROWS = 6
GUTTER = 8
TRANSPARENT = (0, 0, 0, 0)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--band-index", type=int)
    parser.add_argument("--band-count", type=int)
    parser.add_argument("--crop", help="left,top,right,bottom source crop")
    args = parser.parse_args()

    with Image.open(args.input) as source:
        source = source.convert("RGBA")
    if args.crop:
        crop = tuple(int(value) for value in args.crop.split(","))
        if len(crop) != 4:
            raise ValueError("--crop requires left,top,right,bottom")
        source = source.crop(crop)
    elif args.band_index is not None and args.band_count is not None:
        if not 0 <= args.band_index < args.band_count:
            raise ValueError("band index must be inside band count")
        top = round(source.height * args.band_index / args.band_count)
        bottom = round(source.height * (args.band_index + 1) / args.band_count)
        source = source.crop((0, top, source.width, bottom))
    else:
        raise ValueError("provide either --crop or both band arguments")

    bounds = source.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("source crop contains no opaque creature pixels")
    base = source.crop(bounds)
    atlas = Image.new("RGBA", (CELL * COLUMNS, CELL * ROWS), TRANSPARENT)
    for row in range(ROWS):
        for frame in range(COLUMNS):
            _draw_frame(atlas, base, row=row, frame=frame)
    _clear_gutters(atlas)
    _harden_alpha(atlas)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.out, format="PNG", optimize=True)
    print(f"Wrote {args.out} ({atlas.width}x{atlas.height}, 4x6)")


def _draw_frame(atlas: Image.Image, base: Image.Image, *, row: int, frame: int) -> None:
    scale = (
        (0.91, 0.95, 0.98, 0.94),
        (0.92, 0.96, 0.99, 0.96),
        (0.90, 0.93, 0.95, 0.92),
        (0.94, 0.91, 0.95, 0.89),
        (0.90, 0.94, 0.98, 0.94),
        (0.91, 0.86, 0.80, 0.73),
    )[row][frame]
    max_width = 168
    max_height = 158
    fit = min(max_width / base.width, max_height / base.height) * scale
    sprite = base.resize(
        (max(1, round(base.width * fit)), max(1, round(base.height * fit))),
        Image.Resampling.NEAREST,
    )

    rotation = (
        (0, 0, 0, 0),
        (2, -3, -7, -11),
        (0, 1, 0, -1),
        (4, -5, 7, -8),
        (0, -2, 2, 0),
        (8, 24, 48, 76),
    )[row][frame]
    if rotation:
        sprite = sprite.rotate(
            rotation,
            resample=Image.Resampling.NEAREST,
            expand=True,
            fillcolor=TRANSPARENT,
        )
    if row == 3:
        sprite = _tint_damage(sprite, frame)

    cell_left = frame * CELL
    cell_top = row * CELL
    draw = ImageDraw.Draw(atlas)
    center_x = cell_left + CELL // 2
    center_y = cell_top + CELL // 2
    _draw_effects_before(draw, row, frame, center_x, center_y)

    offset_x = (
        (0, 1, 0, -1),
        (5, -3, -11, -18),
        (2, 5, 7, 4),
        (0, 7, -7, 4),
        (0, -2, 2, 0),
        (2, 7, 12, 16),
    )[row][frame]
    offset_y = (
        (3, 0, -2, 1),
        (2, 1, 0, 2),
        (4, 2, 1, 3),
        (2, -1, 3, 1),
        (3, 0, -2, 1),
        (8, 17, 29, 39),
    )[row][frame]
    x = center_x - sprite.width // 2 + offset_x
    y = center_y - sprite.height // 2 + offset_y
    atlas.alpha_composite(sprite, (x, y))
    _draw_effects_after(draw, row, frame, center_x, center_y)


def _tint_damage(sprite: Image.Image, frame: int) -> Image.Image:
    red_boost = (30, 48, 66, 82)[frame]
    pixels = sprite.load()
    assert pixels is not None
    for y in range(sprite.height):
        for x in range(sprite.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha:
                pixels[x, y] = (
                    min(255, red + red_boost),
                    max(0, green - red_boost // 4),
                    max(0, blue - red_boost // 5),
                    255,
                )
    return sprite


def _draw_effects_before(
    draw: ImageDraw.ImageDraw,
    row: int,
    frame: int,
    center_x: int,
    center_y: int,
) -> None:
    if row == 2:
        radius = 64 + frame * 2
        draw.arc(
            (center_x - radius, center_y - radius, center_x + radius, center_y + radius),
            145 - frame * 12,
            225 + frame * 9,
            fill=(82, 225, 230, 255),
            width=5,
        )
        draw.arc(
            (center_x - radius + 5, center_y - radius + 5, center_x + radius - 5, center_y + radius - 5),
            150 - frame * 12,
            220 + frame * 9,
            fill=(238, 186, 71, 255),
            width=3,
        )
    elif row == 4:
        radius = 48 + frame * 7
        draw.ellipse(
            (center_x - radius, center_y - radius, center_x + radius, center_y + radius),
            outline=(62, 207, 222, 255),
            width=4,
        )
        draw.arc(
            (center_x - radius - 8, center_y - radius + 6, center_x + radius + 8, center_y + radius - 6),
            205 + frame * 22,
            330 + frame * 22,
            fill=(244, 190, 67, 255),
            width=5,
        )


def _draw_effects_after(
    draw: ImageDraw.ImageDraw,
    row: int,
    frame: int,
    center_x: int,
    center_y: int,
) -> None:
    if row == 1 and frame > 0:
        reach = 38 + frame * 13
        draw.line(
            (center_x - 18, center_y - 24, center_x - reach, center_y + 18),
            fill=(255, 222, 115, 255),
            width=5,
        )
        draw.line(
            (center_x - 14, center_y - 29, center_x - reach + 5, center_y + 13),
            fill=(255, 116, 67, 255),
            width=3,
        )
    elif row == 3:
        hit_x = center_x - 48 + frame * 4
        hit_y = center_y - 38 + (frame % 2) * 9
        color = (255, 235, 150, 255)
        draw.rectangle((hit_x - 3, hit_y - 13, hit_x + 3, hit_y + 13), fill=color)
        draw.rectangle((hit_x - 13, hit_y - 3, hit_x + 13, hit_y + 3), fill=color)
    elif row == 4:
        for spark in range(frame + 2):
            x = center_x - 64 + spark * 27
            y = center_y - 66 + ((spark + frame) % 3) * 13
            draw.rectangle((x, y, x + 5, y + 5), fill=(255, 225, 102, 255))


def _clear_gutters(atlas: Image.Image) -> None:
    pixels = atlas.load()
    assert pixels is not None
    for y in range(atlas.height):
        local_y = y % CELL
        for x in range(atlas.width):
            local_x = x % CELL
            if (
                local_x < GUTTER
                or local_x >= CELL - GUTTER
                or local_y < GUTTER
                or local_y >= CELL - GUTTER
            ):
                pixels[x, y] = TRANSPARENT


def _harden_alpha(atlas: Image.Image) -> None:
    pixels = atlas.load()
    assert pixels is not None
    for y in range(atlas.height):
        for x in range(atlas.width):
            red, green, blue, alpha = pixels[x, y]
            chroma_fringe = red > 210 and blue > 210 and green < 130
            pixels[x, y] = (
                (red, green, blue, 255)
                if alpha >= 128 and not chroma_fringe
                else TRANSPARENT
            )


if __name__ == "__main__":
    main()
