# CloudDrop — macOS Menu Bar App for Cloudflare R2

app_name := "CloudDrop"
build_dir := ".build/release"
bundle_dir := "build/" + app_name + ".app"

# Build debug and run
dev:
    swift build
    .build/debug/{{app_name}}

# Build release
build:
    swift build -c release

# Generate app icon
icon:
    swift Scripts/generate-icon.swift

# Create .app bundle from release build
bundle: build
    rm -rf {{bundle_dir}}
    mkdir -p {{bundle_dir}}/Contents/MacOS
    mkdir -p {{bundle_dir}}/Contents/Resources
    cp {{build_dir}}/{{app_name}} {{bundle_dir}}/Contents/MacOS/
    cp Resources/Info.plist {{bundle_dir}}/Contents/
    cp Resources/AppIcon.icns {{bundle_dir}}/Contents/Resources/
    codesign --force --sign - --entitlements Resources/CloudDrop.entitlements {{bundle_dir}}

# Run the bundled app
run: bundle
    open {{bundle_dir}}

# Install to /Applications
install: bundle
    cp -R {{bundle_dir}} /Applications/

# Clean build artifacts
clean:
    rm -rf .build build
