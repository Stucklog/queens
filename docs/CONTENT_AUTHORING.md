# Content authoring and releases

Queen’s Regalia treats every story arc as an independently loadable content
package. The web/GitHub Pages edition contains the origin arc, the system
Academy, and “Just Puzzle!”. Paid-platform editions may package more arcs and grant them
through the entitlement boundary; no arc is unlocked merely because its files
are present.

## Identity contract

Every durable ID uses `namespace:kind/path`. Lowercase letters, numbers, dots,
and hyphens are allowed. Arc-owned IDs put the arc name first in the path:

```text
regalia:arc/origin
regalia:map/origin/pilgrimage
regalia:chapter/origin/clovermead
regalia:boss/origin/starfall-stag
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
   one named boss per chapter,
   all paged scene copy, explicit chapter/scene `artAsset` paths, and the puzzle
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
arc agreement. Every chapter boss must reference the puzzle at its chapter’s
`endOrder`; its size and target difficulty must match that puzzle. A non-final
boss must target the next chapter and match that chapter’s difficulty. The last
boss targets the arc’s finale unlock. An optional package that is absent or
invalid receives an
availability status; other packages continue to load.

Each scene owns one or more `pages`. A page requires a title, an ordered list
of non-empty narrative `paragraphs`, an image `semanticLabel`, and the button
label that advances from that page. Chapter introductions normally use one
page with at least two paragraphs. Openings and finales may use multiple pages
for paced prologues and epilogues; only completing the last page records the
scene as seen. Map replay entries must set replay mode so revisiting a scene
does not write story or progression state. The scene-level `artAsset` is shared
by its pages, and opening/finale cinematics retain the principal character
sprites while chapter-start cinematics show environment art alone.

Visible narrative copy should be scene-led rather than read like a quest log:
give each page a concrete sensory image, an immediate choice or threat, and a
distinct emotional turn. Avoid repeating a place/problem/jewel/boss summary
from chapter to chapter. Keep the separate `semanticLabel` literal and concise
so the more lyrical visible prose never makes the artwork description less
useful to assistive technology.

## Origin chapter bosses

Boss sizes preview the next realm’s board size and difficulty. The last map
encounter deliberately expands beyond the regular 10×10 Expert boards.

| Chapter | Boss | Puzzle order | Size | Target difficulty | Unlocks |
| --- | --- | ---: | ---: | --- | --- |
| Asterfall Vale | Starfall Stag | 9 | 7×7 | Easy | Myrrhveil Wilds |
| Myrrhveil Wilds | Elderroot Wyrm | 18 | 7×7 | Medium | Skyglass Reach |
| Skyglass Reach | Tempest Roc | 27 | 8×8 | Medium | Nacre Basilica |
| Nacre Basilica | Abyssal Bellkeeper | 36 | 8×8 | Hard | Pyreheart Caldera |
| Pyreheart Caldera | Cindermaw Behemoth | 45 | 9×9 | Hard | Brasswake Arsenal |
| Brasswake Arsenal | Gilded War Colossus | 54 | 9×9 | Expert | Pale Moon Necropolis |
| Pale Moon Necropolis | The Sevenfold Wraith | 63 | 10×10 | Expert | Empyrean Citadel |
| Empyrean Citadel | The Hollow Star | 72 | 12×12 | Expert | Finale |

Run `dart run tool/generate_puzzles.dart generate-bosses` to regenerate only
these eight slots, or `generate` for the complete story-ordered catalog. Both
paths include the 12×12 finale in exact-solver, region-quality, uniqueness, and
human-difficulty validation.

## Combat presentation and art status

Combat encounters are chapter metadata, not progression nodes. Every `boss`
declares a `spriteFamily`, a `spriteAsset`, and a `spectacleLevel`; levels must
increase exactly from 1 through the chapter count, leaving the final boss with
the strongest finish. Each `encounters` entry declares a namespaced `enemy` ID,
display name, an existing non-boss `puzzleId`, a `spriteFamily`, and a
`spriteAsset`. An encounter is mandatory presentation on its selected puzzle:
it cannot be dismissed from the header, grants no separate durable reward, and
does not add a new frontier or unlock requirement.

The origin arc has nine puzzles per chapter, displayed as a 3×3 route. Its two
regular enemies occupy local positions 3 and 6, and its boss occupies position
9, so every puzzle whose global order is a multiple of three is a combat
encounter and every map row ends with one.

Combat `spriteAsset` files are transparent PNG atlases with four columns and
six rows. Rows, in order, are idle, stagger, strike, press, exposed, and defeat.
The four columns are successive animation frames. Opponents face left toward
the knight in every directional pose, and every cell retains at least eight
transparent pixels on every edge so animation frames cannot bleed into
adjacent cells. That gutter must surround the complete authored silhouette; it
must not be manufactured by shrinking a frame whose feet, limbs, wings, weapon,
or effects were already cropped. Attack and follow-through energy travels left
toward the knight (with trailing motion allowed on the right), anatomy and gear
remain stable through all four frames, and detached pixels are reserved for an
intentional, readable impact or defeat effect rather than source-sheet debris.
Review the final 192 px cells as well as their 74 px in-game render before
accepting an atlas. Every origin boss and in-chapter enemy has its own
production atlas under `assets/art/combat/opponents/`.

The knight's eight production finisher tracks live in
`assets/art/combat/knight_finishers.png`: six columns and eight rows, ordered
Crown Slash, Twin Sigil, Skybreak, Tidal Aegis, Cinderfall, Brass Judgment,
Moonlit Sever, and Regalia Nova. Regular encounters use Crown Slash; chapter
bosses use their numbered row, reserving Regalia Nova for the final boss.
Every enemy-completion cinematic uses three full-screen camera beats: the
complete knight finisher, a pan to the opponent's four-frame defeat, and a pan
back before the knight's victory animation begins. The artwork viewport and
opaque caption occupy separate layout regions so no move can disappear behind
the caption on portrait or landscape screens. The split-screen composition is
reserved for encounter introductions and must not be reused for a defeat.

The code-painted enemy silhouettes in `lib/widgets/combat_presentation.dart`
are error fallbacks only. They are placeholder art and must not appear when a
declared production atlas is packaged correctly. No placeholder asset remains
to be replaced for this combat-presentation backlog; the fallback stays solely
so a corrupt package does not leave an empty header. Atlas dimensions, frame
occupancy, reaction differences, synchronization, reduced motion, and rendered
composition are covered by animation and golden tests.

## Entitlements and availability

`ContentEntitlementPolicy` is the storefront-neutral boundary. Web policy admits
only the origin arc, requires its descriptor to include the `web` channel, and
grants the base origin and Just Puzzle entitlements. The bundled Academy is
system content shared by both editions rather than an arc entitlement.
Paid-platform policy also grants the base content, then accepts explicit
purchased entitlement IDs supplied by the native store/receipt layer.

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

The home Bestiary follows that same manifest order, then chapter and encounter
order within each arc. A foe is revealed only when its encounter puzzle has a
durable clean or assisted completion record; map unlocks and in-progress
replays do not reveal or temporarily hide entries. Locked slots must not load
the foe asset or expose its name through text or semantics. Revealed entries
may preview all six authored atlas reactions without changing story state.
Idle repeats continuously. Stagger, strike, press, and exposed are one-shot
interruptions that return to the idle loop when their authored row completes.
Defeat alone holds on its final frame; choosing idle or another reaction after
defeat restarts playback, with transient reactions again returning to idle.

## Academy lessons

The ordered curriculum lives in `assets/academy/lessons.json`. Each lesson has
a stable `regalia:lesson/academy/*` ID, concise teaching copy, a configured
visual example, a `DeductionTechnique`, and a `sourcePuzzleId`. At load time the
source grid is cloned to a separate `regalia:puzzle/academy/*` ID, so practice
marks and completions never enter an arc's boards, records, or frontier.

Lesson order is consecutive and controls unlocking: lesson one is always open,
then each lesson unlocks when its predecessor is completed. A source puzzle
must remain in the packaged origin catalog and its human-solver trace must
contain the lesson's declared technique; controller tests enforce both rules.

## Settings ownership

Master settings is opened from the home screen and owns preferences that apply
across the app and the full-game reset. The full reset erases every arc,
tutorial and Just Puzzle data, and all preferences, so its UI must retain two
separate warning confirmations.

Every master or story-arc settings page includes the same explicit “Support the
developer” action. The approved Buy Me a Coffee page is the only external URL
and always opens through a user action. On web only, completing the puzzle
immediately before a chapter boss may show the same choice once for that
chapter. Claim the namespaced chapter ID before displaying the prompt, persist
it across sessions, and never show the prompt in Academy, Just Puzzle, or paid
platform builds. An arc reset begins that arc's prompt history again; a full
reset clears all prompt history.

Map unlock and progress reset actions belong in an arc’s own settings screen.
The gear on a story map opens that selected arc’s settings, not master settings.
Always pass the target arc ID to the controller. An arc reset removes only IDs
owned by that namespace and must preserve master preferences, tutorial state,
Just Puzzle runs, entitlements, and progress in every other arc.

Unlock Game Board is deliberately map-only: it opens every puzzle and chapter
landmark, including direct access to the final boss, but never exposes the
finale. The finale becomes available only after the final boss has a saved
clean or assisted completion record. On startup, stored finale unlock IDs are
reconciled with that record so legacy overrides cannot bypass the boss.

Catalog upgrades retain boards and completion records whose immutable puzzle
IDs and sizes still exist. A changed grid must therefore receive a new puzzle
ID; removed/replaced IDs are ignored during restore while unaffected progress
survives.

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
