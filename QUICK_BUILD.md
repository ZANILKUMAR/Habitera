# Habitera App Bundle - Quick Build Guide

## 📋 Before You Start

You need to:
1. **Create a release keystore** (if not already done)
2. **Configure signing credentials** in `android/key.properties`
3. **Update version** in `pubspec.yaml` if needed

---

## 🔑 Step 1: Create Keystore (One-time)

**Only do this once.** After that, reuse the same keystore for all releases.

```powershell
cd android

# Generate keystore (follow prompts)
keytool -genkey -v -keystore habitera_release.jks `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias habitera_release_key

# You will be prompted for:
# - Keystore password
# - Key password (can be same as keystore)
# - Certificate details (name, organization, location, etc.)
```

---

## 🔐 Step 2: Configure android/key.properties

Edit `android/key.properties` and fill in your details:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=habitera_release_key
storeFile=habitera_release.jks
```

⚠️ **Security**: Never commit this file or keystore to public repositories!

---

## 📦 Step 3: Build App Bundle

Run this in PowerShell from project root:

```powershell
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build app bundle for Play Store
flutter build appbundle --release
```

✅ **Success!** Your app bundle is at:
```
build/app/outputs/bundle/release/app-release.aab
```

---

## 🚀 Step 4: Upload to Google Play Store

1. Go to [Google Play Console](https://play.google.com/console)
2. Select or create your app
3. Go to **Release** → **Create Release**
4. Upload `app-release.aab`
5. Add release notes
6. Submit for review

**Review time**: Usually 1-3 hours

---

## 🔄 For Future Updates

Each time you release an update:

1. Update version in `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # Both numbers must increase
   ```

2. Make your code changes

3. Build new bundle:
   ```bash
   flutter build appbundle --release
   ```

4. Upload new AAB to Play Store

---

## ❓ Troubleshooting

**Build fails with "Keystore not found"?**
- Ensure `habitera_release.jks` is in `android/` directory
- Check `key.properties` path is correct

**"Build fails with signing error"?**
- Verify passwords in `key.properties`
- Test keystore with: `keytool -list -v -keystore android/habitera_release.jks`

**"Command not found: keytool"?**
- `keytool` is part of Java JDK
- Ensure JDK is installed and in PATH
- Or use full path: `"C:\Program Files\...\bin\keytool"`

---

## 📱 Alternative: Build APK

If you need APK instead (for direct installation):

```powershell
flutter build apk --split-per-abi --release
```

Output: `build/app/outputs/apk/release/`

---

## 💡 Tips

- **Test first**: Build APK locally and test on device before releasing
- **Keep backup**: Store keystore backup in secure location
- **Version carefully**: Build number must always increase
- **Read release notes**: Review what you changed before submitting

