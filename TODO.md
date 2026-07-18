# App To-Do List

This is the working backlog for the remaining gameplay, story, presentation, and polish work.

## Priority legend

- **P0 — Blocker:** broken functionality or required for the core game loop
- **P1 — Core:** important gameplay or story work
- **P2 — Polish:** improvements that can follow the core work

## Gameplay and progression

- [x] **P1 — Future-proof the app for additional story arcs and platform-specific content.**
  - Treat the current story as the self-contained origin arc, with story content organized so future arcs can be added as separate modules.
  - Keep chapter, map, puzzle, scene, unlock, and save-data identifiers namespaced or otherwise extensible so new arcs do not conflict with existing progress.
  - Make story-arc metadata and content loading data-driven rather than hard-coded to a single campaign.
  - Define the web/GitHub Pages edition as the origin story plus “Just Puzzle!” functionality.
  - Allow paid platform editions to include additional story arcs through a clear platform/content entitlement layer.
  - Ensure missing or unavailable future arcs fail gracefully and do not affect the origin story or puzzle-only mode.
  - Document the content packaging and release process so adding a new arc is a seamless update.

- [x] **P1 — Optionally unlock the final scene from the Settings “Unlock Game Board” action.**
  - When enabled, make the existing unlock-game-board button also unlock access to the final scene.
  - Add a clearly named code/configuration toggle so this behavior can be turned on or off later without reworking the UI.
  - Keep the current board-unlock behavior unchanged when the toggle is disabled.
  - Verify that the final scene becomes available immediately when enabled and that normal progression is unaffected.

- [ ] **P1 — Add an Academy for learning deductive techniques.**
  - Create a dedicated area where players can study the game’s solving logic and deduction techniques.
  - Explain each technique with a short lesson, visual example, and an interactive practice puzzle.
  - Start with fundamentals and unlock more advanced techniques as lessons are completed.
  - Let players revisit completed lessons and practice techniques without affecting the main journey.
  - Track lesson completion and make the Academy accessible from the main navigation.

- [x] **P1 — Add a boss puzzle at the end of every chapter.**
  - Set each boss puzzle’s difficulty to match the difficulty of the next chapter.
  - Verify that completing the puzzle unlocks the next chapter/map progression.
  - Define and document the boss, puzzle size, and target difficulty for each chapter.

- [x] **P1 — Add the final map boss as a 12×12 puzzle.**
  - Confirm the 12×12 board is supported by generation, rendering, input, validation, and completion flows.
  - Give the final boss an appropriately climactic encounter and completion sequence.

- [x] **P2 — Add optional enemy encounters within chapters.**
  - Give each chapter a small set of enemy sprites that can appear during selected puzzles.
  - Keep these encounters optional so they do not block the main chapter path.
  - Establish which puzzles trigger each encounter and how encounters affect presentation or rewards.

## Combat animation and boss presentation

- [x] **P1 — Remove the knight’s dance animation everywhere.**
  - Do not play the dance animation when a puzzle is completed.
  - Remove or replace any other gameplay, scene, or UI trigger that can play the dance animation.
  - Confirm completion sequences transition to the intended victory or special-attack animation instead.
  - Remove stale references and update animation tests or golden assets as needed.

- [x] **P1 — Create boss sprites and boss-puzzle combat sequences.**
  - Show the knight fighting the boss during the boss puzzle.
  - Animate the boss responding appropriately to the knight’s existing attack, defence, and other move animations.
  - When the puzzle is solved, have the boss fall or be defeated during the knight’s final special attack.

- [x] **P1 — Add enemy response animations for regular encounters.**
  - Reuse the knight’s existing attack/defence/etc. moves as timing and style references.
  - Add readable enemy reactions to each relevant knight move.
  - End each encounter with the enemy falling on the final special attack when the puzzle is solved.

- [x] **P1 — Make chapter-ending special moves progressively more impressive.**
  - Ensure the knight finishes off each chapter boss after its puzzle is completed.
  - Increase the spectacle, effects, or animation complexity as the chapter number increases.
  - Reserve the strongest version for the final boss.

## Story and cinematic scenes

- [ ] **P2 — Remove sprites from chapter-start screens.**
  - Remove character and other scene sprites from the chapter introduction/start cards.
  - Retain the existing sprites in the intro and finale cinematic sequences.
  - Check spacing, backgrounds, text placement, and transitions after the sprites are removed.
  - Update visual regression tests or golden assets for the revised chapter-start layouts.

- [ ] **P1 — Expand story text throughout the journey.**
  - Add at least one or two paragraphs of story text to every cinematic scene.
  - Review pacing so text appears at appropriate points before, during, and after major chapters.

