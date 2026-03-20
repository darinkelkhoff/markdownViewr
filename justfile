# Build and run markdownViewr

kill:
   killall -9 markdownViewr || true

# Build the app
build:
    xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -destination 'platform=macOS' build

# Build and open the app
run: build
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
