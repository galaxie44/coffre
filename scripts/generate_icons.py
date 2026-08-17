"""Generate Coffre app icons from a master PNG."""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

from PIL import Image, ImageEnhance

MASTER = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("coffre-logo-master.png")
ROOT = Path(__file__).resolve().parents[1] / "apps" / "coffre"

ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

FOREGROUND_SCALE = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

WINDOWS_ICO_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]


def resize(img: Image.Image, size: int) -> Image.Image:
    out = img.resize((size, size), Image.Resampling.LANCZOS)
    if size <= 48:
        out = ImageEnhance.Contrast(out).enhance(1.08)
        out = ImageEnhance.Sharpness(out).enhance(1.15)
    return out


def save_png(path: Path, img: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def save_ico(path: Path, master: Image.Image) -> None:
    sizes = [
        (16, 16),
        (20, 20),
        (24, 24),
        (32, 32),
        (40, 40),
        (48, 48),
        (64, 64),
        (128, 128),
        (256, 256),
    ]
    source = resize(master, 256)
    path.parent.mkdir(parents=True, exist_ok=True)
    source.save(path, format="ICO", sizes=sizes)


def main() -> None:
    master = Image.open(MASTER).convert("RGBA")
    assets = ROOT / "assets" / "icon"
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    win = ROOT / "windows" / "runner" / "resources"

    save_png(assets / "coffre.png", resize(master, 512))

    app_icon = win / "app_icon.ico"
    save_ico(app_icon, master)
    shutil.copy2(app_icon, assets / "coffre.ico")

    for folder, size in ANDROID_SIZES.items():
        folder_path = res / folder
        save_png(folder_path / "ic_launcher.png", resize(master, size))
        fg_size = FOREGROUND_SCALE[folder]
        save_png(folder_path / "ic_launcher_foreground.png", resize(master, fg_size))

    print(f"Icons generated from {MASTER}")
    print(f"  assets: {assets}")
    print(f"  android: {res}")
    print(f"  windows: {win}")


if __name__ == "__main__":
    main()
