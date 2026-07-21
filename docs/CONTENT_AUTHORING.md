# Content authoring and releases

Queen’s Regalia treats every story arc as an independently loadable content
package. The common manifest is also a lightweight storefront catalog. The
web/GitHub Pages edition loads the origin package, the system Academy, and
“Just Puzzle!”, while retaining manifest-only previews of arcs that are
available in the paid apps. It must not bundle those arcs’ complete metadata,
catalogs, or gameplay art.

The iOS, Android, macOS, Windows, and Linux editions are one-time-purchase apps,
not containers for per-arc in-app purchases. A paid-platform build grants the
app edition as a whole and loads every valid, bundled arc whose descriptor has
the `paidPlatform` channel. The descriptor `entitlementId` remains a required,
stable content identifier and a boundary for possible future distribution
models; it is not a separate SKU or receipt gate in the current paid apps.

## Identity contract

Every durable ID uses `namespace:kind/path`. Every namespace, kind, and path
segment starts with a lowercase letter; its remaining characters may be
lowercase letters, numbers, dots, or hyphens. Arc-owned IDs put the arc name
first in the path:

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
   version, a full or inherited arc theme, namespaced map/unlock IDs, chapter
   ranges and presentation data, one named boss per chapter, chapter and finale
   scenes, and the puzzle catalog asset path. New packages omit the opening
   scene here: `storefront.prologuePreview` in the manifest is the canonical
   opening and is injected when the package is loaded. An opening retained in
   arc metadata is supported only for legacy packages; its ID must match the
   storefront prologue, and its copy must be kept synchronized.
3. Create a catalog whose puzzle IDs are `regalia:puzzle/<arc>/...`. Orders must
   be contiguous from 1 and exactly cover the chapter ranges. Puzzle hashes,
   schema version, scoring model, and uniqueness rules remain mandatory.
4. Add arc-specific art/assets under edition-aware paths. Every runtime content
   read uses Flutter’s bundled asset system; remote metadata, downloadable
   catalogs, and runtime art downloads are unsupported. Declare the complete
   package only in paid-build asset configuration. Declare the lightweight
   storefront and preview assets in the web build as well.
5. Add a descriptor to `assets/content/manifest.json`. A paid-only arc uses
   `"channels": ["paidPlatform"]` and can opt into a locked web tile with
   `"lockedPreviewChannels": ["web"]`. Its descriptor remains in the common
   manifest so that preview can render without loading the package. Author all
   required `storefront` copy, colors, tile art, and the canonical opening
   there. Availability and locked-preview placement are both data-driven; a
   channel cannot appear in both lists for the same arc.
6. Add loader, progression, theme, map-layout, cinematic, finisher,
   missing-package, invalid-package, save-restore, and web-preview tests. The
   web test must prove that opening the preview never reads `metadataAsset`.
   Do not make origin or Just Puzzle tests depend on the optional package.

### Storefront manifest descriptor

Every descriptor is parsed before any full arc package is considered, so its
storefront data must be valid even in an edition that will not load the arc.
Use this shape for a new paid-only arc:

```json
{
  "arcId": "regalia:arc/moon-court",
  "metadataAsset": "assets/content/arcs/moon-court/arc.json",
  "entitlementId": "regalia:entitlement/paid/moon-court",
  "channels": ["paidPlatform"],
  "lockedPreviewChannels": ["web"],
  "storefront": {
    "title": "The Moon Court",
    "tileSubtitle": "Enter the silver court",
    "lockedTileSubtitle": "Preview the prologue",
    "tileArtAsset": "assets/storefront/moon-court/tile.webp",
    "tileForegroundAsset": "assets/storefront/moon-court/bearer.png",
    "theme": {
      "backgroundColor": "#21152f",
      "surfaceColor": "#39234c",
      "primaryColor": "#8567a8",
      "secondaryColor": "#e5bd6b"
    },
    "prologuePreview": {
      "id": "regalia:scene/moon-court/opening",
      "role": "opening",
      "defaults": {
        "background": {
          "asset": "assets/storefront/moon-court/prologue.webp",
          "fit": "cover"
        }
      },
      "frames": [
        {
          "id": "at-the-gate",
          "title": "A Moonless Welcome",
          "paragraphs": [
            "The silver court closed its gates as a second crown appeared above the city."
          ],
          "semanticLabel": "A silver city beneath a moonless sky.",
          "actionLabel": "Continue"
        },
        {
          "id": "journey-ahead",
          "title": "Behind the Silver Gate",
          "paragraphs": [
            "The deeper story continues in the complete app alongside every other arc."
          ],
          "semanticLabel": "Two figures wait behind a silver gate.",
          "actionLabel": "View the apps"
        }
      ]
    }
  }
}
```

