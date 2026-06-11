#!/bin/bash
# Pixel Pathfinder Build Script

set -e

echo "========================================"
echo "Pixel Pathfinder - Build Script"
echo "========================================"

# Check if Godot is available
GODOT_CMD=""
if command -v godot &> /dev/null; then
    GODOT_CMD="godot"
elif [ -f "../godot/Godot_v4.3-stable_linux.x86_64" ]; then
    GODOT_CMD="../godot/Godot_v4.3-stable_linux.x86_64"
elif [ -f "/home/kimi/godot/Godot_v4.3-stable_linux.x86_64" ]; then
    GODOT_CMD="/home/kimi/godot/Godot_v4.3-stable_linux.x86_64"
else
    echo "ERROR: Godot not found!"
    echo "Please install Godot 4.x and ensure it's in PATH"
    exit 1
fi

echo "Using Godot: $GODOT_CMD"
echo ""

# Create build directory
mkdir -p build

# Export for Windows
echo "Exporting Windows executable..."
$GODOT_CMD --headless --path . --export-release "Windows Desktop" ./build/PixelPathfinder.exe

echo ""
echo "========================================"
echo "Build complete!"
echo "Output: ./build/PixelPathfinder.exe"
echo "========================================"
