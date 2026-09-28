"""Strips the alpha channel from the iOS app icons (App Store Connect rejects
icons with transparency). Run after `flutter test tool/generate_icons_test.dart`."""
from pathlib import Path

from PIL import Image

ICONS = Path(__file__).resolve().parent.parent / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
INK = (0x15, 0x12, 0x1F)

for png in ICONS.glob("*.png"):
    img = Image.open(png).convert("RGBA")
    flat = Image.new("RGB", img.size, INK)
    flat.paste(img, mask=img.split()[3])
    flat.save(png, optimize=True)
    print("flattened", png.name)
