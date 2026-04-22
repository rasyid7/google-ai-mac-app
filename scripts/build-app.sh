#!/bin/bash

# Build script for Google AI Desktop (macOS)
# Usage: ./scripts/build-app.sh [debug|release|archive|dmg]
#   debug   - Build Debug configuration (default)
#   release - Build Release configuration
#   archive - Build, archive, and export Release app
#   dmg     - Build Release, export, and create DMG

set -e

# ── Configuration ────────────────────────────────────────────────────────────

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="GoogleAiDesktop"
SCHEME="GoogleAiDesktop"
APP_NAME="Google AI Desktop"
BUNDLE_ID="com.rasyid7.googleaidesktop"

OUTPUT_BASE="$HOME/Downloads/GoogleAIDesktop"
ARCHIVE_PATH="$OUTPUT_BASE/GoogleAIDesktop.xcarchive"
EXPORT_PATH="$OUTPUT_BASE"
DERIVED_DATA_PATH="$PROJECT_DIR/build/DerivedData"

# ── Parse Arguments ──────────────────────────────────────────────────────────

MODE="${1:-debug}"

if [[ "$MODE" != "debug" && "$MODE" != "release" && "$MODE" != "archive" && "$MODE" != "dmg" ]]; then
    echo "Usage: $0 [debug|release|archive|dmg]"
    echo ""
    echo "  debug   - Build Debug configuration (fast, for testing)"
    echo "  release - Build Release configuration (optimized)"
    echo "  archive - Archive and export Release app (for distribution)"
    echo "  dmg     - Full pipeline: archive + export + create DMG"
    exit 1
fi

# ── Helpers ──────────────────────────────────────────────────────────────────

print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ── Main ─────────────────────────────────────────────────────────────────────

cd "$PROJECT_DIR"

if [[ "$MODE" == "debug" ]]; then
    print_header "Building Debug Configuration"

    xcodebuild \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination 'platform=macOS' \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        build

    BUILT_APP="$DERIVED_DATA_PATH/Build/Products/Debug/${APP_NAME}.app"
    echo ""
    echo "✅ Debug build complete"
    echo "   App: $BUILT_APP"
    open $DERIVED_DATA_PATH/Build/Products/Debug/
    echo ""

elif [[ "$MODE" == "release" ]]; then
    print_header "Building Release Configuration"

    xcodebuild \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination 'platform=macOS' \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        build

    BUILT_APP="$DERIVED_DATA_PATH/Build/Products/Release/${APP_NAME}.app"
    echo ""
    echo "✅ Release build complete"
    echo "   App: $BUILT_APP"
    echo ""

elif [[ "$MODE" == "archive" || "$MODE" == "dmg" ]]; then
    print_header "Archiving Release Build"

    mkdir -p "$OUTPUT_BASE"

    xcodebuild \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        archive

    echo ""
    echo "✅ Archive created: $ARCHIVE_PATH"

    # ── Export Archive ───────────────────────────────────────────────────────

    print_header "Exporting Archive"

    EXPORT_OPTIONS="$OUTPUT_BASE/ExportOptions.plist"
    cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | awk -F'(' '{print $2}' | tr -d ')')</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

    xcodebuild \
        -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS"

    rm "$EXPORT_OPTIONS"

    echo ""
    echo "✅ Exported to: $EXPORT_PATH/${APP_NAME}.app"

    # ── Create DMG (optional) ──────────────────────────────────────────────

    if [[ "$MODE" == "dmg" ]]; then
        print_header "Creating DMG"

        if [ -f "$PROJECT_DIR/scripts/create-dmg.sh" ]; then
            "$PROJECT_DIR/scripts/create-dmg.sh"
        else
            echo "⚠️  create-dmg.sh not found at scripts/create-dmg.sh"
        fi
    fi
fi

print_header "Done"
