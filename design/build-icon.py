"""Derive the shipped icon assets from design/icon-source.png.

WoW wants a power-of-two, uncompressed 32-bit TGA for a custom IconTexture.
CurseForge wants a square PNG for the project avatar. Both come from the same
source art, so re-run this after replacing icon-source.png.

    python design/build-icon.py
"""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "design" / "icon-source.png"
MEDIA = ROOT / "Media"
DESIGN = ROOT / "design"


def square(img):
    """Centre-crop to 1:1 so nothing stretches when we resize."""
    w, h = img.size
    if w == h:
        return img
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    return img.crop((left, top, left + side, top + side))


def main():
    if not SOURCE.exists():
        raise SystemExit(f"missing source art: {SOURCE}")

    MEDIA.mkdir(exist_ok=True)
    img = square(Image.open(SOURCE).convert("RGBA"))

    # In-game AddOns-list icon. 64x64 matches Blizzard's own icon textures.
    icon = img.resize((64, 64), Image.LANCZOS)
    icon.save(MEDIA / "Icon.tga", format="TGA", compression=None)

    # A 128 variant, in case the list ever renders larger than 64.
    img.resize((128, 128), Image.LANCZOS).save(
        MEDIA / "Icon128.tga", format="TGA", compression=None
    )

    # CurseForge project avatar.
    img.resize((400, 400), Image.LANCZOS).save(DESIGN / "curseforge-avatar.png")

    # GitHub social preview is 1280x640; centre the icon on a dark field.
    social = Image.new("RGBA", (1280, 640), (14, 13, 17, 255))
    art = img.resize((560, 560), Image.LANCZOS)
    social.alpha_composite(art, (360, 40))
    social.convert("RGB").save(DESIGN / "github-social.png")

    for p in (
        MEDIA / "Icon.tga",
        MEDIA / "Icon128.tga",
        DESIGN / "curseforge-avatar.png",
        DESIGN / "github-social.png",
    ):
        print(f"{p.relative_to(ROOT)}  {p.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
