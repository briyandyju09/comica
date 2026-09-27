# Comica

## Project Stack
Flutter (Dart), Riverpod, Hive, pdfx, Material 3

## Project Description
A beautiful Material 3 comic reader for Android. Point it at a folder and it scans for PDF, CBZ, and CBR comics, generates covers, groups issues into series, and remembers where you left off.

## Project Features
- Folder scanning for PDF, CBZ, and CBR comics
- Auto-generated cover thumbnails
- Series grouping for multi-issue comics
- Resume-last-page tracking
- Favorites and bookmarks
- Material You dynamic theming
- Dark-first reading UI

## How to Build
```bash
flutter pub get
flutter build apk --release
```
Requires the Flutter SDK and Android SDK installed. Output APK: `build/app/outputs/flutter-apk/app-release.apk`
