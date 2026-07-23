# Regalia art production

## Visual north star

Regalia uses readable storybook pixel paintings: crisp intentional pixel
clusters, a limited arc-specific palette, three clear depth planes, one
unmistakable landmark, and one narrative action per scene. Production artwork
must remain legible at the smallest runtime viewport, not only at source size.
Origin and Atlas of Borrowed Winds are the in-repository quality references.

Avoid flat procedural geometry, repeated template compositions, generic dotted
vignettes, smooth vector edges, baked-in UI, text, signatures, and effects that
obscure the subject silhouette.

## Production contracts

### Chapter scenes

- Source/export: 1024x1024 square, opaque, with the focal action clear in the
  center-safe region.
- Composition: foreground framing, readable midground action, atmospheric
  background; do not rely on fine detail to explain the chapter beat.
- QA masks: 1:1 story scene, 600x404 journey route, 600x250 home tile, and the
  small phone layout. Route UI must not cover the only readable subject.
- Existing metadata uses JPEG paths. New pipelines should prefer high-quality
  WebP for hard pixel edges when a coordinated metadata migration is possible.

### Expansion-arc cast and playable heroes

- Every expansion arc owns its cast art. Do not reuse the Origin Crown Bearer
  as the playable lead for an unrelated story.
- Each arc defines two to four viewpoint characters. Every named cast member
  receives a 4-column story-idle strip using the shared 768x288 geometry,
  binary-alpha, and 12-pixel cell-gutter contract.
- The first cast member is the arc's playable hero and additionally receives a
  1774x887 irregular combat atlas and a 1776x2368 finisher atlas.
- Combat row order and occupancy are fixed: eight movement frames, eight basic
  attack frames, eight special-action frames, then four reaction frames and
  four unused transparent cells. Finisher art is eight named moves with six
  distinct frames each.
- `tool/normalize_generated_hero_atlas.py` accepts either a complete sheet or
  one transparent source strip per row. `--allow-tight-row-gaps` is an explicit
  row-input-only escape hatch for complete effects separated by genuine 2px
  transparent gaps; output validation still enforces the full runtime gutters.

### Opponent reaction atlas

- Geometry: 4 columns by 6 rows, 192x192 per cell, 768x1152 total.
- Row order is an ABI: `idle`, `staggered`, `striking`, `pressing`, `exposed`,
  `defeated`.
- Direction: enemies face and attack left toward the playable hero. Staggers
  recoil right. Defeat ends low, collapsed, or dissolved.
- Safety: a natural 8-pixel transparent gutter in every cell; binary alpha; no
  chroma remnants; full anatomy and attached effects stay inside the cell.
- Readability acceptance: inspect every state at 62, 111, 196, and 300 logical
  pixels. Each row must communicate its state without relying on color alone.
- Normalization: `tool/normalize_generated_opponent.py` detects a transparent,
  chroma-free 4x6 authored grid and converts it to the runtime dimensions. The
  source sheet may use a different outer aspect ratio when all 24 complete
  poses and their natural separators are detectable. The normalizer rejects
  cells that cross their natural safety boundary and scales and repositions
  complete poses inside the output gutter; it never repairs clipping by
  erasing pixels.
  `tool/build_opponent_reaction_atlas.py` is suitable only for procedural
  fallbacks because it derives every reaction from one cutout.

## Expansion portfolio contract

Origin and Atlas establish the structural reference: each eight-chapter arc
contains two named regular encounters and one named boss per chapter. Every
unfinished expansion arc therefore ships as one coherent package with:

- eight chapter paintings and two finale paintings;
- exactly 24 distinct named opponent atlases: 16 regular enemies and eight
  chapter bosses;
- a story-idle strip for every named cast member; and
- combat and finisher atlases for that arc's playable lead.

Names, silhouettes, materials, palette, magic language, and environmental
motifs come from the individual story specification. Established boss names
remain stable. Regular encounter names must be unique within and across arcs,
and their visual descriptions must make them recognizable without labels.
Origin and Atlas art are reference-only and stay unchanged during this rollout.

## Rollout

Replace and accept one complete arc at a time so palette, character identity,
animation language, and package weight are reviewed as a coherent set. Do not
mark an arc complete while any chapter scene, named opponent, cast strip, hero
combat atlas, or hero finisher atlas is still procedural or missing.

For every replacement:

1. Lock a model/environment reference and semantic chapter beat.
2. Author all required frames with natural gutters and stable identity.
3. Normalize and run structural asset tests.
4. Review contact sheets plus the actual story, route, combat, bestiary, and
   finisher viewports.
5. Record package-size impact before accepting the arc.

`tool/generate_portfolio_arcs.py` preserves checked-in production visuals by
default and creates procedural art only for missing slots. The explicit
`--force-procedural-art` option is destructive to chapter, finale, and opponent
replacements and should be used only when intentionally restoring fallbacks.
