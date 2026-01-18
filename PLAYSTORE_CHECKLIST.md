# Habitera - Google Play Store Submission Checklist

## Pre-Build Checklist

### 1. Version Configuration
- [ ] Update version in `pubspec.yaml`
  - Format: `version: 1.0.0+1`
  - First number: User-facing version
  - Number after `+`: Build number (must increment)
  
### 2. Android Configuration
- [ ] Verify `android/app/build.gradle.kts` has correct signing config
- [ ] Confirm `minSdk = 21` (Android 5.0+)
- [ ] Ensure `compileSdk` matches Flutter's requirements

### 3. Keystore Setup
- [ ] Create `android/habitera_release.jks` if not already created
  ```bash
  cd android
  keytool -genkey -v -keystore habitera_release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias habitera_release_key
  ```

### 4. Signing Configuration
- [ ] Fill in `android/key.properties` with your keystore information:
  ```properties
  storePassword=YOUR_PASSWORD
  keyPassword=YOUR_PASSWORD
  keyAlias=habitera_release_key
  storeFile=habitera_release.jks
  ```
- [ ] Verify `android/key.properties` is in `.gitignore`
- [ ] Ensure keystore file (`*.jks`) is in `.gitignore`

---

## Build Checklist

### 1. Clean & Prepare
- [ ] Run: `flutter clean`
- [ ] Run: `flutter pub get`
- [ ] Run: `flutter doctor -v` to verify setup

### 2. Build the App Bundle
- [ ] Run: `flutter build appbundle --release`
- [ ] Verify build completes without errors
- [ ] Confirm output file exists: `build/app/outputs/bundle/release/app-release.aab`

### 3. Verify Build Output
- [ ] AAB file size is reasonable (typically 15-25MB)
- [ ] File is not corrupted: `7z l app-release.aab` (or use archive manager)

---

## App Content Preparation

### 1. App Icons & Graphics
- [ ] **App Icon (512×512 px)**
  - Location: `assets/app_icon.png` or similar
  - Format: PNG with alpha channel
  - No rounded corners in source (Play Store rounds automatically)
  
- [ ] **Feature Graphic (1024×500 px)**
  - Required for app listing
  - Shows at top of store page
  - PNG or JPEG format

- [ ] **Screenshots (minimum 2, maximum 8 per device type)**
  - Phone: 1080×1920 px (9:16 ratio)
  - 7" Tablet: 1200×1920 px
  - 10" Tablet: 1600×2560 px
  - Recommended: Create for at least 2-3 devices

### 2. App Store Listing Text
- [ ] **App Name** (max 50 characters)
  - Current: "Habitera"
  - Avoid keywords, keep simple

- [ ] **Short Description** (max 80 characters)
  - Example: "Build habits. Shape your life."
  - Clear and compelling

- [ ] **Full Description** (max 4000 characters)
  - Explain features
  - Mention privacy/offline-first nature
  - Include key benefits
  - Example structure:
    ```
    Habitera is your personal habit tracking companion.
    
    FEATURES:
    • Create and track daily habits
    • Monitor streaks and progress
    • View analytics and trends
    • Customizable reminders
    • No login required - all data stays private
    
    KEY BENEFITS:
    • Offline-first design - no internet needed
    • Full privacy control - your data is yours
    • Beautiful interface with light/dark themes
    • Simple, intuitive design
    • Built with Flutter for smooth performance
    ```

- [ ] **Release Notes** (for this specific version)
  - What's new in this release
  - Bug fixes
  - Improvements
  - Example:
    ```
    Version 1.0.0 - Initial Release
    
    ✨ Features:
    - Create and track daily habits
    - Daily check-in with visual progress ring
    - Streak tracking (current & longest)
    - Activity heatmap calendar
    - Export/import data as JSON
    - Dark & light themes
    
    🔒 Privacy:
    - No login required
    - All data stored locally
    - Full user privacy
    
    Thanks for using Habitera!
    ```

---

## Google Play Store Setup

### 1. App Store Configuration
- [ ] **Package Name**: `com.example.habitera`
  - Change to your own unique package name before first release
  - Format: `com.yourcompany.habitera`
  - Cannot be changed after first release
  
- [ ] **App Type**: "Applications"

- [ ] **Category**: "Lifestyle" or "Health & Fitness"

- [ ] **Content Rating**: Complete questionnaire
  - Most likely: "Mature 17+"
  - Submit to get rating certificate

### 2. Privacy & Security
- [ ] **Privacy Policy URL**: 
  - Required before public release
  - Host on your website or use privacy policy generator
  - Include:
    - No personal data collection
    - Local storage only
    - No third-party services
    - No advertising

- [ ] **Data Safety Form**:
  - [ ] No personal data collected
  - [ ] No advertising
  - [ ] Security practices compliant
  - [ ] Declare dependencies (notifications, etc.)