- [ ] **P1 — Expand the intro and finale.**
  - Make both scenes more substantial and narratively complete.
  - Consider splitting either sequence into multiple scenes to deepen character, setting, and stakes.
  - Add transitions and pacing checks so the expanded scenes remain engaging.

## Map and visual assets

- [ ] **P2 — Add a small replayable intro tile at the top of the map.**
  - Place a compact tile above the chapter path that lets players rewatch the intro scene.
  - Make the tile visually distinct from playable chapters while fitting the map layout.
  - Ensure replaying the intro does not reset progress or alter chapter unlock state.

- [ ] **P1 — Replace the final map chapter tile image.**
  - Create or select a new image for the last chapter tile.
  - Fix the current poor layout at the end of the map.
  - Ensure the new tile is distinct from the preceding chapter and looks correct at all supported sizes.

## Typography and readability

- [ ] **P2 — Explore alternative fonts for character legibility.**
  - Compare candidate fonts against the current font at the sizes used throughout the app.
  - Pay particular attention to the numerals `2`, `5`, and `8`, which currently look too similar to snake-like shapes when viewed individually.
  - Check puzzle coordinates, hints, buttons, story text, and other UI labels for readability.
  - Select and apply the clearest option while preserving the game’s visual style.
  - Update visual regression tests or golden assets if the chosen font changes rendered output.

## Visual style and polish

- [ ] **P2 — Replace sharp box corners with a hand-drawn, organic look.**
  - Review panels, buttons, dialogs, cards, tiles, and other boxed UI elements for overly rigid corners.
  - Introduce irregular or softly rounded hand-drawn edges that fit the game’s pixel-art style.
  - Keep hit areas, text layout, contrast, and accessibility behavior unchanged.
  - Apply the treatment consistently without making important controls or puzzle boundaries unclear.
  - Update visual regression tests or golden assets for the affected components.

## UI and naming

- [ ] **P2 — Match automatic crown exclusions to player-made `X` marks.**
  - Make the marks placed automatically after a crown is solved look identical to manually placed `X` exclusions.
  - Preserve the distinction in behavior internally if needed, while keeping the board presentation visually consistent.
  - Verify the styling across all board sizes, themes, and relevant puzzle states.

- [ ] **P2 — Rename “Challenge Mode” to “Just Puzzle!”.**
  - Update the visible label, navigation, explanatory copy, and any related accessibility text.
  - Update tests and internal references where the old name is user-facing.

- [ ] **P1 — Make hints easier to follow than coded cell references.**
  - Replace or supplement codes such as cell coordinates with a visual highlight, outline, pulse, or pointer directly on the referenced puzzle cell.
  - Keep the referenced row/column markings visible while the hint is active, or provide a clear temporary overlay when the board has no markings.
  - Ensure the hint still works for edge and corner cells and remains understandable on all supported board sizes.
  - Preserve a concise text description as an accessibility/fallback option.

- [ ] **P2 — Increase hint display duration.**
  - Keep each hint visible for a couple of seconds longer than it is currently.
  - Make sure the timer does not dismiss the visual highlight before the hint text disappears.
  - Add or update a test for the hint’s display duration and dismissal behavior.

## Bugs and regression coverage

- [ ] **P0 — Fix puzzle recoil under the top banner during pull-down scrolling.**
  - Confirmed issue: the bounce/overscroll recoil on puzzle screens moves the board underneath the top banner, partially hiding it.
  - Constrain the scrollable puzzle content so recoil respects the banner’s safe area and visible bounds.
  - Verify the puzzle remains fully visible after pulling down and releasing at different scroll positions.
  - Add a regression test or visual test covering the overscroll and recoil behavior.

- [ ] **P0 — Fix dragging “X” marks on puzzle boards.**
  - Confirmed issue: horizontal dragging works, but vertical dragging is intercepted or confused by page scrolling.
  - Prevent the puzzle board’s vertical drag gesture from being treated as page scrolling while the player is marking cells.
  - Restore reliable drag-to-place and drag-to-remove behavior for `X`s in both directions.
  - Preserve normal page scrolling when the gesture starts outside the board or is not clearly a board-marking gesture.
  - Verify behavior across the full board, including edges, corners, vertical drags, and quick drag gestures.
  - Add a regression test so dragging `X`s cannot silently break again.

## Verification checklist

- [ ] Play through every chapter from a fresh start and confirm the boss puzzle appears at the correct point.
- [x] Confirm all boss and optional enemy animations finish cleanly without desynchronizing from puzzle completion.
- [ ] Confirm story scenes display the intended text without clipping, overflow, or unreadable pacing.
- [ ] Confirm the final map tile and all updated art pass visual regression checks.
- [ ] Run the full test suite and perform a release build after the above work is complete.