`title`, both subtitles, and every scene string must be non-empty.
`tileForegroundAsset` is optional. Tile assets must start with `assets/`, must
not contain `..`, and must exist in every edition that displays the descriptor.
Each storefront theme color is a required six-digit `#RRGGBB` value. The
preview must have role `opening`, and its namespaced scene ID must belong to the
descriptor’s arc.

The home tile always takes its title, subtitle, palette, tile art, and optional
foreground from this lightweight `storefront` object. Those values must be
production-ready even when the full arc is installed; they are not fallback
copy derived from the first chapter.

### Full arc package

An `arc.json` root has `schemaVersion: 1`, the same `id` as its descriptor, a
positive `contentVersion`, a non-empty `title`, an optional `theme`, its
namespaced `mapId`, `puzzleCatalogAsset`, `unlocks.fullMap`,
`unlocks.finale`, and non-empty `chapters` and `scenes` arrays. Keep the full
arc title aligned with the storefront title even though they serve different
loading layers.

Each chapter declares its namespaced `id`, the arc `mapId`, a namespaced
`sceneId`, `artKey`, bundled `artAsset`, an integer `visualIndex`, non-empty
`title` and `caption`, contiguous `startOrder` and `endOrder`, `difficulty`,
board `size`, one `boss`, required `primaryColor` and `secondaryColor`, and
optional `encounters`, `mapLayout`, and partial `theme`. Supported difficulties
are `easy`, `medium`, `hard`, and `expert`; the chapter range must refer to that
same ordered span in the catalog. `visualIndex` selects the code-painted
landscape fallback and is clamped to the supported range `0..7`.

Every chapter scene ID must resolve within `scenes`. New metadata contains its
chapter scenes and exactly one `finale`; the manifest supplies the one opening.
Encounter puzzle IDs must be unique within the chapter, fall inside its order
range, and differ from the boss puzzle. Boss and enemy sprite assets must be
safe PNG paths under `assets/art/combat/opponents/`.

The loader validates namespace ownership, unique IDs, contiguous chapters and
puzzles, required opening/finale scenes, catalog integrity, and package/manifest
arc agreement. The canonical manifest prologue supplies the required opening
when arc metadata omits it. Every chapter boss must reference the puzzle at its
chapter’s `endOrder`; its size and target difficulty must match that puzzle. A
non-final boss must target the next chapter and match that chapter’s difficulty.
The last boss targets the arc’s finale unlock.

A missing or invalid eligible package receives an isolated availability status;
other packages continue to load. That isolation begins after the common
manifest has parsed. A malformed descriptor, storefront preview, or root
`storeLinks` object invalidates the manifest itself, so lightweight data needs
the same validation coverage as full packages.

### Arc themes and chapter palettes

The optional root `theme` controls the shared UI around every chapter in the
arc. Omission uses the established midnight theme. `brightness` is `dark` or
`light`; the remaining supported keys are `backgroundColor`, `surfaceColor`,
`surfaceLowColor`, `surfaceHighColor`, `surfaceContainerHighColor`,
`foregroundColor`, `mutedForegroundColor`, `outlineColor`,
`outlineVariantColor`, `inkColor`, and `dangerColor`. Each color must be exactly
six-digit `#RRGGBB`. A partial object inherits omitted values from midnight.

Every chapter still requires `primaryColor` and `secondaryColor` for its route,
landscape, and combat accents. Its optional `theme` uses the same keys and
partially overrides the resolved arc theme. Keep text/background contrast
accessible after both levels have been merged. The four-color storefront theme
is a separate lightweight schema: it is expanded into a complete preview UI
theme without loading the arc metadata.

### Journey map layout

Each chapter may configure its route independently:

