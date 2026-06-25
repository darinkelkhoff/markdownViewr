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
    @open -n "$(xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/markdownViewr.app"

# Open a specific markdown file
open file: build
    @open -n "$(xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/markdownViewr.app" "{{file}}"

# Run the test suite
test:
    xcodebuild test -project markdownViewr.xcodeproj -scheme markdownViewr -destination 'platform=macOS'

# Update the Homebrew cask to match the current release (run after a successful just release)
update-cask:
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
    DMG="/tmp/markdownViewr.dmg"
    if [[ ! -f "$DMG" ]]; then
        echo "==> Downloading DMG for v$VERSION..."
        gh release download "v$VERSION" --repo darinkelkhoff/markdownViewr --pattern "markdownViewr.dmg" --dir /tmp --clobber
    fi
    DMG_SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
    TAP_DIR="/tmp/markdownViewr-homebrew-tap"
    rm -rf "$TAP_DIR"
    git clone git@github.com:darinkelkhoff/homebrew-tap.git "$TAP_DIR"
    sed -i.bak "s/version \".*\"/version \"$VERSION\"/" "$TAP_DIR/Casks/markdownviewr.rb"
    sed -i.bak "s/sha256 \".*\"/sha256 \"$DMG_SHA\"/" "$TAP_DIR/Casks/markdownviewr.rb"
    rm -f "$TAP_DIR/Casks/markdownviewr.rb.bak"
    git -C "$TAP_DIR" add Casks/markdownviewr.rb
    git -C "$TAP_DIR" commit -m "markdownViewr: update to v$VERSION"
    git -C "$TAP_DIR" push origin main
    echo "Done! brew install --cask darinkelkhoff/tap/markdownviewr"

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
    MAJOR=$(echo "$VERSION" | cut -d. -f1)
    MINOR=$(echo "$VERSION" | cut -d. -f2)
    PATCH=$(echo "$VERSION" | cut -d. -f3)
    BUILD_NUMBER=$(( MAJOR * 10000 + MINOR * 100 + PATCH ))
    echo "==> Regenerating Xcode project..."
    xcodegen generate
    LATEST=$(gh release list --repo darinkelkhoff/markdownViewr --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || echo "none")
    if [[ "$LATEST" == "v$VERSION" ]]; then
        echo "Error: v$VERSION is already released. Bump MARKETING_VERSION in project.yml first."
        exit 1
    fi
    ARCHIVE="/tmp/markdownViewr.xcarchive"
    EXPORT="/tmp/markdownViewr-export"
    ZIP="/tmp/markdownViewr-$VERSION.zip"
    echo "==> Archiving v$VERSION (build $BUILD_NUMBER)..."
    rm -rf "$ARCHIVE" "$EXPORT" "$ZIP"
    xcodebuild archive \
        -project markdownViewr.xcodeproj \
        -scheme markdownViewr \
        -archivePath "$ARCHIVE" \
        -destination 'generic/platform=macOS' \
        ENABLE_HARDENED_RUNTIME=YES \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER" | xcpretty || true
    echo "==> Exporting with Developer ID signing..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportPath "$EXPORT" \
        -exportOptionsPlist ExportOptions.plist
    APP="$EXPORT/markdownViewr.app"
    if [[ ! -d "$APP" ]]; then
        echo "Error: expected $APP but found: $(ls "$EXPORT")"
        exit 1
    fi
    echo "==> Notarizing (this takes a minute)..."
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "markdownViewr-notarytool" --wait
    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$APP"
    echo "==> Packaging final release..."
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "==> Creating DMG..."
    DMG="/tmp/markdownViewr.dmg"
    DMG_STAGING="/tmp/markdownViewr-dmg-staging"
    rm -f "$DMG"
    rm -rf "$DMG_STAGING"
    mkdir "$DMG_STAGING"
    cp -R "$APP" "$DMG_STAGING/"
    create-dmg \
        --volname "markdownViewr" \
        --window-size 660 400 \
        --icon-size 128 \
        --icon "markdownViewr.app" 180 185 \
        --hide-extension "markdownViewr.app" \
        --app-drop-link 480 185 \
        "$DMG" \
        "$DMG_STAGING/"
    echo "==> Creating GitHub release v$VERSION..."
    gh release create "v$VERSION" "$DMG" "$ZIP" \
        --repo darinkelkhoff/markdownViewr \
        --title "markdownViewr v$VERSION" \
        --generate-notes
    echo "==> Updating appcast..."
    SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -path "*/artifacts/sparkle/Sparkle/bin" -type d 2>/dev/null | head -1)
    if [[ -z "$SPARKLE_BIN" ]]; then
        echo "Error: Sparkle tools not found in DerivedData. Run 'just build' first."
        exit 1
    fi
    rm -rf /tmp/markdownViewr-appcast-input
    mkdir -p /tmp/markdownViewr-appcast-input
    cp "$ZIP" /tmp/markdownViewr-appcast-input/
    "$SPARKLE_BIN/generate_appcast" \
        --download-url-prefix "https://github.com/darinkelkhoff/markdownViewr/releases/download/v$VERSION/" \
        -o appcast.xml \
        /tmp/markdownViewr-appcast-input/
    echo "==> Committing and pushing appcast..."
    git add appcast.xml
    git commit -m "release: update appcast for v$VERSION"
    git push origin main
    just update-cask
    echo ""
    echo "Done! https://github.com/darinkelkhoff/markdownViewr/releases/tag/v$VERSION"
    echo "      brew install --cask darinkelkhoff/tap/markdownviewr"

