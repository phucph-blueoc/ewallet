#!/bin/bash
# Script to build Flutter app with code obfuscation enabled
# Usage: ./build_release_obfuscated.sh [android|ios|both]

set -e

PLATFORM=${1:-both}
DEBUG_INFO_DIR="./debug-info"

echo "🔒 Building Flutter app with code obfuscation..."

# Create debug info directory if it doesn't exist
mkdir -p "$DEBUG_INFO_DIR"

if [ "$PLATFORM" = "android" ] || [ "$PLATFORM" = "both" ]; then
    echo ""
    echo "📱 Building Android APK with obfuscation..."
    flutter build apk --release \
        --obfuscate \
        --split-debug-info="$DEBUG_INFO_DIR/android" \
        --target-platform android-arm,android-arm64,android-x64
    
    echo ""
    echo "📱 Building Android App Bundle with obfuscation..."
    flutter build appbundle --release \
        --obfuscate \
        --split-debug-info="$DEBUG_INFO_DIR/android" \
        --target-platform android-arm,android-arm64,android-x64
    
    echo "✅ Android build completed!"
    echo "   APK: build/app/outputs/flutter-apk/app-release.apk"
    echo "   AAB: build/app/outputs/bundle/release/app-release.aab"
    echo "   Debug info: $DEBUG_INFO_DIR/android"
fi

if [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "both" ]; then
    echo ""
    echo "🍎 Building iOS with obfuscation..."
    flutter build ios --release \
        --obfuscate \
        --split-debug-info="$DEBUG_INFO_DIR/ios"
    
    echo "✅ iOS build completed!"
    echo "   IPA: build/ios/ipa/"
    echo "   Debug info: $DEBUG_INFO_DIR/ios"
fi

echo ""
echo "🎉 Build completed successfully!"
echo ""
echo "⚠️  IMPORTANT: Keep the debug-info directory safe!"
echo "   You'll need it to symbolicate crash reports."
echo "   Do NOT commit it to version control!"

