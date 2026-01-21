#!/bin/bash
#
# Creates App Store-ready screenshots at highest resolution (2880x1800) as JPEG
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_DIR="$SCRIPT_DIR/Screenshots"
OUTPUT_DIR="$SCRIPT_DIR/Screenshots/Generated"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Highest resolution for Mac App Store
WIDTH=2880
HEIGHT=1800

# Background color for padding
BG_COLOR="#1e1e1e"

echo "=== Creating App Store Screenshots (${WIDTH}x${HEIGHT} JPEG) ==="
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

create_screenshot() {
    local input="$1"
    local output_base="$2"
    local name="$3"

    if [ ! -f "$INPUT_DIR/$input" ]; then
        echo "⚠ Skipping $input (not found)"
        return
    fi

    echo "Creating: $name"

    # Create high-quality JPEG at 2880x1800
    magick "$INPUT_DIR/$input" \
        -resize ${WIDTH}x${HEIGHT}^ \
        -gravity center \
        -extent ${WIDTH}x${HEIGHT} \
        -background "$BG_COLOR" \
        -flatten \
        -colorspace sRGB \
        -quality 95 \
        "$OUTPUT_DIR/${output_base}.jpg"

    echo "  ✓ ${output_base}.jpg"
}

# Process each screenshot
for entry in "${SCREENSHOTS[@]}"; do
    IFS=':' read -r input output_base name <<< "$entry"
    create_screenshot "$input" "$output_base" "$name"
done

echo ""
echo "=== Done ==="
echo ""
echo "Generated ${WIDTH}x${HEIGHT} JPEG screenshots:"
ls -lh "$OUTPUT_DIR"
echo ""
echo "Screenshots saved to: $OUTPUT_DIR"
