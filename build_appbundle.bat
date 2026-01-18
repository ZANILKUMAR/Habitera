@echo off
REM Habitera - Build App Bundle Script for Google Play Store

setlocal enabledelayedexpansion

echo ========================================
echo Habitera App Bundle Build Script
echo ========================================
echo.

REM Check if Flutter is installed
flutter --version >nul 2>&1
if !errorlevel! neq 0 (
    echo Error: Flutter is not installed or not in PATH
    echo Please install Flutter and add it to your PATH
    pause
    exit /b 1
)

echo Step 1: Cleaning previous builds...
call flutter clean
if !errorlevel! neq 0 (
    echo Error: Flutter clean failed
    pause
    exit /b 1
)

echo.
echo Step 2: Getting dependencies...
call flutter pub get
if !errorlevel! neq 0 (
    echo Error: Flutter pub get failed
    pause
    exit /b 1
)

echo.
echo Step 3: Building app bundle for Play Store...
call flutter build appbundle --release
if !errorlevel! neq 0 (
    echo Error: Build failed
    echo Make sure key.properties is properly configured
    pause
    exit /b 1
)

echo.
echo ========================================
echo Build Successful!
echo ========================================
echo.
echo App Bundle Location:
echo build\app\outputs\bundle\release\app-release.aab
echo.
echo Next Steps:
echo 1. Go to Google Play Console
echo 2. Create a new release in your app
echo 3. Upload the app-release.aab file
echo 4. Add release notes
echo 5. Submit for review
echo.
pause
