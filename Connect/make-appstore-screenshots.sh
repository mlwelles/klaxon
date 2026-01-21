#!/bin/bash
#
# Creates App Store-ready screenshots in multiple formats and sizes
# Generates all variants to find what App Store Connect accepts
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_DIR="$SCRIPT_DIR/Screenshots"
OUTPUT_DIR="$SCRIPT_DIR/Screenshots/AppStore"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Mac App Store accepted sizes
SIZES=(
    "2880x1800"
    "2560x1600"
    "1440x900"
)

# Background color for padding
BG_COLOR="#1e1e1e"

echo "=== Creating App Store Screenshots (All Sizes & Formats) ==="
echo ""

# Screenshot mappings: input -> output base name -> display name
SCREENSHOTS=(
    "06-alert.png:01-alert:Alert Window"
    "01-menubar.png:02-menubar:Menu Bar"
    "03-preferences-alerts.png:03-preferences-alerts:Preferences - Alerts"
    "04-preferences-calendars.png:04-preferences-calendars:Preferences - Calendars"
    "02-preferences-startup.png:05-preferences-startup:Preferences - Startup"
    "05-about.png:06-about:About Window"
)

create_all_variants() {
    local input="$1"
    local output_base="$2"
    local name="$3"

    if [ ! -f "$INPUT_DIR/$input" ]; then
        echo "⚠ Skipping $input (not found)"
        return
    fi

    echo "Creating variants for: $name"

    for size in "${SIZES[@]}"; do
        local width="${size%x*}"
        local height="${size#*x}"
        local size_suffix="${width}x${height}"

        # Create temp scaled base
        local temp_base="/tmp/screenshot_base_$$.png"

        magick "$INPUT_DIR/$input" \
            -resize ${width}x${height}^ \
            -gravity center \
            -extent ${width}x${height} \
            -background "$BG_COLOR" \
            "$temp_base"

        # PNG - Flattened RGB (most compatible)
        magick "$temp_base" \
            -flatten \
            -type TrueColor \
            -colorspace sRGB \
            -define png:color-type=2 \
            "$OUTPUT_DIR/${output_base}-${size_suffix}-rgb.png"
        echo "  ✓ ${output_base}-${size_suffix}-rgb.png"

        # PNG - sips processed (Apple native)
        cp "$temp_base" "$OUTPUT_DIR/${output_base}-${size_suffix}-sips.png"
        sips -s format png \
             -m "/System/Library/ColorSync/Profiles/sRGB Profile.icc" \
             "$OUTPUT_DIR/${output_base}-${size_suffix}-sips.png" >/dev/null 2>&1
        echo "  ✓ ${output_base}-${size_suffix}-sips.png"

        # JPEG - High quality (App Store accepts JPEG too)
        magick "$temp_base" \
            -flatten \
            -colorspace sRGB \
            -quality 95 \
            "$OUTPUT_DIR/${output_base}-${size_suffix}.jpg"
        echo "  ✓ ${output_base}-${size_suffix}.jpg"

        rm -f "$temp_base"
    done
    echo ""
}

# Process each screenshot
for entry in "${SCREENSHOTS[@]}"; do
    IFS=':' read -r input output_base name <<< "$entry"
    create_all_variants "$input" "$output_base" "$name"
done

echo "=== Done ==="
echo ""
echo "Generated sizes:"
for size in "${SIZES[@]}"; do
    echo "  - $size"
done
echo ""
echo "Formats per size:"
echo "  *-rgb.png  - Flattened RGB PNG (no alpha)"
echo "  *-sips.png - Apple sips with sRGB profile"
echo "  *.jpg      - JPEG 95% quality"
echo ""
echo "Try uploading in this order:"
echo "  1. 2880x1800 files first (preferred Retina size)"
echo "  2. If those fail, try 1440x900 (standard size)"
echo "  3. Try JPEG if PNG keeps failing"
echo ""
ls -lh "$OUTPUT_DIR" | head -25
echo "..."
echo ""
echo "Total files: $(ls -1 "$OUTPUT_DIR" | wc -l | tr -d ' ')"
echo "Screenshots saved to: $OUTPUT_DIR"
