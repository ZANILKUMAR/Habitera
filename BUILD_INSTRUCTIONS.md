# Habitera - Google Play Store App Bundle Build Guide

## Prerequisites

- Flutter SDK installed and in PATH
- Android Studio or command-line Android tools
- Java Development Kit (JDK) 11+
- Git installed

---

## Step 1: Create a Release Keystore

The keystore is required to sign your app for release. Run this command in PowerShell or Command Prompt:

```powershell
# Navigate to android directory
cd android

# Generate a keystore (follow prompts to enter password and details)
# Replace the paths/names as needed
keytool -genkey -v -keystore habitera_release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias habitera_release_key

# Example with parameters (replace with your own values):
# keytool -genkey -v -keystore habitera_release.jks `
#   -keyalg RSA -keysize 2048 -validity 10000 `
#   -alias habitera_release_key `
#   -dname "CN=Your Name,O=Your Organization,L=City,S=State,C=Country"
```

**Important:** Store this keystore file securely and remember the passwords.

---

## Step 2: Configure Signing

### Option A: Using key.properties (Recommended for CI/CD)

1. The `key.properties` file is already created at `android/key.properties`

2. Edit it with your keystore details:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=habitera_release_key
storeFile=habitera_release.jks
```

3. Update the `build.gradle.kts` file to load signing config from properties:

See the updated build.gradle.kts in this directory.

### Option B: Manual Signing Config

Add to `android/app/build.gradle.kts`:
```kotlin
signingConfigs {
    release {
        keyAlias = "habitera_release_key"
        keyPassword = "YOUR_KEY_PASSWORD"
        storeFile = file("../habitera_release.jks")
        storePassword = "YOUR_STORE_PASSWORD"
    }
}
```

---

## Step 3: Update Build Configuration

Ensure your `pubspec.yaml` has the correct version:

```yaml
version: 1.0.0+1
```

- First number: User-visible version
- Number after `+`: Build number (integer, must increment for each release)

For subsequent releases:
- Increment user version: `1.0.1+2`
- Only increment build number for play store updates of same version

---

## Step 4: Build the App Bundle

### Clean previous builds:
```bash
flutter clean
flutter pub get
```

### Build App Bundle (AAB) for Play Store:
```bash
flutter build appbundle --release
```

**Output location:**
```
build/app/outputs/bundle/release/app-release.aab
```

---

## Step 5: Alternative - Build APK (if needed)

For testing or alternative distribution:
```bash
flutter build apk --split-per-abi --release
```

**Output locations:**
```
build/app/outputs/apk/release/
  - app-armeabi-v7a-release.apk
  - app-arm64-v8a-release.apk
  - app-x86_64-release.apk
```

---

## Step 6: Prepare for Google Play Store Upload

### Pre-upload Checklist:

- [ ] App bundle (AAB) successfully built
- [ ] Version code incremented (pubspec.yaml)
- [ ] App icons and screenshots prepared
- [ ] Privacy policy URL prepared
- [ ] App description and marketing text ready
- [ ] Content rating questionnaire completed
- [ ] Target audience identified
- [ ] Release notes written

### Files You'll Need:

1. **app-release.aab** - The app bundle
2. **Screenshots** - Min 2, max 8 per device type
   - Phone (5" & 6.7")
   - 7" tablet
   - 10" tablet
3. **Feature graphic** - 1024x500 px
4. **App icon** - 512x512 px (high quality)
5. **App name** - Max 50 characters
6. **Short description** - Max 80 characters
7. **Full description** - Max 4000 characters
8. **Release notes** - For this version

### Console Publishing Steps:

1. Go to [Google Play Console](https://play.google.com/console)
2. Create new app or select existing
3. Go to **Release** → **Production** or **Testing**
4. Click **Create release**
5. Upload the AAB file
6. Add release notes
7. Review content rating
8. Set pricing and distribution
9. Submit for review

---

## Troubleshooting

### Issue: "Gradle build failed"
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

### Issue: Keystore not found
Ensure `habitera_release.jks` is in the `android/` directory.

### Issue: "Signing error"
Verify passwords in `key.properties` match keystore creation.

### Issue: App crashes on device
Check Android SDK version compatibility:
- `minSdk = 21` (Android 5.0+)
- `targetSdk` should match Flutter's recommended version

### Issue: App bundle too large
Check for unused dependencies:
```bash
flutter pub deps --style=list
```

---

## Security Best Practices

⚠️ **IMPORTANT:**
- Never commit `habitera_release.jks` to public repositories
- Never commit `key.properties` with real passwords to public repos
- Add to `.gitignore`:
  ```
  android/habitera_release.jks
  android/key.properties
  ```
- Store keystore backup in secure location
- Use environment variables for CI/CD passwords

---

## Subsequent Releases

For each update:

1. Update version in `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # Increment both numbers
   ```

2. Build new bundle:
   ```bash
   flutter build appbundle --release
   ```

3. Upload to Play Console:
   - Go to Release → Production (or Testing first)
   - Create new release
   - Upload AAB
   - Update release notes
   - Submit for review

---

## Useful Commands

```bash
# View keystore details
keytool -list -v -keystore android/habitera_release.jks

# Build and show size
flutter build appbundle --release --split-debug-info=build/debug_info

# Build with verbose output
flutter build appbundle --release -v

# Check Flutter doctor
flutter doctor -v
```

---

## Support Resources

- [Flutter Build Documentation](https://docs.flutter.dev/deployment/android)
- [Google Play Store Console](https://play.google.com/console)
- [Android Build Configuration](https://developer.android.com/studio/build)
- [App Signing & Versioning](https://developer.android.com/studio/publish/app-signing)

---

## Notes

- App bundle is preferred over APK for Play Store (smaller download size for users)
- Google Play dynamically generates optimized APKs from the bundle
- Bundle size is typically 15-25MB for Flutter apps
- First submission requires content rating and privacy policy
- Review process typically takes 1-3 hours but can take up to 24 hours

