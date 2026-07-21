# App To-Do List

This is the working backlog for the remaining gameplay, story, presentation, and polish work.

## Priority legend

- **P0 — Blocker:** broken functionality or required for the core game loop
- **P1 — Core:** important gameplay or story work
- **P2 — Polish:** improvements that can follow the core work

## Gameplay and progression

- [ ] **P1 — Create a read-only “How to Play” walkthrough before the first prologue.**
  - After the one-time opening slides, show “How to Play” before entering the origin story and prologue.
  - Cover the game rules, puzzle interactions, story selection, and how progression/unlocks work.
  - Teach each rule forcefully and in order rather than allowing free play on a live puzzle board.
  - Use partially completed read-only boards to demonstrate deductions and interactions: one tap for a block/exclusion, two taps for a crown, and dragging to block multiple cells.
  - Make examples advance only after the intended lesson is understood or acknowledged, without changing puzzle state.
  - Do not show “How to Play” again after the first prologue has been completed; retain a clearly visible Home Screen entry for optional replay.
  - Restore the first origin-story puzzle to a normal playable puzzle instead of using it as the tutorial.
  - Ensure replaying “How to Play” never changes story, puzzle, or progression state.

- [x] **P1 — Set story arcs to nine puzzles per difficulty–size combination.**
  - Set the arc progression target to nine puzzles for each difficulty and board-size combination.
  - Ensure players can move through the current story arc faster and reach the next story arc sooner.
  - Update chapter progression, unlock thresholds, map display, puzzle catalogs, and completion tracking to use the reduced counts.
  - Confirm the shorter arc still has a satisfying difficulty curve and enough variety.
  - Preserve access to additional puzzles through “Just Puzzle!” or another replay path where appropriate.
  - Update tests, balancing data, and any progress migration needed for existing players.

- [x] **P1 — Add 12×12 puzzles to “Just Puzzle!”.**
  - Include 12×12 boards in the puzzle-only challenge pool.
  - Confirm generation, rendering, marking, validation, hints, completion, and reset behavior work at this size.
  - Balance the available 12×12 puzzles so they provide an appropriate range of difficulty.
  - Add coverage for selecting and completing a 12×12 puzzle in “Just Puzzle!”.

- [x] **P1 — Future-proof the app for additional story arcs and platform-specific content.**
  - Treat the current story as the self-contained origin arc, with story content organized so future arcs can be added as separate modules.
  - Keep chapter, map, puzzle, scene, unlock, and save-data identifiers namespaced or otherwise extensible so new arcs do not conflict with existing progress.
  - Make story-arc metadata and content loading data-driven rather than hard-coded to a single campaign.
  - Define the web/GitHub Pages edition as the origin story plus “Just Puzzle!” functionality.
  - Allow paid platform editions to include additional story arcs through a clear platform/content entitlement layer.
  - Ensure missing or unavailable future arcs fail gracefully and do not affect the origin story or puzzle-only mode.
  - Document the content packaging and release process so adding a new arc is a seamless update.

- [x] **P1 — Unlock the finale cutscene when the final boss is defeated.**
  - Make defeating the last boss the only gameplay requirement for viewing the finale.
  - Allow the finale to be viewed even if none of the other puzzles have been solved.
  - Ensure the final-boss completion state is saved and reliably unlocks the finale across sessions.
  - Keep the finale locked until the last boss is defeated, while leaving the existing board-unlock behavior unchanged.

- [x] **P1 — Add an Academy for learning deductive techniques.**
  - Create a dedicated area where players can study the game’s solving logic and deduction techniques.
  - Explain each technique with a short lesson, visual example, and an interactive practice puzzle.
  - Start with fundamentals and unlock more advanced techniques as lessons are completed.
  - Let players revisit completed lessons and practice techniques without affecting the main journey.
  - Track lesson completion and make the Academy accessible from the main navigation.

- [ ] **P1 — Disable the Academy until it can be improved.**
  - Hide or disable the Academy entry and access point while its content and experience are being improved.
  - Preserve the Academy implementation and progress data so it can be re-enabled later with a configuration toggle or feature flag.
  - Ensure disabled Academy access does not block the main journey, tutorial, or “Just Puzzle!” mode.

