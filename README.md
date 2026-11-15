# Opensic 🎵

An open-source, ad-free Flutter music player for Android. Purple Material 3 UI, offline local library, saved HTTPS streams, favorites, playlists, queue, seek, shuffle, repeat, and background audio service integration.

> **Status: development source (v0.3.0), not a verified production release.** The project has not been compiled or device-tested by its authoring environment. GitHub Actions builds an APK when CI succeeds. The current online mode is *direct URLs only*; it does **not** offer a licensed Spotify-like music catalog, cloud sync, or automatic online search.

## Quick start

Requirements: Flutter stable, Android SDK, Java/JDK compatible with your Flutter version.

1. Clone/download this repository.
2. From its root, run `flutter create --platforms=android --org org.opensic --project-name opensic .` to generate missing Android/Flutter scaffolding.
3. **Important:** `flutter create` can overwrite generated Android files. Verify that `android/app/src/main/AndroidManifest.xml` matches the committed version and that `android/app/src/main/kotlin/org/opensic/opensic/MainActivity.kt` extends `AudioServiceActivity`. Verify the application ID is `org.opensic.opensic`.
4. Run `flutter pub get`.
5. Connect an Android phone with USB debugging enabled and run `flutter run`.
6. Run `flutter build apk --release` for an APK at `build/app/outputs/flutter-apk/app-release.apk`.

Alternatively, push to GitHub and use **Actions → Android APK → Run workflow**. Download the `opensic-android-apk` workflow artifact when successful.

## GitHub releases

Push a version tag such as `v0.3.0` to run the Android Release workflow. It runs analysis and tests, builds the APK, and publishes it as a GitHub pre-release.

These are development APKs signed with the Android debug key, not production or Play Store releases. A permanent release requires a private signing keystore configured as GitHub Actions secrets; never commit signing keys to this repository. No release should be considered device-tested until it has been installed and exercised on Android hardware.

## Supported

- Local music via Android MediaStore and runtime audio permission
- Local audio album art when MediaStore provides it
- Favorites and playlists saved on device
- HTTPS direct-stream entries (only content you are authorized to access)
- Unified playback queue, seek, next/previous, shuffle/repeat
- Foreground audio playback service and media notifications (requires Android device validation)

## Known limitations / next milestones

- Online stream URLs may fail due to codec, HTTP response, redirects, authorization, or host restrictions.
- No licensed catalog API, Navidrome connector, music downloads, cloud sync, playlist editing/removal of individual songs, or gapless guarantees yet.
- Queue persistence and error recovery require additional work.
- A release distributed to users should have a proper signing key, versioning, privacy policy, and multi-device QA.
- Never commit API keys, credentials, keystores, or copyrighted music to this repository.

## Licensing

MIT. Dependencies have their own licenses; review before redistribution. Contributions welcome; see CONTRIBUTING.md.
