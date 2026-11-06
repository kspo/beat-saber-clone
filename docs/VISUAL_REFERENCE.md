# Visual reference pass — 2026-10-24

## Menu refinement — 2026-10-25

The three supplied menu screenshots guide this pass: floating dark panels,
cyan Solo header, bright selected song row, larger album artwork and a prominent
Play action. Static vector stage lighting and thin red/cyan accents decorate the
existing 1408 × 640 canvas; no continuous animation or external art is required.
The library header reports the actual filtered song count. Existing selection,
search, modifiers, favorites and difficulty controls retain their signals.
Long song titles use two lines with ellipsis; validation details retain four
lines and a full-text tooltip. Headless checks cover control bounds/overlaps and
selection/play behavior; rendered headset appearance remains unverified.

User-supplied gameplay reference: https://beatsaber.com/images/video/video.webm
Downloaded copy and sampled frames are local review artifacts under `artifacts/`;
they are not included in the game. The clip is 12.966 seconds, 1920×1080,
30 fps and has no audio stream. It contains gameplay, not menus.

Observed in the sampled frames, particularly 5 and 10 seconds:

- Dark saturated beveled note bodies, broad solid white wedge marks toward
  the upper part of the face. This corrects the earlier open-chevron design.
- Cut fragments have dark interiors and very bright cut boundaries.
- Rectangular obstacles have thin bright red borders and irregular electric
  contour lines; a regular grid does not match this reference.
- The overall appearance also depends on the blue stage lighting, moving beams,
  saber trails, hit sparks and reflective floor. Materials alone do not reproduce
  the complete clip. Dot-note proportions are not clearly established by this clip.

Implemented:

- Procedural antialiased solid wedge and circular marks, darker body shading,
  narrow cut rims and dark fragment interiors; existing mesh and collision rules.
- Obstacle borders and irregular contours using one original shared 256×256
  baked scalar-field texture. Generator: `tools/make_wall_noise.py`.
- Solo menu layout with gameplay modifiers on the left, songs in the center,
  cover/details/difficulty/Play on the right. Cyan selection, dark panels,
  two-line song rows, and coordinated pause/settings/highscore panel styles.
- Main-menu canvas alpha enabled to reveal the scene between panels. Canvas
  updates remain input-driven, and the menu is hidden while playing.
- Existing controls/signals/node paths remain in place. Tests check hit-target
  bounds and overlap, selection details, difficulty population and Play availability.

Menu reference (the gameplay clip has none):
https://medium.com/@sawantdarshini/beat-saber-vr-a-ui-ux-and-interaction-analysis-of-immersive-game-design-in-vr-d9a8039d9ee0
The implemented menu uses the existing project's features; it does not add online,
campaign or other modes merely to match buttons in reference screenshots.

Validation limits:

- Headless suite: 150 checks pass, including menu layout and selection checks.
- Headless checks do not render shaders or prove visual equivalence or Quest FPS.
- No GUI Godot launch was attempted, because prior launches crashed macOS app
  registration. `tools/visual_preview.tscn` is available for manual material review.
- Changes require a newly built and installed APK; song uploads cannot update them.
- Quest screenshots, shader rendering and CPU/GPU frame-time measurements remain
  necessary before claiming an exact match or unchanged headset performance.

## Close-up reference correction

The user's five supplied close-ups resolve the mark placement and face treatment:
- Wedge moved from near the center to the entry edge: local normalized Y
  0.34–0.68, width 1.24 on a face spanning -1 to +1. Five-sided profile
  preserves the small vertical shoulders visible in the screenshots.
- Dot radius increased from 0.19 to 0.30, still centered.
- White mark emission increased to 3.2, with a narrow colored surface halo that
  works without fullscreen bloom. Halo does not extend beyond the note geometry.
- Added procedural rounded inset frame/groove, reduced roughness to 0.23 and
  adjusted metallic to 0.28. This changes shading, not the collision or mesh.
- Updated scene material overrides as well as shader defaults. The old scene
  had still overridden the narrower cut rim with 0.04; it now uses 0.018.

