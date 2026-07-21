# Queen’s Regalia

Queen’s Regalia is an original, offline Flutter implementation of the one-crown-per-row, column, and region logic puzzle. Crowns may not touch, including diagonally; diagonal alignment at a distance is legal.

The bundled **Queen’s Regalia: Origin Story** arc contains 72 deterministic, uniquely solvable puzzles plus a separate guided tutorial. Each realm presents nine puzzles as a 3×3 route, with combat encounters at the end of every row. They form a linear prestige pixel-art pilgrimage across eight realms: each clean or assisted solve advances the Regalia’s unnamed bearer from Asterfall Vale toward the Empyrean Citadel. Completed puzzles remain replayable, while future route nodes stay visible and locked. Journey scenery, storyboard backgrounds, and principal character art are bundled as optimized production assets, with procedural art retained as an offline-safe fallback.

The complete release also includes the ten-world story portfolio: **The Sun-Sail Covenant**, **Where the Rain Trees Walk**, **The Oathstorm Fleet**, **The Crimson Ledger**, **The Atlas of Borrowed Winds**, **A Treaty Written in Thorns**, **The Inn at the End of Yesterday**, **The Ninth Library**, **Shepherds of the Thunderwild**, and **Steal the Seventh Tide**. Each arc adds eight playable chapters and 72 distinct puzzles, a three-frame prologue, chapter cinematics, a two-frame finale, its own environments, and a unique eight-boss roster while sharing the common progression and combat systems.

Puzzle actions also drive a synchronized combat stage: chapter bosses react to
the knight’s existing moves and fall to increasingly elaborate chapter-ending
specials, while selected in-chapter puzzles feature regular enemies. Completing
any encounter now opens the full-screen final-move, opponent-defeat, and
knight-victory sequence. Defeated foes are collected in the home-screen
Bestiary, organized by arc and chapter, where all six reaction animations can
be replayed without changing story progress. Reaction studies play once inside
the idle loop and return to idle; defeat alone holds on its final frame.

“Just Puzzle!” is a separate endless run of puzzles generated and verified entirely on the device. Players can choose Easy, Medium, Hard, Expert, 12×12 Extreme, or a rotating Mixed run; the next board is prepared while the current one is played. Its boards, marks, elapsed time, assistance, and run statistics resume after relaunch without changing any story frontier.

After the tutorial, the home screen lists every available story arc in a single metadata-driven column and keeps the Academy, “Just Puzzle!”, and master settings at the top level. Selecting an arc opens its own opening scene when needed and then that arc’s map. The GitHub Pages/web edition and every native build currently include the complete Origin arc and all ten portfolio arcs alongside the Academy and “Just Puzzle!”. A missing, corrupt, or future channel-restricted package is isolated without preventing other arcs, the Academy, or puzzle-only mode from loading.

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
flutter run -d chrome
```

The checked-in workspace is the complete app source. Normal web, iOS, Android,
macOS, Windows, and Linux `flutter run` and `flutter build` commands include
every current story; there is no paid flavor and no per-story purchase. Web
runtime content is selected with Flutter's `kIsWeb`. The GitHub Pages workflow
creates an untracked temporary copy and removes any asset roots marked
`# web-excluded` for a future channel-restricted package. The current all-web
source has no such roots, so staging zero exclusions is valid. A release web
build includes Flutter's generated service worker, which caches the app shell
and caches bundled story resources as the player loads them. Metadata and
catalogs are read during startup; unvisited cinematic and combat art remains
an on-demand cache entry rather than an eager offline download.

For local macOS animation review, choose **Queen's Regalia — macOS** in VS
Code's Run and Debug view. It includes the complete story portfolio. In debug
builds, the Bestiary also shows **Unlock All Foes (Debug)**;
that preview lasts only for the current visit and never changes saved progress.

## Puzzle tooling

The app and command-line tooling share the pure-Dart core in `lib/core`.

```sh
dart run tool/generate_puzzles.dart report
dart run tool/generate_puzzles.dart validate
dart run tool/generate_puzzles.dart inspect regalia:puzzle/origin/easy-001
dart run tool/generate_puzzles.dart generate --seed 20260714
```

Generation fails with rejection diagnostics if any requested tier cannot be filled. The shipped catalog contains only public puzzle metadata and region grids. Solutions, seeds, exact-search diagnostics, and human-solving traces are kept in `tool/validation_report.json` for development validation.

The nine portfolio expansion packages are reproducible from their authored
specs in `tool/story_arc_specs/`. The generator writes committed runtime JSON,
fresh namespaced puzzle catalogs, compact chapter art, and boss reaction
atlases. Existing hand-authored storefront key art is preserved; a procedural
fallback is created only when a storefront image is missing. The Python
dependency is development-only:

```sh
python3 -m venv .venv
.venv/bin/pip install -r tool/requirements.txt
.venv/bin/python tool/generate_portfolio_arcs.py
dart run tool/generate_puzzles.dart validate-all
```

## Verification

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --exclude-tags=golden
flutter test --tags=golden
flutter test test/atlas_of_borrowed_winds_bundle_test.dart
flutter test test/portfolio_story_arcs_test.dart
dart run tool/generate_puzzles.dart validate
dart run tool/generate_puzzles.dart validate-all
dart run tool/verify_offline.dart
web_stage="$(mktemp -d)"
dart run tool/stage_web_edition.dart --output "$web_stage"
(cd "$web_stage" && flutter pub get && dart run tool/verify_offline.dart --web-source)
(cd "$web_stage" && flutter build web --release)
(cd "$web_stage" && dart run tool/verify_offline.dart --web-source --web-build build/web)
```

Unsigned web, Android APK/AAB, iOS, macOS, Windows, and Linux release
artifacts are defined in `.github/workflows/ci.yml`. Signing identities, store
credentials, listings, and submissions remain deployment steps.
