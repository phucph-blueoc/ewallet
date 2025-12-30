#!/bin/bash
# Script to fix root_detector namespace, Kotlin version, and compilation issues
# Run this after 'flutter pub get' if the issue persists

ROOT_DETECTOR_BUILD_GRADLE="$HOME/.pub-cache/hosted/pub.dev/root_detector-0.0.6/android/build.gradle"
ROOT_DETECTOR_PLUGIN_KT="$HOME/.pub-cache/hosted/pub.dev/root_detector-0.0.6/android/src/main/kotlin/space/wisnuwiry/root_detector/RootDetectorPlugin.kt"

if [ -f "$ROOT_DETECTOR_BUILD_GRADLE" ]; then
    echo "Fixing root_detector build.gradle..."
    
    # Fix namespace
    if ! grep -q "namespace 'space.wisnuwiry.root_detector'" "$ROOT_DETECTOR_BUILD_GRADLE"; then
        echo "  - Adding namespace..."
        sed -i "/^android {/a\    namespace 'space.wisnuwiry.root_detector'" "$ROOT_DETECTOR_BUILD_GRADLE"
    fi
    
    # Fix Kotlin version
    if grep -q "ext.kotlin_version = '1.3.50'" "$ROOT_DETECTOR_BUILD_GRADLE"; then
        echo "  - Updating Kotlin version..."
        sed -i "s/ext.kotlin_version = '1.3.50'/ext.kotlin_version = '1.9.0'/" "$ROOT_DETECTOR_BUILD_GRADLE"
    fi
    
    # Fix jcenter() to mavenCentral()
    if grep -q "jcenter()" "$ROOT_DETECTOR_BUILD_GRADLE"; then
        echo "  - Replacing jcenter() with mavenCentral()..."
        sed -i 's/jcenter()/mavenCentral()/g' "$ROOT_DETECTOR_BUILD_GRADLE"
    fi
    
    # Fix JVM target compatibility
    if ! grep -q "kotlinOptions" "$ROOT_DETECTOR_BUILD_GRADLE"; then
        echo "  - Adding JVM target compatibility..."
        # Add compileOptions and kotlinOptions before lintOptions
        sed -i '/lintOptions {/i\    compileOptions {\n        sourceCompatibility JavaVersion.VERSION_1_8\n        targetCompatibility JavaVersion.VERSION_1_8\n    }\n    kotlinOptions {\n        jvmTarget = '\''1.8'\''\n    }' "$ROOT_DETECTOR_BUILD_GRADLE"
    fi
    
    # Fix compileSdkVersion to 31 for lStar attribute support
    if grep -q "compileSdkVersion" "$ROOT_DETECTOR_BUILD_GRADLE"; then
        echo "  - Updating compileSdkVersion to 31..."
        sed -i 's/compileSdkVersion [0-9]*/compileSdkVersion 31/g' "$ROOT_DETECTOR_BUILD_GRADLE"
    else
        echo "  - Adding compileSdkVersion 31..."
        sed -i "/^android {/a\    compileSdkVersion 31" "$ROOT_DETECTOR_BUILD_GRADLE"
    fi
else
    echo "root_detector build.gradle not found at $ROOT_DETECTOR_BUILD_GRADLE"
fi

# Fix Kotlin source code
if [ -f "$ROOT_DETECTOR_PLUGIN_KT" ]; then
    echo "Fixing root_detector Kotlin source code..."
    
    # Fix null safety issues in error handling
    if grep -q "result.error(e.message, e.message, e.stackTrace)" "$ROOT_DETECTOR_PLUGIN_KT"; then
        echo "  - Fixing null safety in error handling..."
        sed -i 's/result.error(e.message, e.message, e.stackTrace)/result.error(e.message ?: "Unknown error", e.message ?: "Unknown error", e.stackTrace?.toString())/g' "$ROOT_DETECTOR_PLUGIN_KT"
    fi
else
    echo "root_detector Kotlin source not found at $ROOT_DETECTOR_PLUGIN_KT"
fi

echo "Fixed!"