```json
"mapLayout": {
  "columns": 4,
  "pattern": "snake",
  "direction": "rightToLeft"
}
```

`columns` must be positive. `pattern` is `snake`, which reverses each successive
row, or `rows`, which starts every row on the same side. `direction` is
`leftToRight` or `rightToLeft` and selects the first row’s starting side. If
`mapLayout` or any of its fields is omitted, the defaults are three columns, a
snake, and left-to-right. Node order remains the catalog/chapter order; layout
changes presentation only and does not change progression or durable IDs.

### Cinematic scenes

New scenes use the `frames` shape. `pages`, a root `artAsset`, and the old
single-page narrative shape remain readable for legacy packages, but should not
be used for new content. A preferred scene looks like this:

```json
{
  "id": "regalia:scene/moon-court/finale",
  "role": "finale",
  "defaults": {
    "background": {
      "asset": "assets/art/moon-court/finale.webp",
      "fit": "cover"
    },
    "characters": [
      {
        "id": "queen",
        "source": {"type": "builtIn", "character": "queen"},
        "alignment": "bottomRight",
        "size": {"height": 145},
        "semanticLabel": "The Queen"
      }
    ]
  },
  "frames": [
    {
      "id": "dawn",
      "narrative": {
        "title": "Dawn at the Court",
        "paragraphs": [
          "Sunlight crossed the open gate and reached the throne."
        ],
        "semanticLabel": "The Queen watches sunlight enter the silver court.",
        "actionLabel": "Return to the map"
      }
    }
  ]
}
```

A scene must resolve to at least one frame, frame IDs must be unique within the
scene, and each frame must resolve a background. Put shared `background` and
`characters` under `defaults`; a frame can override either. A frame-level
`characters` array replaces the default array rather than merging with it, and
`"characters": []` deliberately renders environment art alone. Use that empty
cast for chapter-start cinematics. Opening and finale frames may retain the
principal characters.

`background.fit` accepts `cover`, `contain`, `fill`, `fitWidth`, `fitHeight`,
`none`, or `scaleDown`. A frame’s narrative may be nested under `narrative` as
above or use the same keys directly on the frame. Author an explicit non-empty
`title`, ordered non-empty `paragraphs`, literal image `semanticLabel`, and
button `actionLabel` for every frame even though compatibility defaults exist.

Character sources are built-ins (`crownBearer` and `queen`) or bundled custom
assets (`{"type": "asset", "asset": "assets/..."}`). Character IDs are
unique per frame. `alignment` may be a named position such as `bottomLeft` or
an `{x, y}` object whose coordinates are both in `-1..1`. Optional `size`
dimensions and `scale` must be positive; `mirrored` flips custom art;
`zOrder` controls back-to-front paint order. Asset paths must be relative,
must not traverse with `..`, and must be declared in the target edition.

An asset character layer may also declare an evenly divided sprite-sheet
`animation`. Set positive `frameCount`, `columns`, and `rows`, a non-negative
`startFrame`, either `frameDurationMs` or `framesPerSecond`, and `loop`.
`startFrame + frameCount` must fit in the sheet. Always choose a
`reducedMotion` behavior: `firstFrame`, `lastFrame`, `hideLayer`, or
`{"behavior": "selectedFrame", "frame": 0}` using an in-range local frame.

Chapter introductions normally use one frame with at least two short
paragraphs. A prologue may use no more than three frames (pages). Use each
frame to establish one clear turn: the problem, the immediate choice, or the
consequence. Finales may use several frames when the ending needs room, but
should still favor a small number of clear beats. Only completing the last
frame records the scene as seen. The web locked preview uses the same canonical
opening but deliberately records no seen or progression state. Map replay
entries must likewise use replay mode so revisiting a scene does not write story
or progression state.

### Narrative clarity and per-arc voice

Clarity is a floor, not the voice of the game. After reading a frame once, a
player should be able to say who acted, what changed, why it matters, and what
the immediate choice or danger is. Keep the reader's mental load light: give
each frame one main event and introduce only the detail needed to understand
that event. Prefer a concrete person, place, action, and result over an
abstract explanation of the setting's rules. If the plot depends on a magical
rule or an invented term, state plainly what it does the first time it matters.
For example, say that Nahla is a mapmaker and that the atlas can move water;
do not make the reader infer either from metaphor or specialist vocabulary.
Strange imagery is welcome; obscuring the event it describes is not.

