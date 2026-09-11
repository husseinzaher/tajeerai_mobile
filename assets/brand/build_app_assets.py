#!/usr/bin/env python3
"""Builds the logo images the app bundles, from the brand exports beside this file.

    python3 assets/brand/build_app_assets.py        # run from mobile/

Needs Pillow. Reads the official exports in assets/brand/ and writes trimmed,
downscaled copies to assets/brand/app/ — the only folder pubspec.yaml declares.
The exports are 1536x1024 canvases that are ~80% transparent margin, so shipped
as they are they would add megabytes to the binary and centre the logo inside a
box of empty space.

Nothing is redrawn, recoloured or re-typeset: every output is a crop and a
resize of an export. No coordinate is chosen by eye — margins are trimmed at the
first opaque pixel, and the mark is cut at the transparent gap that separates it
from the wordmark in the horizontal lockup. If that gap is not there, the script
stops rather than guessing.
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'app')
INK = 24   # alpha above this counts as logo, below it as anti-aliased margin
PAD = 8    # transparent margin kept around trimmed content


def ink(im):
    return im.getchannel('A').point(lambda v: 255 if v > INK else 0)


def trim(im):
    x0, y0, x1, y1 = ink(im).getbbox()
    w, h = im.size
    return im.crop((max(0, x0 - PAD), max(0, y0 - PAD), min(w, x1 + PAD), min(h, y1 + PAD)))


def fit(im, max_h):
    if im.size[1] <= max_h:
        return im
    return im.resize((round(im.size[0] * max_h / im.size[1]), max_h), Image.LANCZOS)


def save(im, name):
    path = os.path.join(OUT, name)
    im.save(path, optimize=True)
    print(f'{name:24} {im.size[0]}x{im.size[1]}  aspect={im.size[0] / im.size[1]:.4f}  '
          f'{os.path.getsize(path) // 1024} KB')


def mark_from_horizontal(im):
    """The run of inked columns before the first fully transparent one."""
    mask = ink(im)
    w, h = im.size
    x0, _, x1, _ = mask.getbbox()

    def clear(x):
        return mask.crop((x, 0, x + 1, h)).getbbox() is None

    edge = x0
    while edge < x1 and not clear(edge):
        edge += 1
    gap_end = edge
    while gap_end < x1 and clear(gap_end):
        gap_end += 1
    if edge >= x1 or gap_end - edge < 8:
        raise SystemExit('no clear gap separates the mark from the wordmark - mark.png not written')

    sx0, sy0, sx1, sy1 = mask.crop((x0, 0, edge, h)).getbbox()
    box = (x0 + sx0 - 4, sy0 - 4, x0 + sx1 + 4, sy1 + 4)
    if box[2] > gap_end:
        raise SystemExit(f'padded mark {box} would reach the wordmark at x={gap_end}')
    return im.crop(box)


def main():
    os.makedirs(OUT, exist_ok=True)
    for locale in ('en', 'ar'):
        for mode in ('light', 'dark'):
            source = Image.open(os.path.join(HERE, f'{locale}-{mode}-mode.png')).convert('RGBA')
            save(fit(trim(source), 600), f'lockup_{locale}_{mode}.png')

    horizontal = Image.open(os.path.join(HERE, 'horizontal.png')).convert('RGBA')
    save(fit(trim(horizontal), 300), 'lockup_horizontal.png')
    save(fit(mark_from_horizontal(horizontal), 512), 'mark.png')


if __name__ == '__main__':
    main()
