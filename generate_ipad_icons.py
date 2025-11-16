#!/usr/bin/env python3
"""
Generate missing iPad icon sizes from the 1024x1024 AppIcon source.
This fixes the App Store validation error:
"Missing required icon file. The bundle does not contain an app icon for iPad of exactly '152x152' pixels"
"""

from PIL import Image
import os

# Path to the source icon and output directory
source_icon = "mobile/ios-field-utility/SkyFeederFieldUtility/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon1024x1024.png"
output_dir = "mobile/ios-field-utility/SkyFeederFieldUtility/Resources/Assets.xcassets/AppIcon.appiconset"

# iPad icon sizes that are missing
ipad_icon_sizes = [
    ("AppIcon20x20@1x.png", 20),
    ("AppIcon29x29@1x.png", 29),
    ("AppIcon40x40@1x.png", 40),
    ("AppIcon76x76@1x.png", 76),
    ("AppIcon76x76@2x.png", 152),  # This is the critical missing 152x152 icon
    ("AppIcon83.5x83.5@2x.png", 167),  # iPad Pro
]

def main():
    # Load the source 1024x1024 icon
    print(f"Loading source icon: {source_icon}")
    img = Image.open(source_icon)

    if img.size != (1024, 1024):
        print(f"Warning: Source icon is {img.size}, expected (1024, 1024)")

    # Generate each required size
    for filename, size in ipad_icon_sizes:
        output_path = os.path.join(output_dir, filename)

        # Resize using high-quality LANCZOS filter
        resized = img.resize((size, size), Image.Resampling.LANCZOS)

        # Save as PNG
        resized.save(output_path, "PNG")
        print(f"Generated {filename} ({size}x{size})")

    print(f"\nSuccessfully generated {len(ipad_icon_sizes)} iPad icons")

if __name__ == "__main__":
    main()