Write in short, direct sentences where they carry the story best. Do not stack
multiple causes, exceptions, institutions, and invented terms into one
paragraph. A scene may have depth, but the player should never need to decode
the basic action before they can enjoy it. Revise for the simplest accurate
wording, then add only the flavor that supports the scene.

Those checks are an editing pass, not a prose formula. Do not impose a sensory
detail quota, a fixed sentence rhythm, a required narrator distance, or one
serious "fantasy" register on every arc. Humor, dialogue, irony, dread,
romance, plain speech, and ornament can all belong when the individual story
supports them. A page does not need to announce every fact in the same order,
and different arcs should not sound as though one narrator wrote them from a
template.

Give each arc a short voice brief before drafting its scenes. Describe the
story's attitude, character focus, range of humor, emotional limits, and a few
concrete motifs; do not turn the brief into a universal checklist. The current
arcs use deliberately different briefs:

- **Queen's Regalia: Origin Story** is an earnest, measured rescue tale. Its
  unnamed knight is defined through decisions, so the narration is serious and
  restrained, with concrete magical detail and very little banter.
- **The Atlas of Borrowed Winds** is a character-led desert adventure about
  maps, power, and consent. It can be warm, quick, and wry about royal
  bureaucracy; Nahla, Ilyun, and Samir may disagree or joke like people who
  know one another. Scenes dealing with debt, coercion, displacement, or
  consent become direct rather than flippant. Ink, brass, wells, wind, and
  practical navigation give it texture, while map magic is explained by what
  it visibly does to people and places.

Future arcs may lean comic, horrific, romantic, mythic, or otherwise. Preserve
their chosen voice while keeping the events intelligible on a first read.
Avoid repeating the same place/problem/object/boss summary from chapter to
chapter. Keep the separate `semanticLabel` literal and concise for assistive
technology.

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
declares a `spriteFamily`, a `spriteAsset`, and a `spectacleLevel` from 1 through
8. New content also declares an explicit `finisher` so its move is independent
of chapter position:

```json
"finisher": {
  "track": "moonlitSever",
  "moveName": "Silver Verdict",
  "effectLevel": 7
}
```

`track` selects one of the shared authored atlas tracks, `moveName` is the
non-empty player-facing caption, and `effectLevel` from 1 through 8 controls the
effects and timing. If `finisher` is omitted, legacy compatibility maps
`spectacleLevel` to the corresponding track, default move name, and effect
level. Do not rely on that mapping for a new arc. `spectacleLevel` itself need
not equal the chapter index; design an escalation appropriate to the arc and
give its climactic encounter the strongest intended treatment.

Each `encounters` entry declares a namespaced `enemy` ID, display name, an
existing non-boss `puzzleId`, a `spriteFamily`, and a `spriteAsset`. It may use
the same optional `finisher` object; without one a regular encounter defaults
to Crown Slash at effect level 1. An encounter is mandatory presentation on its
selected puzzle: it cannot be dismissed from the header, grants no separate
durable reward, and does not add a new frontier or unlock requirement.

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
Moonlit Sever, and Regalia Nova. Their JSON keys are `crownSlash`, `twinSigil`,
`skybreak`, `tidalAegis`, `cinderfall`, `brassJudgment`, `moonlitSever`, and
`regaliaNova`. Unknown names are rejected. The origin bosses deliberately use
these tracks in order and reserve Regalia Nova for the final boss, but another
arc may choose any existing track explicitly. Adding a ninth track is a code
and shared-atlas change, not a data-only package change.
Each 296 px finisher cell keeps the complete pose and effect inside a genuine
24 px transparent safety gutter. Pack frames at the transparent gaps between
complete poses rather than slicing a generated strip into equal sixths; equal
slices can sever a slash, flame, spectral trail, or aura before padding is
added. Long straight alpha runs at a content edge are treated as a failed
export unless they are an intentional ground-contact baseline.
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

