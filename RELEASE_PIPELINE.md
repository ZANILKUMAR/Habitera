# Habitera Build & Release Process Flow

## 📊 Complete Release Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    HABITERA RELEASE PIPELINE                    │
└─────────────────────────────────────────────────────────────────┘

                        ┌──────────────────┐
                        │  One-Time Setup  │
                        └────────┬─────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
              ┌─────▼──┐  ┌─────▼──┐  ┌─────▼──┐
              │ Create │  │ Configure│  │ Add to │
              │Keystore│  │Credentials
│ .gitignore │
              └─────────┘  └─────────┘  └─────────┘
                    │            │            │
                    └────────────┼────────────┘
                                 │
                                 ▼
                        ┌──────────────────┐
                        │  For Each Build  │
                        └────────┬─────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
              ┌─────▼──┐  ┌─────▼──┐  ┌─────▼──┐
              │ Update │  │ flutter│  │ flutter│
              │Version │  │  clean │  │  pub   │
              │ Number │  │        │  │  get   │
              └─────────┘  └─────────┘  └─────────┘
                    │            │            │
                    └────────────┼────────────┘
                                 │
                                 ▼
                        ┌──────────────────┐
                        │ Build Verification│
                        └────────┬─────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
              ┌─────▼──┐  ┌─────▼──┐  ┌─────▼──┐
              │flutter │  │flutter │  │Check   │
              │analyze │  │test    │  │Errors  │
              └─────────┘  └─────────┘  └─────────┘
                    │            │            │
                    └────────────┼────────────┘
                                 │
                                 ▼
                        ┌──────────────────┐
                        │   Build Release  │
                        └────────┬─────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
              ┌─────▼──────┐  ┌─▼─────────┐
              │ AAB Bundle │  │APK (test) │
              │(Play Store)│  │(optional) │
              └─────────────┘  └───────────┘
                    │
                    ▼
            ┌──────────────────┐
            │ Upload to Play   │
            │ Store Console    │
            └────────┬─────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
   ┌────▼───┐  ┌────▼───┐  ┌────▼───┐
   │ Testing│  │Staging │  │Production
│
   │Release │  │Release │  │ Release │
   └────────┘  └────────┘  └────────┘
        │            │            │
        └────────────┼────────────┘
                     │
                     ▼
            ┌──────────────────┐
            │  Google Review   │
            │  (1-3 hours)     │
            └────────┬─────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
    ┌───▼──┐              ┌──────▼────┐
    │Review│              │  Rejected  │
    │Passed│              │  (Fix &    │
    │      │              │   Retry)   │
    └───┬──┘              └────────────┘
        │
        ▼
    ┌──────────────────┐
    │App Live on Play  │
    │Store!            │
    └──────────────────┘
```

---

## 🔑 Key Files & Their Purposes

```
Habitera/
│
├── pubspec.yaml
│   └─ Version control (e.g., 1.0.0+1)
│      • First number: User version
│      • Number after +: Build number (must increment)
│
├── android/
│   │
│   ├── app/build.gradle.kts
│   │   └─ Build configuration with signing
│   │      • Loads from key.properties
│   │      • Disables minification (for notifications)
│   │      • Sets release signing config
│   │
│   ├── key.properties ⚠️ SENSITIVE
│   │   └─ Credentials (git-ignored)
│   │      • storePassword
│   │      • keyPassword
│   │      • keyAlias
│   │      • storeFile path
│   │
│   ├── habitera_release.jks ⚠️ SENSITIVE
│   │   └─ Keystore file (git-ignored)
│   │      • BACKUP THIS SECURELY
│   │      • Cannot recreate if lost
│   │      • Valid for 10,000 days
│   │
│   ├── AndroidManifest.xml
│   │   └─ App permissions & config
│   │      • Notifications
│   │      • Required permissions
│   │
│   └── .gitignore
│       └─ Protects sensitive files
│          • *.jks files
│          • key.properties
│
├── BUILD_INSTRUCTIONS.md
│   └─ Comprehensive build guide (this file)
│
├── PLAYSTORE_CHECKLIST.md
│   └─ Pre-release checklist
│
├── QUICK_BUILD.md
│   └─ Quick reference
│
└── build/app/outputs/bundle/release/
    └─ app-release.aab (created after build)
       • This is uploaded to Play Store
       • Size: 15-25 MB
```

---

## 📋 Step-by-Step: From Code to App Store

### Phase 1: One-Time Setup (First Release Only)

```
STEP 1: Create Keystore
├─ Run: keytool -genkey ... 
├─ Creates: android/habitera_release.jks
├─ Stores: Certificate and signing key
└─ Duration: 5 minutes

STEP 2: Configure Credentials
├─ Edit: android/key.properties
├─ Enter: Keystore password
├─ Enter: Key password
├─ Enter: Key alias name
└─ Duration: 2 minutes

STEP 3: Verify Setup
├─ Run: flutter doctor -v
├─ Check: All required tools present
├─ Verify: No errors in console
└─ Duration: 2 minutes
```

### Phase 2: For Each Build/Release

```
STEP 4: Update Version
├─ Edit: pubspec.yaml
├─ Change: version: X.Y.Z+N
├─ Note: Both numbers must increase
└─ Duration: 1 minute

STEP 5: Clean & Prepare
├─ Run: flutter clean
├─ Run: flutter pub get
├─ Purpose: Remove old build artifacts
└─ Duration: 1-2 minutes

