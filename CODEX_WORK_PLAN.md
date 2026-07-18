# Codex Work Plan

This document consolidates the work in [TODO.md](TODO.md) into eight efficient,
ordered Codex implementation calls. Run them sequentially: later calls depend
on the content model and interaction fixes introduced earlier.

## Recommended calls

| # | Codex call | Covers | Recommended model / intelligence |
| --- | --- | --- | --- |
| 1 | P0 puzzle input and viewport fixes | Overscroll behind banner; vertical `X` dragging; regression tests | GPT-5.6 Sol — high |
| 2 | Scalable content/platform foundation | Story arcs, namespaced IDs, data-driven loading, web “Just Puzzle!”, entitlement/fallback behavior, packaging docs | GPT-5.6 Sol — xhigh |
| 3 | Chapter bosses and progression | Boss puzzle per chapter, next-chapter difficulty, 12×12 finale, settings-based finale unlock toggle, progression tests | GPT-5.6 Sol — xhigh |
| 4 | Combat encounter system | Remove dance, boss/enemy response sequences, escalating special moves, optional encounters | GPT-5.6 Sol — xhigh |
| 5 | Academy | Lessons, visuals/practice puzzles, unlocks, persistence, navigation | GPT-5.6 Sol — high |
| 6 | Story and map presentation | Expanded intro/finale/chapter text, sprite-free chapter starts, replayable intro tile, final chapter tile/layout | GPT-5.6 Terra — high; use GPT Image 2 for new art |
| 7 | UI, accessibility, and visual polish | “Just Puzzle!” rename, visual hints/duration, automatic-X styling, font selection, organic components | GPT-5.6 Terra — high |
| 8 | Release verification | Full journey playthrough, visual-golden updates, tests, web release build | GPT-5.6 Sol — high |

## 1. P0 puzzle input and viewport fixes

```text
Use TODO.md as the source of truth and inspect the puzzle/game-screen gesture implementation. Fix both P0 issues:
1) puzzle overscroll/recoil must remain below the top banner’s safe visible area;
2) vertical drag-to-place/remove X marks must be captured by the board without breaking normal scrolling outside or unrelated to the board.
Preserve horizontal drag behavior and test edges, corners, fast drags, recoil, and layout. Add focused regression/widget tests. Run formatting, flutter analyze, and relevant tests. Do not change unrelated files.
```

## 2. Scalable content/platform foundation

```text
Use TODO.md as the source of truth. Implement its extensible content architecture: keep the present story as a self-contained origin arc, make arc/chapter/map/puzzle/scene/unlock/save IDs safely namespaced, and load arc metadata/content data-first instead of assuming one campaign. Define web as origin story plus “Just Puzzle!”; add a clear entitlement/content-availability layer for paid-platform future arcs. Missing arcs must fail gracefully without affecting origin or puzzle-only play. Document authoring, content packaging, and release steps. Preserve existing saved progress through a deliberate migration and add tests.
```

## 3. Chapter bosses and progression

```text
Use TODO.md as the source of truth. Build chapter-boss progression on top of the new content model. Add one boss puzzle at each chapter ending, with its difficulty matching the next chapter; completing it must unlock the next chapter. Implement and document the boss roster, sizes, and target difficulty. Make the final map boss a fully supported 12×12 puzzle across generation, rendering, input, validation, saving, and completion. Add a named configuration toggle so Settings → Unlock Game Board can also unlock the finale immediately when enabled, while preserving current behavior when disabled. Add progression and save-state tests.
```

## 4. Combat encounter system

```text
Use TODO.md as the source of truth. Implement the combat-presentation backlog cohesively. Remove the knight dance animation and all its triggers. Create reusable boss and regular-enemy encounter presentation: the knight’s existing moves drive readable enemy reactions, and a final special attack defeats the opponent after puzzle completion. Apply the system to chapter bosses and optional in-chapter encounters without blocking the main route. Make chapter-ending special moves increasingly spectacular, strongest for the final boss. Update or add appropriate animation and golden tests; clearly identify any needed placeholder art versus production-ready assets.
```

## 5. Academy

```text
Use TODO.md as the source of truth. Create the Academy feature: a dedicated navigation destination with progressive deduction lessons, concise explanations, visual examples, interactive practice puzzles, completion tracking, unlock rules, and replay that does not affect journey progress. Build it from data/configuration where practical so new techniques can be added without reworking navigation or persistence. Add widget/controller tests and preserve the existing tutorial and challenge flows.
```

## 6. Story and map presentation

```text
Use TODO.md as the source of truth. Implement the narrative-and-map presentation backlog. Expand every cinematic scene with readable story text; deepen and, if warranted, split the opening and finale. Remove sprites only from chapter-start cards while retaining them in intro/finale cinematics. Add a compact replayable intro tile above the journey path that never changes progress. Replace and correctly lay out the final chapter tile at all supported sizes. Update golden/visual tests and flag any generated art that needs human approval before shipping.
```

## 7. UI, accessibility, and visual polish

```text
Use TODO.md as the source of truth. Complete the coherent UX and visual-polish pass. Rename all player-facing “Challenge Mode” text to “Just Puzzle!”. Make automatic crown exclusions visually identical to player X marks. Replace coordinate-only hints with accessible visual cell highlighting plus retained text fallback and visible row/column context; increase the synchronized hint duration. Evaluate the bundled and suitable candidate fonts, especially 2/5/8 legibility, then apply the best option. Replace rigid UI boxes with consistent hand-drawn/organic edges without harming hit targets, puzzle boundaries, contrast, or accessibility. Update relevant widget and golden tests.
```

## 8. Release verification

```text
Use TODO.md as the source of truth. Perform final integration verification for every completed TODO item. Start from a fresh save and play through every chapter, verify boss timing/progression, optional encounter completion, story readability, all board sizes including 12×12, map art, web Just Puzzle! mode, and unavailable-arc fallback behavior. Run:
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/generate_puzzles.dart validate
dart run tool/verify_offline.dart
flutter build web --release
dart run tool/verify_offline.dart --web-build build/web
Fix only failures caused by this backlog, update goldens deliberately, and report remaining manual QA or art-approval items.
```

## Verification command reference

The project’s standard verification sequence is documented in [README.md](README.md).