`ContentEntitlementPolicy` is the storefront-neutral boundary. Shipping
policies admit and grant every descriptor that lists the active release
channel. The current manifest lists only Origin on `web`, while a future
manifest can make another arc available there without a Dart change. The
bundled Academy is system content shared by both editions rather than an arc
entitlement.

Paid-platform policy represents ownership of the one-time-purchase app itself.
It admits every descriptor with the `paidPlatform` channel and treats every
such descriptor’s entitlement as granted. Do not create per-arc products,
receipt restore logic, or unlock prompts, and do not require
`grantedEntitlementIds` for the standard paid build. That set remains part of
the neutral policy API for tests or a future distribution model, but it does
not narrow the current paid app’s content.

UI code should read `ContentRegistry.availabilityFor(arcId)` and distinguish:

- `available`: eligible and granted, with metadata and catalog loaded and
  validated;
- `notEntitled`: an eligible descriptor denied by a custom entitlement policy;
  its package is not read;
- `notInEdition`: excluded by the release policy; its package is not read;
- `missingPackage` or `invalidPackage`: packaging/content error isolated to the
  arc after a load was attempted;
- `notPackaged`: the manifest has no descriptor for that ID.

`notEntitled` remains a supported status, but neither current shipping policy
uses it as a per-arc purchase state. Do not infer availability from asset
presence, and do not turn an optional-arc failure into an application startup
failure.

The home screen renders available arcs in manifest order. It renders a
`notInEdition` descriptor as a locked tile only when that descriptor lists the
active channel in `lockedPreviewChannels`. Tapping one plays the descriptor’s
canonical prologue without recording it as seen, never reads `metadataAsset`,
and then presents the paid-app links. The home screen does not turn
`notEntitled`, missing, or invalid packages into playable tiles or previews.
“Just Puzzle!” remains independently visible whenever its own feature
entitlement is available, including when no story package can load.

### Store links

Store links are root manifest data, not arc metadata:

```json
"storeLinks": {
  "appStore": "https://apps.apple.com/app/example/id123456789",
  "playStore": "https://play.google.com/store/apps/details?id=example.app"
}
```

If `storeLinks` is present, both values must be valid HTTPS URLs. The App Store
host must be exactly `apps.apple.com`; the Play Store host must be exactly
`play.google.com`. Host matching is case-insensitive, but subdomains, `www`, URL
shorteners, redirect hosts, and plain HTTP are rejected. Use the final product
listing URLs. The UI launches them in an external application only after the
player finishes a locked preview and explicitly taps a store button. The
runtime parser tolerates an omitted object and then shows no store buttons, but
the release verifier requires both links in the production manifest.

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
developer” action. Outside the manifest-owned App Store and Google Play links,
the approved Buy Me a Coffee page is the only external URL; every external URL
opens only through a user action. On web only, completing the puzzle immediately
before a chapter boss may show the support choice once for that chapter. Claim
the namespaced chapter ID before displaying the prompt, persist it across
sessions, and never show the prompt in Academy, Just Puzzle, or paid platform
builds. An arc reset begins that arc's prompt history again; a full reset clears
all prompt history.

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

### Loading and web-bundle boundary

At startup, `ContentRepository` reads the common manifest with
`rootBundle.loadString`. It parses every lightweight descriptor, then checks the
release channel and entitlement before reading that descriptor’s
`metadataAsset`; only an admitted arc proceeds to its arc JSON and puzzle
catalog. Story JSON, catalogs, backgrounds, character art, and combat sprites
are all bundled Flutter assets. There is no HTTP content loader and no
download-on-demand package fallback.

This runtime short-circuit is necessary but is not a packaging filter. Flutter
copies declared assets into the web output whether or not Dart code reads them.
Keep paid-only package files out of the web build’s asset declarations; merely
using `"channels": ["paidPlatform"]` or omitting an arc from the manifest does
not remove a declared file from `build/web`. A directory entry in
`pubspec.yaml` includes its direct children, not arbitrary nested directories,
so explicitly declare every nested preview-art directory that web needs.

The web build must contain and list for service-worker offline availability:

- the common manifest and every arc descriptor;
- the complete origin metadata, catalog, and gameplay assets;
- every descriptor’s `tileArtAsset`, optional `tileForegroundAsset`, and every
  `assets/...` reference inside `prologuePreview`, including paid-only locked
  previews;