STEP 6: Verify Code Quality
├─ Run: flutter analyze
├─ Run: flutter test
├─ Fix: Any errors found
└─ Duration: 2-5 minutes

STEP 7: Build App Bundle
├─ Run: flutter build appbundle --release
├─ Reads: key.properties for signing
├─ Creates: build/app/outputs/bundle/release/app-release.aab
├─ Optimizes: Dart code and resources
└─ Duration: 3-5 minutes

STEP 8: Verify Build
├─ Check: File exists and is ~20MB
├─ Inspect: AAB contents (optional)
└─ Duration: 1 minute
```

### Phase 3: Upload to Play Store

```
STEP 9: Go to Play Store Console
├─ URL: https://play.google.com/console
├─ Sign in: With Google account
└─ Duration: 1 minute

STEP 10: Create or Select App
├─ Create: New app (if first release)
├─ Fill: App name, category
├─ Upload: Graphics and screenshots
└─ Duration: 15-30 minutes

STEP 11: Submit Build for Review
├─ Go to: Release section
├─ Create: New release
├─ Upload: app-release.aab
├─ Add: Release notes
├─ Submit: For review
└─ Duration: 10 minutes

STEP 12: Wait for Review
├─ Status: Can be viewed in console
├─ Time: Usually 1-3 hours
├─ Email: Notification when done
└─ Duration: ⏳ 1-3 hours

STEP 13: Monitor & Update
├─ View: User reviews & ratings
├─ Check: Crash reports
├─ Respond: To user feedback
└─ Duration: Ongoing
```

---

## 🔄 Version Number Management

### Versioning Strategy

```
pubspec.yaml: version: MAJOR.MINOR.PATCH+BUILD

Example Timeline:
├─ v1.0.0+1      ← Initial release
├─ v1.0.1+2      ← Bug fix
├─ v1.0.2+3      ← Another bug fix
├─ v1.1.0+4      ← New feature
├─ v2.0.0+5      ← Major redesign
└─ ... forever

Rules:
✓ Both numbers MUST increase with each release
✓ Cannot reuse same version+build number
✓ Build number increments sequentially
✓ User version (before +) shows feature changes
```

---

## 🔒 Security Checklist

### Before First Release
- [ ] Create keystore with strong password
- [ ] Backup keystore to secure location
- [ ] Add *.jks to .gitignore
- [ ] Add key.properties to .gitignore
- [ ] Never commit credentials
- [ ] Document password securely

### Before Each Release
- [ ] Verify keystore file still exists
- [ ] Confirm key.properties has correct paths
- [ ] Check passwords are correct
- [ ] Review code for security issues

### After Release
- [ ] Verify app in Play Store
- [ ] Test on multiple devices
- [ ] Monitor crash reports
- [ ] Keep backup of keystore

---

## ⚠️ Common Issues & Solutions

### "Build Failed: Gradle Error"
```
Fix:
1. flutter clean
2. flutter pub get
3. Check Java version (11+)
4. Run flutter doctor -v
```

### "Keystore not found"
```
Fix:
1. Verify habitera_release.jks in android/
2. Check key.properties path
3. Ensure .gitignore not hiding file
```

### "Wrong password"
```
Fix:
1. Double-check key.properties
2. Verify with: keytool -list -v -keystore android/habitera_release.jks
3. Regenerate if lost (old keystore must be deleted)
```

### "App crashes after release"
```
Fix:
1. Check Play Console crash reports
2. Review minification settings
3. Test build locally first
4. Check Android API compatibility
```

---

## 📊 Build Output Explanation

```
flutter build appbundle --release
                                    └─ Build optimized release version
                        └─ Creates AAB (not APK)
           └─ Flutter CLI command

Output files:
├── build/app/intermediates/
│   └─ Intermediate build files (can delete)
│
├── build/app/outputs/bundle/release/
│   └─ app-release.aab        ← THIS IS YOUR APP!
│       • ~20-25 MB
│       • Contains all code, resources, assets
│       • Google Play optimizes per device
│       • Ready to upload
│
└── build/app/outputs/apk/
    └─ APK files (if built separately)
        • Smaller per-device downloads
        • Generated by Play Store from AAB
```

---

## 🚀 Quick Reference: Commands

```bash
# One-time setup
keytool -genkey -v -keystore android/habitera_release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias habitera_release_key

# Before each build
flutter clean
flutter pub get
flutter analyze
flutter test

# Build for release
flutter build appbundle --release

# Build APK for testing
flutter build apk --split-per-abi --release

# Install APK to device
flutter install

# View keystore info
keytool -list -v -keystore android/habitera_release.jks

# View app version
grep "version:" pubspec.yaml
```

---

## 📞 Getting Help

If you encounter issues:

1. **Build fails**: Check `flutter doctor -v`
2. **Signing issues**: Verify keystore with `keytool`
3. **Review rejected**: Check Play Store console for details
4. **App crashes**: Review crash logs in Play Console
5. **General help**: 
   - [Flutter Docs](https://docs.flutter.dev/deployment/android)
   - [Play Store Help](https://support.google.com/googleplay)
   - [Android Studio Docs](https://developer.android.com/studio/publish/app-signing)

---

## 🎉 You're All Set!

Your Habitera app is ready to go to the Play Store!

**Next action**: Create your keystore (Step 1 in setup guide)

Good luck! 🚀

