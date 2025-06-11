#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Pactus GUI for macOS...${NC}"

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
flutter clean
rm -rf build/macos

# Build Flutter macOS app
echo -e "${YELLOW}Building Flutter macOS app...${NC}"
flutter build macos --release

# Check if build was successful
if [ ! -d "build/macos/Build/Products/Release/gui.app" ]; then
    echo -e "${RED}Error: Flutter build failed!${NC}"
    exit 1
fi

# Create a temporary directory for DMG contents
APP_NAME="Pactus GUI"
DMG_NAME="PactusGUI"
TEMP_DIR="temp_dmg"
APP_PATH="build/macos/Build/Products/Release/gui.app"

echo -e "${YELLOW}Preparing DMG contents...${NC}"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Copy the app bundle
cp -R "$APP_PATH" "$TEMP_DIR/$APP_NAME.app"

# Create the native resources directory structure inside the app bundle
RESOURCES_DIR="$TEMP_DIR/$APP_NAME.app/Contents/Resources"
mkdir -p "$RESOURCES_DIR/lib/src/core/native_resources/macos"

# Copy native resources (daemon and wallet files)
echo -e "${YELLOW}Copying native resources...${NC}"
cp lib/src/core/native_resources/macos/* "$RESOURCES_DIR/lib/src/core/native_resources/macos/"

# Make native resources executable
chmod +x "$RESOURCES_DIR/lib/src/core/native_resources/macos/"*

# Create the launch script inside the app bundle
echo -e "${YELLOW}Creating launch wrapper...${NC}"
cat > "$TEMP_DIR/$APP_NAME.app/Contents/MacOS/gui_original" << 'EOF'
#!/bin/bash

# Get the directory where this script is located (Contents/MacOS)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_CONTENTS="$(dirname "$HERE")"

# Set the path to native resources for macOS
export PACTUS_NATIVE_RESOURCES="$APP_CONTENTS/Resources/lib/src/core/native_resources/macos"

# Launch the actual GUI application
exec "$HERE/gui_flutter" "$@"
EOF

# Rename the original executable and replace with our wrapper
mv "$TEMP_DIR/$APP_NAME.app/Contents/MacOS/gui" "$TEMP_DIR/$APP_NAME.app/Contents/MacOS/gui_flutter"
mv "$TEMP_DIR/$APP_NAME.app/Contents/MacOS/gui_original" "$TEMP_DIR/$APP_NAME.app/Contents/MacOS/gui"
chmod +x "$TEMP_DIR/$APP_NAME.app/Contents/MacOS/gui"

# Create a symbolic link to Applications folder for easy installation
ln -s /Applications "$TEMP_DIR/Applications"

# Create DMG
echo -e "${YELLOW}Creating DMG file...${NC}"
DMG_PATH="$DMG_NAME.dmg"
rm -f "$DMG_PATH"

# Create the DMG
hdiutil create -volname "$APP_NAME" -srcfolder "$TEMP_DIR" -ov -format UDZO "$DMG_PATH"

# Clean up temporary directory
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ DMG created successfully: $DMG_PATH${NC}"
echo -e "${GREEN}You can now distribute this DMG file to users.${NC}"
echo -e "${YELLOW}To install: Mount the DMG and drag '$APP_NAME.app' to the Applications folder.${NC}"

# Optional: Open the DMG to test
read -p "Do you want to open the DMG to test it? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$DMG_PATH"
fi 