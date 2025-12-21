#!/bin/bash
# Script to clean up emulator storage

echo "Cleaning emulator storage..."

# Trim app caches
echo "Trimming app caches..."
adb shell pm trim-caches 1000M

# Clean temp files
echo "Cleaning temp files..."
adb shell rm -rf /data/local/tmp/* 2>&1

# Show storage info
echo ""
echo "Storage info:"
adb shell df -h | grep "/data"

# List largest apps
echo ""
echo "Largest apps (top 10):"
adb shell dumpsys package | grep -A 1 "Package \[.*\]" | grep -E "Package|codePath" | head -20

echo ""
echo "Done! Try installing the app again."

