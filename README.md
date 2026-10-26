# Marketplace App

A Facebook Marketplace–style app built with Flutter and Firebase (Auth, Firestore).

## Install the Android App (APK)

### Requirements

- An Android phone
- The APK file (`app-release.apk`, or `app-arm64-v8a-release.apk` for 64-bit phones)

### Steps

1. **Get the APK onto your phone.** Download it from the release page, or copy it from your computer using a USB cable (File Transfer mode), Google Drive, or Telegram.
2. **Open the APK.** Tap the file in your Files or Downloads app.
3. **Allow installation from unknown sources.** If Android blocks the install, tap **Settings** on the prompt, then turn on **Allow from this source** for the app you used to open the file (Files, Chrome, Telegram, etc.). Go back afterwards.
4. **Tap Install.** If Google Play Protect shows a warning, tap **More details** → **Install anyway**. This is normal for apps that are not published on the Play Store.
5. **Open the app.** Tap **Open**, or find it in your app drawer.

### Troubleshooting

| Problem | Fix |
| --- | --- |
| "App not installed" | Uninstall any older version of the app first, then try again. |
| "Parse error" | The file may be incomplete. Download or copy it again. |
| Install option is greyed out | Allow installs from unknown sources (step 3). |

## Build the APK Yourself

From the project folder:

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

The APK files are created in:

```
build/app/outputs/flutter-apk/
```

### Install directly over USB

1. Enable **Developer options** and **USB debugging** on your phone.
2. Connect it to your computer.
3. Run:

```bash
flutter install
```
