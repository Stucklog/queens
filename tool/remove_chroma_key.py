#!/usr/bin/env python3
"""Remove an authored flat chroma matte and emit binary-alpha PNG art."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


TRANSPARENT = (0, 0, 0, 0)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--key", required=True, type=_parse_hex)
    parser.add_argument(
        "--tolerance",
        type=int,
        default=96,
        help="maximum RGB Euclidean distance from the matte color",
    )
    args = parser.parse_args()
    if not 0 <= args.tolerance <= 441:
        raise ValueError("tolerance must be between 0 and 441")

    with Image.open(args.input) as source_image:
        image = source_image.convert("RGBA")
    _remove_matte(image, key=args.key, tolerance=args.tolerance)
    if image.getchannel("A").getbbox() is None:
        raise ValueError("chroma removal erased the entire image")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.out, format="PNG", optimize=True)
    print(f"Wrote {args.out} ({image.width}x{image.height}, binary alpha)")


def _parse_hex(value: str) -> tuple[int, int, int]:
    normalized = value.removeprefix("#")
    if len(normalized) != 6:
        raise argparse.ArgumentTypeError("key must be a six-digit RGB hex color")
    try:
        return tuple(int(normalized[index:index + 2], 16) for index in (0, 2, 4))
    except ValueError as error:
        raise argparse.ArgumentTypeError("key must be hexadecimal") from error


def _remove_matte(
    image: Image.Image, *, key: tuple[int, int, int], tolerance: int
) -> None:
    pixels = image.load()
    assert pixels is not None
    tolerance_squared = tolerance * tolerance
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            distance_squared = (
                (red - key[0]) ** 2
                + (green - key[1]) ** 2
                + (blue - key[2]) ** 2
            )
            if alpha < 128 or distance_squared <= tolerance_squared:
                pixels[x, y] = TRANSPARENT
            else:
                pixels[x, y] = (red, green, blue, 255)


if __name__ == "__main__":
    main()
