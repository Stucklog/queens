# Content authoring and releases

Queen’s Regalia treats every story arc as an independently loadable content
package. The web/GitHub Pages edition contains exactly the origin arc and
“Just Puzzle!”. Paid-platform editions may package more arcs and grant them
through the entitlement boundary; no arc is unlocked merely because its files
are present.

## Identity contract

Every durable ID uses `namespace:kind/path`. Lowercase letters, numbers, dots,
and hyphens are allowed. Arc-owned IDs put the arc name first in the path:

```text
regalia:arc/origin
regalia:map/origin/pilgrimage
regalia:chapter/origin/clovermead
regalia:puzzle/origin/easy-001
regalia:scene/origin/opening
regalia:unlock/origin/full-map
regalia:save/origin/boards
```

Never reuse an ID, even after content is removed. A puzzle ID may remain stable
only while its region grid remains the same. The catalog fingerprint protects
saved marks from being applied to changed boards.

Use `SaveIds.forArc(arcId, slot)` for new arc-local persistence rather than
inventing preference keys. Unlock state should store the unlock IDs declared by
the arc, not chapter positions or display labels.

## Author an arc

1. Choose a unique arc name and entitlement ID, for example
   `regalia:arc/moon-court` and `regalia:entitlement/paid/moon-court`.
2. Create `assets/content/arcs/<arc>/arc.json` with schema version, content
   version, namespaced map/unlock IDs, chapter ranges and presentation data,
   all scene copy, explicit chapter/scene `artAsset` paths, and the puzzle
   catalog asset path. Use the origin arc as the canonical schema example.
3. Create a catalog whose puzzle IDs are `regalia:puzzle/<arc>/...`. Orders must
   be contiguous from 1 and exactly cover the chapter ranges. Puzzle hashes,
   schema version, scoring model, and uniqueness rules remain mandatory.
4. Add arc-specific art/assets and declare their directories in `pubspec.yaml`.
   Content must be fully bundled and offline-safe; runtime downloads are not a
   supported packaging strategy. The home screen uses the first chapter’s
   `artAsset` as the arc tile illustration, overlays the shared main-character
   sprite, and takes the prominent tile label from the arc `title`; author
   those fields as storefront-quality presentation content.
5. Add a descriptor to `assets/content/manifest.json`. `channels` controls which
   edition may consider the package. `entitlementId` controls whether an
   eligible installation may load it.
6. Add loader, progression, missing-package, invalid-package, and save-restore
   tests for the new arc. Do not make origin or Just Puzzle tests depend on it.

The loader validates namespace ownership, unique IDs, contiguous chapters and
puzzles, required opening/finale scenes, catalog integrity, and package/manifest
arc agreement. An optional package that is absent or invalid receives an
availability status; other packages continue to load.

## Entitlements and availability

`ContentEntitlementPolicy` is the storefront-neutral boundary. Web policy admits
only the origin arc, requires its descriptor to include the `web` channel, and
grants the base origin and Just Puzzle entitlements. Paid-platform policy also
grants the base content, then accepts explicit purchased entitlement IDs
supplied by the native store/receipt layer.

UI code should read `ContentRegistry.availabilityFor(arcId)` and distinguish:

- `available`: entitled, eligible for this edition, packaged, and valid;
- `notEntitled`: packaged for the edition but not owned;
- `notInEdition`: deliberately excluded from the current release channel;
- `missingPackage` or `invalidPackage`: packaging/content error isolated to the
  arc;
- `notPackaged`: the manifest has no descriptor for that ID.

Do not infer ownership from asset presence, and do not turn an optional-arc
failure into an application startup failure.

The home screen renders only `availableArcs`, in manifest order, as one vertical
column. It must not show unentitled, excluded, missing, or invalid packages as
playable tiles. “Just Puzzle!” remains independently visible whenever its own
feature entitlement is available, including when no story package can load.

## Settings ownership

Master settings is opened from the home screen and owns preferences that apply
across the app and the full-game reset. The full reset erases every arc,
tutorial and Just Puzzle data, and all preferences, so its UI must retain two
separate warning confirmations.

Map unlock and progress reset actions belong in an arc’s own settings screen.
The gear on a story map opens that selected arc’s settings, not master settings.
Always pass the target arc ID to the controller. An arc reset removes only IDs
owned by that namespace and must preserve master preferences, tutorial state,
Just Puzzle runs, entitlements, and progress in every other arc.

## Package and release

For every release:

1. Bump an arc’s `contentVersion` when any metadata or referenced catalog
   changes. Keep existing IDs stable unless the represented object changed.
2. Confirm `pubspec.yaml` includes the manifest, each arc metadata directory,
   every referenced catalog, and all art/audio assets.
3. For web, keep only origin descriptors eligible for `web`; never add a paid
   future arc to that channel. Build and inspect the generated service worker to
   confirm the origin manifest/metadata/catalog and tutorial are cached.
4. For paid platforms, package the desired optional descriptors/assets and wire
   verified store purchases to `grantedEntitlementIds`. Test fresh install,
   purchase restore, entitlement loss, and reinstall without the optional files.
5. Run:

   ```sh
   dart format --output=none --set-exit-if-changed lib test tool
   flutter analyze
   flutter test
   dart run tool/generate_puzzles.dart validate
   dart run tool/verify_offline.dart
   flutter build web --release
   dart run tool/verify_offline.dart --web-build build/web
   ```

6. Smoke-test origin from a fresh save and a migrated legacy save. Separately
   start/resume Just Puzzle with the origin package deliberately unavailable.
   Finally, test each optional arc as entitled, unentitled, absent, and corrupt.

The legacy migration writes all current values before deleting old keys. It
maps old puzzle, board, scene, challenge, unlock, and save identifiers into the
canonical namespaces; valid board content and completion history are retained.