### 3. Target Audience
- [ ] **Target Age**: "Mature 17+"
- [ ] **Intended Users**: Self-improvement, health & wellness enthusiasts
- [ ] **Childcare Items**: No

### 4. Pricing & Distribution
- [ ] **Pricing Model**: Free
- [ ] **Distribution Countries**: Select desired regions
  - Typically: All available countries
- [ ] **Device Categories**: 
  - [ ] Phones and Tablets (required)
  - [ ] Chromebooks (optional, auto-supports)

---

## Release Process

### 1. Create Release in Console
- [ ] Go to [Google Play Console](https://play.google.com/console)
- [ ] Select your app or create new app
- [ ] Navigate to **Release** section
- [ ] Click **Create release** (Start with Testing if unsure)

### 2. Upload App Bundle
- [ ] Drag and drop or browse for `app-release.aab`
- [ ] System validates automatically
- [ ] Wait for upload completion

### 3. Configure Release
- [ ] Add release notes for this version
- [ ] Verify version code is incremented
- [ ] Check content rating is complete
- [ ] Review privacy policy is set

### 4. Submit for Review
- [ ] Review all content one final time
- [ ] Click **Review release**
- [ ] Confirm all settings
- [ ] Click **Submit release**

---

## After Submission

### 1. Review Process
- [ ] **Typical Timeline**: 1-3 hours (can take up to 24 hours)
- [ ] Google reviews app for policy compliance
- [ ] Check email for approval or rejection notifications

### 2. If Approved
- [ ] App appears in Play Store search (may take 1-2 hours)
- [ ] Share your Play Store link
- [ ] Monitor user reviews and ratings
- [ ] Respond to reviews

### 3. If Rejected
- [ ] Read rejection details carefully
- [ ] Fix the issue
- [ ] Increment build number in `pubspec.yaml`
- [ ] Rebuild app bundle
- [ ] Create new release with fixed version
- [ ] Submit again

### 4. Ongoing Maintenance
- [ ] Monitor crash reports in Play Console
- [ ] Check performance metrics (ANRs, crashes)
- [ ] Respond to user reviews
- [ ] Plan updates for new features or fixes

---

## Update Releases

### For Each Update:

1. **Prepare Changes**:
   - Make code changes
   - Test thoroughly
   - Update `pubspec.yaml` version (increment both numbers)

2. **Build New Bundle**:
   ```bash
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```

3. **Create Release in Console**:
   - New release (not update old one)
   - Upload new AAB
   - Add release notes
   - Submit

---

## Troubleshooting

### Build Issues

**Issue**: "Build fails with signing error"
- [ ] Verify `key.properties` passwords are correct
- [ ] Check keystore file exists: `android/habitera_release.jks`
- [ ] Regenerate keystore if needed

**Issue**: "Key password doesn't match"
- [ ] Verify in `key.properties`: `keyPassword` field
- [ ] Ensure it matches keystore creation password

**Issue**: "Gradle build failed"
- [ ] Run: `flutter clean`
- [ ] Run: `flutter pub get`
- [ ] Run: `flutter doctor -v`
- [ ] Check Java version: `java -version` (should be 11+)

### Play Store Issues

**Issue**: "Content policy violation"
- [ ] Review policy:
  - No spam, malware, or deceptive content
  - No sexual or vulgar content
  - No hate speech
  - No violence
  - No privacy violations

**Issue**: "Missing required content"
- [ ] Check all fields completed:
  - Minimum 2 screenshots
  - Privacy policy URL
  - Content rating
  - Supported languages

**Issue**: "App crashes on test"
- [ ] Check `flutter run` works on device
- [ ] Test on Android 5.0+ devices
- [ ] Review crash logs in Play Console

---

## Important Security Notes

⚠️ **NEVER**:
- [ ] Commit keystore file to GitHub/public repositories
- [ ] Commit `key.properties` with real passwords
- [ ] Share keystore with team publicly
- [ ] Lose keystore (you can't create a new one for same package)

✓ **DO**:
- [ ] Keep backup of keystore in secure location
- [ ] Use environment variables in CI/CD
- [ ] Share keystore privately with trusted team members
- [ ] Document the keystore password securely

---

## Useful Resources

- [Flutter Deployment Documentation](https://docs.flutter.dev/deployment/android)
- [Google Play Store Console](https://play.google.com/console)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Google Play Policies](https://play.google.com/about/play-policies/)
- [App Content Rating System](https://support.google.com/googleplay/answer/6209544)

---

## Sign-Off

- [ ] **Builder**: _________________ **Date**: _________
- [ ] **Reviewer**: ________________ **Date**: _________
- [ ] **App Released**: _______________ **URL**: _______________

