# LumiLink (pc_remote)

LumiLink — your PC, from your pocket: brightness, profiles & lock.

Same name + same logo on Windows and Android. Package stays `pc_remote`
(`com.owner.pc_remote`) so existing installs keep updating.

## Getting Started

```powershell
flutter pub get
flutter analyze   # clean
flutter test      # 3/3 pass
flutter run       # install + launch (USB debugging on)
flutter build apk --release   # keep-forever APK
```

Release APK: `build/app/outputs/flutter-apk/app-release.apk`.
Reinstall fresh so Android grants the LAN/WiFi permissions.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
