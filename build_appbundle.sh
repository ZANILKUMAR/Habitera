#!/bin/bash
# Habitera - Build App Bundle Script for Google Play Store

set -e  # Exit on error

echo "========================================"
echo "Habitera App Bundle Build Script"
echo "========================================"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter is not installed or not in PATH"
    echo "Please install Flutter and add it to your PATH"
    exit 1
fi

echo "Step 1: Cleaning previous builds..."
flutter clean

echo ""
echo "Step 2: Getting dependencies..."
flutter pub get

echo ""
echo "Step 3: Building app bundle for Play Store..."
flutter build appbundle --release

echo ""
echo "========================================"
echo "Build Successful!"
echo "========================================"
echo ""
echo "App Bundle Location:"
echo "build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "Next Steps:"
echo "1. Go to Google Play Console"
echo "2. Create a new release in your app"
echo "3. Upload the app-release.aab file"
echo "4. Add release notes"
echo "5. Submit for review"
echo ""
