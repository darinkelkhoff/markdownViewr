default:
    @just --list

# Kill the running app
kill:
    -killall -9 markdownViewr 2>/dev/null

# Build the app
build:
    xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -destination 'platform=macOS' build

# Kill, build, and launch the app
run: kill build
    @open "$(xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/markdownViewr.app"

# Open a specific markdown file
open file: build
    @open -a "$(xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/markdownViewr.app" "{{file}}"

# Regenerate the Xcode project from project.yml
generate:
    xcodegen generate

# Clean build artifacts
clean:
    xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr clean

# Archive, notarize, and publish a GitHub release (bump MARKETING_VERSION in project.yml first)
release: kill
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
    ARCHIVE="/tmp/markdownViewr.xcarchive"
    EXPORT="/tmp/markdownViewr-export"
    ZIP="/tmp/markdownViewr-$VERSION.zip"
    echo "==> Archiving v$VERSION..."
    rm -rf "$ARCHIVE" "$EXPORT"
    xcodebuild archive \
        -project markdownViewr.xcodeproj \
        -scheme markdownViewr \
        -archivePath "$ARCHIVE" \
        -destination 'generic/platform=macOS' \
        ENABLE_HARDENED_RUNTIME=YES | xcpretty || true
    echo "==> Exporting with Developer ID signing..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportPath "$EXPORT" \
        -exportOptionsPlist ExportOptions.plist
    echo "==> Notarizing (this takes a minute)..."
    ditto -c -k --keepParent "$EXPORT/markdownViewr.app" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "markdownViewr-notarytool" --wait
    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$EXPORT/markdownViewr.app"
    echo "==> Packaging final release..."
    ditto -c -k --keepParent "$EXPORT/markdownViewr.app" "$ZIP"
    echo "==> Creating GitHub release v$VERSION..."
    gh release create "v$VERSION" "$ZIP" \
        --repo darinkelkhoff/markdownViewr \
        --title "markdownViewr v$VERSION" \
        --generate-notes
    echo ""
    echo "Done! https://github.com/darinkelkhoff/markdownViewr/releases/tag/v$VERSION"