- [x] **P1 — Add a boss puzzle at the end of every chapter.**
  - Set each boss puzzle’s difficulty to match the difficulty of the next chapter.
  - Verify that completing the puzzle unlocks the next chapter/map progression.
  - Define and document the boss, puzzle size, and target difficulty for each chapter.

- [x] **P1 — Add the final map boss as a 12×12 puzzle.**
  - Confirm the 12×12 board is supported by generation, rendering, input, validation, and completion flows.
  - Give the final boss an appropriately climactic encounter and completion sequence.

- [x] **P2 — Add enemy encounters within chapters.**
  - Give each chapter a small set of enemy sprites that can appear during selected puzzles.
  - Keep encounter presentation mandatory on its selected puzzle without adding a separate route gate.
  - Establish which puzzles trigger each encounter and how encounters affect presentation or rewards.

## Combat animation and boss presentation

- [x] **P1 — Fix the Drowned Acolyte’s inconsistent facing direction.**
  - Review every frame of the Drowned Acolyte animation for incorrect left/right orientation.
  - Correct the frames that face the wrong way and ensure direction changes are intentional and consistent.
  - Check the animation in all gameplay and cutscene contexts where the sprite appears.
  - Add or update a visual regression test to catch future facing-direction errors.

- [x] **P1 — Present each boss-defeating special move as a cutscene.**
  - Play the knight’s final special move in a dedicated cutscene when a boss puzzle is solved.
  - Show the knight’s complete final move full-screen, pan to the boss for its defeat animation, then pan back to the knight’s victory stance.
  - Keep the boss finisher distinct from the split-screen enemy-introduction composition while retaining the cinematic moving background.
  - Clearly show the boss reacting to the special move and being defeated before returning to the chapter-completion flow.
  - Make the cutscene reusable for every chapter boss, with configurable timing, sprites, effects, and increasingly impressive special moves.
  - Ensure it does not trigger for ordinary puzzle completion or interrupt the wrong puzzle state.

- [x] **P1 — Add short animated enemy-encounter cutscenes.**
  - Create approximately two-second encounter introductions for optional enemy fights.
  - Show both the knight and enemy sprites in the cutscene.
  - Use a split-screen composition inspired by creature-battle introductions, with each character clearly framed on opposite sides.
  - Add an animated, blurred background to create energy and movement without distracting from the sprites.
  - Make the transition into and out of the puzzle smooth and ensure the cutscene does not block input longer than intended.
  - Provide a reusable encounter-cutscene component so different chapters and enemies can share the same presentation with configurable art and timing.

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

- [ ] **P2 — Limit prologues to three pages.**
  - Keep each story-arc prologue to a maximum of three pages.
  - Condense or redistribute text so the essential setup, context, and hook remain clear within the limit.
  - Check pacing, text readability, navigation, and transitions on small and large screens.

- [x] **P1 — Improve text contrast on story-arc homepage tiles.**
  - Fix the current black text over black drop shadow treatment, which makes tile labels difficult to read.
  - Adjust the text color, shadow color/strength, outline, tile overlay, or another combination to create reliable contrast.
  - Check readability across every story-arc tile image, theme, and supported display size.
  - Add or update visual regression coverage for the tile labels.

- [x] **P2 — Add a back button to the first prologue page.**
  - Let players quickly return to the Home Screen if they opened the story unintentionally.
  - Show the back button on the first prologue page without disrupting normal forward navigation.
  - Preserve the existing story state when the player returns and reopens the prologue.

- [x] **P1 — Review story-direction documents and rebalance the writing style.**
  - Identify any project document, prompt, content guide, or implementation note that may be steering the story too far toward poetry or dry exposition.
  - Define a middle-ground story voice that is clear, emotionally engaging, and concise without becoming flat or overly ornamental.
  - Update the source guidance document and affected story text to match the chosen direction.
  - Review the intro, prologue, chapter scenes, and finale together for consistency and player comprehension.

