# Queen’s Regalia

Queen’s Regalia is an original, offline Flutter implementation of the one-crown-per-row, column, and region logic puzzle. Crowns may not touch, including diagonally; diagonal alignment at a distance is legal.

The bundled **Queen’s Regalia: Origin Story** arc contains 72 deterministic, uniquely solvable puzzles plus a separate guided tutorial. Each realm presents nine puzzles as a 3×3 route, with combat encounters at the end of every row. They form a linear prestige pixel-art pilgrimage across eight realms: each clean or assisted solve advances the Regalia’s unnamed bearer from Asterfall Vale toward the Empyrean Citadel. Completed puzzles remain replayable, while future route nodes stay visible and locked. Journey scenery, storyboard backgrounds, and principal character art are bundled as optimized production assets, with procedural art retained as an offline-safe fallback.

Puzzle actions also drive a synchronized combat stage: chapter bosses react to
the knight’s existing moves and fall to increasingly elaborate chapter-ending
specials, while selected in-chapter puzzles feature regular enemies. Completing
any encounter now opens the full-screen final-move, opponent-defeat, and
knight-victory sequence. Defeated foes are collected in the home-screen
Bestiary, organized by arc and chapter, where all six reaction animations can
be replayed without changing story progress. Reaction studies play once inside
the idle loop and return to idle; defeat alone holds on its final frame.

“Just Puzzle!” is a separate endless run of puzzles generated and verified entirely on the device. Players can choose Easy, Medium, Hard, Expert, 12×12 Extreme, or a rotating Mixed run; the next board is prepared while the current one is played. Its boards, marks, elapsed time, assistance, and run statistics resume after relaunch without changing any story frontier.

After the tutorial, the home screen lists every available story arc in a single metadata-driven column and keeps the Academy, “Just Puzzle!”, and master settings at the top level. Selecting an arc opens its own opening scene when needed and then that arc’s map. The GitHub Pages/web edition includes the complete origin arc, the deduction Academy, and “Just Puzzle!”. Paid-platform builds use the same package manifest with a separate entitlement policy for future optional arcs. Missing, corrupt, unentitled, or edition-excluded optional packages do not prevent the origin arc, Academy, or puzzle-only mode from loading.

It has no backend, accounts, analytics, ads, or automatic runtime network
services. Story progress, puzzle-only runs, story scenes, Bestiary discoveries,
support-prompt history, and preferences stay in platform-local storage. A
clearly labeled support action can open the project’s external Buy Me a Coffee
page only after a player chooses it. Legacy origin and puzzle-only saves are
migrated to namespaced IDs without resetting valid progress.

See [Content authoring and releases](docs/CONTENT_AUTHORING.md) for the ID contract, package format, entitlement integration, validation, and release checklist.

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
dart run tool/generate_puzzles.dart inspect regalia:puzzle/origin/easy-001
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