- the system Academy, tutorial, Just Puzzle, font, and shared runtime assets.

For a descriptor without the `web` channel, its `metadataAsset` and assets used
only by that full package must not appear in the web build or its generated
service-worker resource list. This includes its catalog, chapter/scenery art,
custom scene art, and opponent sprites. An asset shared by a web arc or
explicitly referenced by the descriptor’s lightweight storefront preview is
allowed. Keep storefront assets in an intentionally web-declared path and full
paid content in separate, paid-only paths so this distinction stays
reviewable.

The checked-in `pubspec.yaml` is the secure, web-safe source of truth. Assets
used by every edition have scalar declarations. Full paid-package roots use
Flutter asset mappings with an explicit paid flavor:

```yaml
- assets/storefront/atlas-of-borrowed-winds/
- path: assets/content/arcs/atlas-of-borrowed-winds/
  flavors:
    - paid
- path: assets/art/arcs/atlas-of-borrowed-winds/backgrounds/
  flavors:
    - paid
```

Do not add `default-flavor` to the canonical pubspec. An unflavored web build
must exclude every flavored root. Flutter 3.29 can select flavored assets for
tests and for platform projects with configured Android/Xcode flavors, but it
cannot pass an asset flavor to Linux or Windows builds. For one consistent
native release path, materialize an isolated paid workspace:

```sh
paid_stage=/absolute/path/to/an/empty/staging-directory
dart run tool/stage_paid_edition.dart --output "$paid_stage"
cd "$paid_stage"
flutter pub get
dart run tool/verify_offline.dart --paid-source
flutter build apk --release       # or appbundle, ios, macos, linux, windows
dart run tool/verify_offline.dart --paid-source \
  --native-build build/app/outputs/flutter-apk/app-release.apk
```

The staging tool refuses a directory inside the repository and refuses to
overwrite a non-empty directory. It copies neither `.git`, `.dart_tool`, nor
`build`, then makes paid asset entries unconditional in the staged pubspec.
Never run `flutter build web` from that expanded workspace; the paid-source
verifier rejects combining its mode with `--web-build`.

For every release:

1. Bump an arc’s `contentVersion` when its metadata, canonical manifest
   prologue, or referenced catalog changes. Keep existing IDs stable unless the
   represented object changed.
2. Validate the common manifest and both store URLs. Confirm every referenced
   asset exists and is declared in each intended edition’s Flutter asset list.
3. For web, keep the origin descriptor eligible for `web`. Keep each paid-only
   descriptor limited to `paidPlatform` and add `web` only to its
   `lockedPreviewChannels` when a web preview is intended. Keep lightweight
   preview assets in the manifest and web bundle while excluding full packages.
   Build and inspect both the generated asset manifest and service-worker
   resource list; these assets may enter the cache on demand rather than at
   install time.
4. For paid platforms, package every intended `paidPlatform` arc and all of its
   referenced assets. Treat the store’s one-time app purchase as the entitlement
   boundary; do not wire per-arc receipts to `grantedEntitlementIds`. Test a
   fresh install, reinstall, and every packaged arc as valid, absent, and
   corrupt.
5. Run:

   ```sh
   dart format --output=none --set-exit-if-changed lib test tool
   flutter analyze
   flutter test --exclude-tags=golden
   flutter test --tags=golden
   flutter test --flavor paid test/atlas_of_borrowed_winds_paid_bundle_test.dart
   dart run tool/generate_puzzles.dart validate
   dart run tool/generate_puzzles.dart validate \
     --catalog assets/content/arcs/atlas-of-borrowed-winds/catalog.json
   dart run tool/verify_offline.dart
   flutter build web --release
   dart run tool/verify_offline.dart --web-build build/web
   ```

6. Smoke-test origin from a fresh save and a migrated legacy save. Separately
   start/resume Just Puzzle with the origin package deliberately unavailable.
   On web, play every locked prologue and confirm no full paid package is read.
   In a paid build, confirm every valid packaged arc is available without a
   per-arc purchase.

The legacy migration writes all current values before deleting old keys. It
maps old puzzle, board, scene, challenge, unlock, and save identifiers into the
canonical namespaces; valid board content and completion history are retained.
