# Opensic 🎵

An open-source, ad-free Flutter music player for Android. Purple Material 3 UI, offline local library, Audius music discovery, saved HTTPS streams, favorites, playlists, queue, seek, shuffle, repeat, and background audio service integration.

> **Status: development source (v0.3.2), not a verified production release.** Audius discovery uses its public read API; an optional API key raises the rate limit.

## Quick start

Requirements: Flutter stable, Android SDK, Java/JDK compatible with your Flutter version.

1. Clone/download this repository.
2. From its root, run `flutter create --platforms=android --org org.opensic --project-name opensic .` to generate missing Android/Flutter scaffolding.
3. **Important:** `flutter create` can overwrite generated Android files. Verify that `android/app/src/main/AndroidManifest.xml` matches the committed version and that `android/app/src/main/kotlin/org/opensic/opensic/MainActivity.kt` extends `AudioServiceActivity`. Verify the application ID is `org.opensic.opensic`.
4. Run `flutter pub get`.
5. Connect an Android phone with USB debugging enabled and run `flutter run`.
6. Run `flutter build apk --release` for an APK at `build/app/outputs/flutter-apk/app-release.apk`.

Alternatively, push to GitHub and use **Actions → Android APK → Run workflow**. Download the `opensic-android-apk` workflow artifact when successful.

## Online music discovery

The **Discover** tab shows trending Audius tracks and supports track search. Audius's public read endpoints work without credentials at a lower rate limit; adding an API key uses the documented free API plan (10 requests per second, 500,000 requests per month):

1. Create a developer app at [Audius API Plans](https://api.audius.co/plans) or [Audius Settings](https://audius.co/settings).
2. Run with `flutter run --dart-define=AUDIUS_API_KEY=your_api_key` (optional; use your own key).
3. For an APK, pass the same define to `flutter build apk --release --dart-define=AUDIUS_API_KEY=your_api_key`.
4. For GitHub Actions APK builds, add a repository Actions secret named `AUDIUS_API_KEY`.

The API key is sent in the `x-api-key` request header; never use the API secret in the app. The API's free tier does not mean every track is public domain, ad-free, or licensed for reuse. Track availability and rights are determined by uploaders and applicable platform terms. The app does not download tracks.

## GitHub releases

Push a version tag matching `pubspec.yaml`, such as `v0.3.2`, to run the Android Release workflow. It runs analysis and tests, builds the APK, and publishes it as a GitHub pre-release.

These are development APKs signed with the Android debug key, not production or Play Store releases. A permanent release requires a private signing keystore configured as GitHub Actions secrets; never commit signing keys to this repository. No release should be considered device-tested until it has been installed and exercised on Android hardware.

## Supported

- Local music via Android MediaStore and runtime audio permission
- Local audio album art when MediaStore provides it
- Favorites and playlists saved on device
- Audius trending tracks and search (optional API key)
- HTTPS direct-stream entries (only content you are authorized to access)
- Unified playback queue, seek, next/previous, shuffle/repeat
- Foreground audio playback service and media notifications (requires Android device validation)

## Known limitations / next milestones

- Online stream URLs may fail due to codec, HTTP response, redirects, authorization, or host restrictions.
- No Navidrome connector, music downloads, cloud sync, playlist editing/removal of individual songs, or gapless guarantees yet.
- Queue persistence and error recovery require additional work.
- A release distributed to users should have a proper signing key, versioning, privacy policy, and multi-device QA.
- Never commit API keys, credentials, keystores, or copyrighted music to this repository.

## Licensing

MIT. Dependencies have their own licenses; review before redistribution. Contributions welcome; see CONTRIBUTING.md.
