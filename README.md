# Queen's Regalia

Queen's Regalia is an original, offline Flutter implementation of the one-crown-per-row, column, and region logic puzzle. Crowns may not touch, including diagonally; diagonal alignment at a distance is legal.

The app contains 120 deterministic, uniquely solvable puzzles plus a separate guided tutorial. It has no backend, accounts, analytics, ads, or runtime network services. Progress and preferences stay in platform-local storage.

## Run the app

```sh
flutter pub get
flutter run
```

Flutter targets web, iOS, Android, macOS, Windows, and Linux from this repository. A release web build includes Flutter's generated service worker, which caches the app shell and bundled catalog for use after the first load.

## Puzzle tooling

The app and command-line tooling share the pure-Dart core in `lib/core`.

```sh
dart run tool/generate_puzzles.dart report
dart run tool/generate_puzzles.dart validate
dart run tool/generate_puzzles.dart inspect regalia-easy-001
dart run tool/generate_puzzles.dart generate --seed 20260714
```

Generation fails with rejection diagnostics if any requested tier cannot be filled. The shipped catalog contains only public puzzle metadata and region grids. Solutions, seeds, exact-search diagnostics, and human-solving traces are kept in `tool/validation_report.json` for development validation.

## Verification

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/generate_puzzles.dart validate
dart run tool/verify_offline.dart
flutter build web --release
dart run tool/verify_offline.dart --web-build build/web
```

Unsigned web, Android APK/AAB, iOS, macOS, Windows, and Linux release
artifacts are defined in `.github/workflows/ci.yml`. Signing identities, store
credentials, listings, and submissions remain deployment steps.