These are reference-guided proportions, not a claim of pixel-identical rendering.
Actual Quest lighting, tone mapping and viewing distance still need visual review.

## Lighting and cut-spark correction

The note body now uses low self-emission (0.025), metallic 0.08 and roughness
0.30. Removed the painted front-face brightness and emissive frame bands.
A warm directional key (1.15), cool rim (0.35) and subdued ambient light (0.22)
provide normal-based diffuse/specular shading. These lights do not cast shadow
maps; this pass improves surface shading without adding dynamic shadow passes.
The material preview uses the same light configuration.

The old particle effect deleted its GPU emitter on Android, and its cut trigger
was commented out. Replaced it with 24 CPU particles per burst, 0.28-second
lifetime, opaque thin streak meshes, and velocity alignment. The effect fires at
the cut plane's projection of the note center, using world-space swing direction.
It works independently of fragment falloff and the hidden note's process state.
It freezes during pause and stops on track clear or note reuse. No per-cut node
creation, GPU turbulence, alpha shells or light spawning.

155 headless checks pass, including burst bounds, cut position/direction, disabled
parent behavior, pause and track-clear cleanup. Actual rendered appearance and
Quest CPU/GPU cost still require a new APK and device review. Existing two-resource
exit warning remains; no new script errors were reported.

## Neon stage pass — 2026-11-07

Goal: genre-typical "neon arena" feel without fullscreen bloom (disabled on Quest).

- `game/NeonGlow.gdshader`: analytic light-tube halo. The beam mesh is inflated
  around its axis; each fragment computes the ray-to-segment distance to the
  beam centre and applies an additive falloff. One pass, no textures, no depth
  writes. Attached as `next_pass` of every stage laser group (colour follows all
  light events through `_on_Tween_tween_step`) and as `material_overlay` on saber
  blades (segment length tracks the blade show/hide animation).
- Notes: deeper lacquer body, neon bevel outline derived from bevel normals,
  grazing-angle rim, face vignette, two-stage tinted halo around the mark.
- Stage: metallic dark ring frames, blue depth fog (backdrop sphere excluded),
  distance-faded laser halos.
- Menu: saturated cyan selection with white text, glass panels with lit top edge
  and soft glow, static fixed-seed star dust, song rows show `Title · Artist`
  (ItemList drops line breaks).
- Previews: `tools/stage_preview.tscn` (player-eye gameplay frame) and
  `tools/menu_preview.tscn` (flat menu render), both take `-- out.png`.

Validation: 328 headless checks pass; previews rendered on macOS (Metal, Forward
Mobile). Quest GPU frame time with the additive halos is not yet measured on device.

## Arena feel pass — 2026-11-07 (second iteration)

- Atmosphere: `event_driver.gd` mixes the live light-group colours into fog colour,
  ambient light, a horizon-weighted backdrop haze and a shadowless stage
  back-light (colours note rims). Updated on every light event/tween step.
- Lasers and blades: `NeonGlow.gdshader` gained a white-hot core term
  (`core_radius`, `core_intensity`) scaled by the light level.
- Saber: wide white core shader, stronger halo, procedural metal hilt with a
  coloured emitter ring (`SaberHilt.gdshader`), additive trail ribbon with a hot
  leading edge (`SaberTrail.gdshader`).
- Impacts: `game/vfx/SparkVfx.gd` builds hot streak sparks, slow embers and an
  additive flash (CPU particles). Cut = directional spray (40) + radial burst (20)
  + embers (12) + flash; saber clash = warm streaks (30) + flash.
- Obstacles: smoked-glass body, white-hot frame, inner glow, drifting contours.
- Typography: Exo 2 (SIL OFL 1.1, `game/data/fonts/`, attribution in LICENSE)
  for menus and HUD; heavy italic for titles, PLAY and hit scores.

Validation: 328 headless checks pass; desktop renders via `tools/stage_preview.tscn`
and `tools/menu_preview.tscn`. Quest frame time still to be confirmed on device.