# Archive and export a signed App Store .pkg (then upload via Transporter or altool)
release-mas: kill
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
    MAJOR=$(echo "$VERSION" | cut -d. -f1)
    MINOR=$(echo "$VERSION" | cut -d. -f2)
    PATCH=$(echo "$VERSION" | cut -d. -f3)
    BUILD_NUMBER=$(( MAJOR * 10000 + MINOR * 100 + PATCH ))
    echo "==> Regenerating Xcode project..."
    xcodegen generate
    ARCHIVE="/tmp/markdownViewr-mas.xcarchive"
    EXPORT="/tmp/markdownViewr-mas-export"
    rm -rf "$ARCHIVE" "$EXPORT"
    echo "==> Archiving v$VERSION (build $BUILD_NUMBER) for the App Store..."
    xcodebuild archive \
        -project markdownViewr.xcodeproj \
        -scheme markdownViewr-MAS \
        -configuration Release \
        -archivePath "$ARCHIVE" \
        -destination 'generic/platform=macOS' \
        -allowProvisioningUpdates \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER" | xcpretty || true
    echo "==> Exporting App Store package..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportPath "$EXPORT" \
        -exportOptionsPlist ExportOptions-MAS.plist \
        -allowProvisioningUpdates
    PKG=$(find "$EXPORT" -name '*.pkg' | head -1)
    echo ""
    echo "Done! Signed App Store package:"
    echo "  $PKG"
    echo ""
    echo "Upload it with: just upload-mas"

# Key ID is read from the AuthKey_<id>.p8 filename in ~/.appstoreconnect/private_keys/;
# issuer id from ~/.appstoreconnect/issuer_id (or the ASC_ISSUER_ID env var).
# Validate and upload the exported App Store .pkg to App Store Connect
upload-mas:
    #!/usr/bin/env bash
    set -euo pipefail
    KEYS_DIR="$HOME/.appstoreconnect/private_keys"
    KEY_FILE=$(ls "$KEYS_DIR"/AuthKey_*.p8 2>/dev/null | head -1)
    [[ -n "$KEY_FILE" ]] || { echo "No AuthKey_*.p8 in $KEYS_DIR"; exit 1; }
    KEY_ID=$(basename "$KEY_FILE" .p8); KEY_ID=${KEY_ID#AuthKey_}
    ISSUER_ID="${ASC_ISSUER_ID:-$(cat "$HOME/.appstoreconnect/issuer_id" 2>/dev/null || true)}"
    [[ -n "$ISSUER_ID" ]] || { echo "Set ASC_ISSUER_ID or write it to ~/.appstoreconnect/issuer_id"; exit 1; }
    PKG="/tmp/markdownViewr-mas-export/markdownViewr.pkg"
    [[ -f "$PKG" ]] || { echo "No package at $PKG — run 'just release-mas' first."; exit 1; }
    echo "==> Validating (key $KEY_ID)..."
    xcrun altool --validate-app -f "$PKG" -t macos --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID"
    echo "==> Uploading..."
    xcrun altool --upload-app -f "$PKG" -t macos --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID"
    echo "Done! Watch App Store Connect -> your app -> Build for processing (a few minutes)."

# Show App Store Connect build + version processing state (uses the same API key)
asc-builds:
    python3 scripts/asc-builds.py
