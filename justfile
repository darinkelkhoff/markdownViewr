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