- [x] **P2 — Remove sprites from chapter-start screens.**
  - Remove character and other scene sprites from the chapter introduction/start cards.
  - Retain the existing sprites in the intro and finale cinematic sequences.
  - Check spacing, backgrounds, text placement, and transitions after the sprites are removed.
  - Update visual regression tests or golden assets for the revised chapter-start layouts.

- [x] **P1 — Expand story text throughout the journey.**
  - Add at least one or two paragraphs of story text to every cinematic scene.
  - Review pacing so text appears at appropriate points before, during, and after major chapters.

- [x] **P1 — Expand the intro and finale.**
  - Make both scenes more substantial and narratively complete.
  - Consider splitting either sequence into multiple scenes to deepen character, setting, and stakes.
  - Add transitions and pacing checks so the expanded scenes remain engaging.

## Map and visual assets

- [x] ~~**P1 — Create distinct hopeful art for the “Finale Awaits” segment.**~~ *(Cancelled — no implementation required.)*
  - ~~Replace the current Empyrean Citadel artwork used for “Finale Awaits.”~~
  - ~~Create a hopeful scene suggesting the queen is waiting for the knight’s arrival.~~
  - ~~Keep the new artwork visually distinct from the Empyrean Citadel chapter art while matching the game’s established style.~~
  - ~~Check the composition at the map tile’s display size and update visual regression assets as needed.~~

- [x] **P2 — Add a small replayable intro tile at the top of the map.**
  - Place a compact tile above the chapter path that lets players rewatch the intro scene.
  - Make the tile visually distinct from playable chapters while fitting the map layout.
  - Ensure replaying the intro does not reset progress or alter chapter unlock state.

- [x] **P1 — Replace the final map chapter tile image.**
  - Create or select a new image for the last chapter tile.
  - Fix the current poor layout at the end of the map.
  - Ensure the new tile is distinct from the preceding chapter and looks correct at all supported sizes.

## Typography and readability

- [x] **P2 — Explore alternative fonts for character legibility.**
  - Compare candidate fonts against the current font at the sizes used throughout the app.
  - Pay particular attention to the numerals `2`, `5`, and `8`, which currently look too similar to snake-like shapes when viewed individually.
  - Check puzzle coordinates, hints, buttons, story text, and other UI labels for readability.
  - Select and apply the clearest option while preserving the game’s visual style.
  - Update visual regression tests or golden assets if the chosen font changes rendered output.
  - Candidate review complete: retain the bundled Pixelify Sans font so the app keeps its established pixelated identity.

## Visual style and polish

- [x] **P2 — Replace sharp box corners with a hand-drawn, organic look.**
  - Review panels, buttons, dialogs, cards, tiles, and other boxed UI elements for overly rigid corners.
  - Introduce irregular or softly rounded hand-drawn edges that fit the game’s pixel-art style.
  - Keep hit areas, text layout, contrast, and accessibility behavior unchanged.
  - Apply the treatment consistently without making important controls or puzzle boundaries unclear.
  - Update visual regression tests or golden assets for the affected components.
  - Final direction: use clean, old-game rounded corners with subtly pixel-stepped curves and straight edges rather than wiggly outlines.

## UI and naming

- [ ] **P2 — Add a temporary “Unlock All” button to the Bestiary.**
  - Add a development/testing button on the Bestiary page that unlocks every enemy entry.
  - Use it to inspect all enemy animations without requiring normal progression.
  - Make the control clearly temporary and gate it behind a code/configuration flag or development build check.
  - Ensure it cannot unintentionally alter normal player progress or ship enabled in the production release.
  - Remove the temporary control or disable its flag before release.

- [x] **P2 — Match automatic crown exclusions to player-made `X` marks.**
  - Make the marks placed automatically after a crown is solved look identical to manually placed `X` exclusions.
  - Preserve the distinction in behavior internally if needed, while keeping the board presentation visually consistent.
  - Verify the styling across all board sizes, themes, and relevant puzzle states.

- [x] **P2 — Rename “Challenge Mode” to “Just Puzzle!”.**
  - Update the visible label, navigation, explanatory copy, and any related accessibility text.
  - Update tests and internal references where the old name is user-facing.

