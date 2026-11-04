"""Draw the pyZDL launcher icon: a Python-logo emblem on a DOOM-style backdrop.

Writes assets/pyzdl-launcher.png and assets/pyzdl-launcher.ico.
"""

import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
SIZE = 1024
PYTHON_BLUE = (55, 118, 171)
PYTHON_YELLOW = (255, 212, 59)
DARK_RED = (40, 8, 8)
HELL_RED = (175, 28, 18)
GOLD = (200, 150, 60)
INK = (20, 20, 20)
WHITE = (250, 250, 250)


def backdrop():
    glow = Image.radial_gradient("L").resize((SIZE, SIZE), Image.LANCZOS)
    dark = Image.new("RGBA", (SIZE, SIZE), DARK_RED + (255,))
    hot = Image.new("RGBA", (SIZE, SIZE), HELL_RED + (255,))
    return Image.composite(dark, hot, glow)


def eye(draw, center, radius=54):
    x, y = center
    draw.ellipse(
        (x - radius, y - radius, x + radius, y + radius),
        fill=WHITE,
        outline=INK,
        width=8,
    )
    pupil = radius // 2
    draw.ellipse((x - pupil, y - pupil, x + pupil, y + pupil), fill=INK)


def draw_icon():
    canvas = backdrop()
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), 200, fill=255)
    canvas.putalpha(mask)

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((28, 28, SIZE - 29, SIZE - 29), 180, outline=GOLD, width=28)

    draw.rounded_rectangle(
        (220, 230, 630, 640), 160, fill=PYTHON_BLUE, outline=INK, width=12
    )
    draw.rounded_rectangle(
        (390, 380, 800, 790), 160, fill=PYTHON_YELLOW, outline=INK, width=12
    )
    eye(draw, (370, 370))
    eye(draw, (650, 650))
    return canvas


def save_ico(image, path):
    side = max(image.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(image, ((side - image.width) // 2, (side - image.height) // 2))
    square.save(path, format="ICO", sizes=ICO_SIZES)


if __name__ == "__main__":
    icon = draw_icon()
    assets = os.path.join(ROOT, "assets")
    icon.resize((512, 512), Image.LANCZOS).save(
        os.path.join(assets, "pyzdl-launcher.png")
    )
    save_ico(icon, os.path.join(assets, "pyzdl-launcher.ico"))
    print("Wrote assets/pyzdl-launcher.png and assets/pyzdl-launcher.ico")