- [x] **P1 — Make hints easier to follow than coded cell references.**
  - Replace or supplement codes such as cell coordinates with a visual highlight, outline, pulse, or pointer directly on the referenced puzzle cell.
  - Keep the referenced row/column markings visible while the hint is active, or provide a clear temporary overlay when the board has no markings.
  - Ensure the hint still works for edge and corner cells and remains understandable on all supported board sizes.
  - Preserve a concise text description as an accessibility/fallback option.

- [x] **P2 — Increase hint display duration.**
  - Keep each hint visible for a couple of seconds longer than it is currently.
  - Make sure the timer does not dismiss the visual highlight before the hint text disappears.
  - Add or update a test for the hint’s display duration and dismissal behavior.

## Bugs and regression coverage

- [x] **P0 — Fix puzzle recoil under the top banner during pull-down scrolling.**
  - Confirmed issue: the bounce/overscroll recoil on puzzle screens moves the board underneath the top banner, partially hiding it.
  - Constrain the scrollable puzzle content so recoil respects the banner’s safe area and visible bounds.
  - Verify the puzzle remains fully visible after pulling down and releasing at different scroll positions.
  - Add a regression test or visual test covering the overscroll and recoil behavior.

- [x] **P0 — Fix dragging “X” marks on puzzle boards.**
  - Confirmed issue: horizontal dragging works, but vertical dragging is intercepted or confused by page scrolling.
  - Prevent the puzzle board’s vertical drag gesture from being treated as page scrolling while the player is marking cells.
  - Restore reliable drag-to-place and drag-to-remove behavior for `X`s in both directions.
  - Preserve normal page scrolling when the gesture starts outside the board or is not clearly a board-marking gesture.
  - Verify behavior across the full board, including edges, corners, vertical drags, and quick drag gestures.
  - Add a regression test so dragging `X`s cannot silently break again.

## Victory, story, support, and collection follow-up

- [x] **P0 — Keep complete knight animations visible.**
  - Reserve the full authored sprite width in the puzzle header, including on
    non-encounter puzzles.
  - Give full-screen victory artwork and opaque captions separate layout regions
    so special moves stay unobscured in portrait and landscape.

- [x] **P1 — Give the story a more vivid narrative voice.**
  - Replace matter-of-fact quest summaries with scene-led prose, concrete
    imagery, and a distinct emotional beat for every cinematic page.
  - Preserve literal artwork descriptions for assistive technology.

- [x] **P1 — Add developer support links and a restrained web prompt.**
  - Put the approved Buy Me a Coffee action on every settings page.
  - On web only, offer support at most once per chapter after the puzzle directly
    before its boss, with the choice persisted across sessions and replays.

- [x] **P1 — Hide the board cursor until keyboard input.**
  - Keep touch-only play visually unselected while preserving board focus for an
    attached keyboard.
  - Reveal the cursor on a handled keyboard command and hide it again when the
    player returns to touch or pointer input.

- [x] **P1 — Add an arc-organized Bestiary.**
  - Place the Bestiary on the home screen and derive discoveries from durable
    clean or assisted encounter-puzzle completions.
  - Keep undefeated identities hidden, organize entries by story arc and
    chapter, and let players replay all six authored foe reactions.
  - Resume the idle loop after every non-defeat reaction, hold defeat on its
    final frame, and restart looping when another reaction is chosen.

- [x] **P1 — Give regular enemies the full victory cutscene.**
  - Route ordinary chapter encounters through the same full-screen final move,
    opponent defeat, and knight victory sequence used for bosses.
  - Keep non-encounter, Academy, and Just Puzzle completions on their existing
    lightweight completion path.

## Verification checklist

- [x] Play through every chapter from a fresh start and confirm the boss puzzle appears at the correct point.
- [x] Confirm all boss and in-chapter enemy animations finish cleanly without desynchronizing from puzzle completion.
- [x] Confirm story scenes display the intended text without clipping, overflow, or unreadable pacing.
- [x] Confirm the final map tile and all updated art pass visual regression checks.
- [x] Run the full test suite and perform a release build after the above work is complete.
