# STK Haven — MASTER anatomical character foundation (not exercise-specific)

## Base and gates
- Asset `stk_haven_master_55_unapproved.glb` derives from the pinned original
  Innerscene CC0 file SHA256 `7135e03b6259e970458deff3e0458610914d7c35164cae12611101361e4a5749`.
  Core MakeHuman/MPFB model rights are CC0 (see supplier license).
- This is an authoring MASTER (no animations, no exercise-specific barbell,
  equipment, bench, or colors), not an exercise demo and not a production asset.
- Original **53 joints and all 107,024 triangles**, original skin vertex
  weights and inverse-bind matrices are preserved. Two controls are inserted
  into the shoulder-girdle hierarchy, each one reparenting the corresponding
  clavicle. **55 bones total**, neutral rest transforms unchanged.
- 11 bilateral named muscle regions, **one unique set of indices each**,
  with original skin weights. These groups are *approximate* bind-pose
  classifier labels, not separately sculpted or anatomist verified muscles.
  The same master could power all exercises, rather than baking muscle color
  into the original mesh for each pilot.
- Capability profile and joint limitations accompany the GLB. Readiness
  claims deliberately remain `unverified` or `needs_motion_and_coach_review`.
- CI tests ensure every old bone stays in exactly the same bind position,
  left/right scapular controls work separately, 11 groups cover all source
  faces exactly once, and provenance/approval controls remain intact.
- Staged at `apps/app_mobile/build/cc0_master_character/` and included in
  **public CI review artifacts only**. Not imported by app pubspec, not shipped.

## Structural limits discovered and next development
1. The source CC0 has 53 bones, 5 spinal links, 1 clavicle each shoulder,
   15 finger bones each hand, but **no independent scapula bone**. Two control
   pivots now exist, yet scapula geometry is NOT separately sculpted.
2. The source is a skin mannequin rather than a realistic muscle écorché.
   A professional, legally usable anatomical sculpt and correct per-muscle
   mesh segmentation are still essential before accepting the character.
3. Add distal forearm twist support, elbow/knee hinge range controllers,
   corrective shoulder/hip deformations, controls for pulley/bench/support,
   and certified exercise-specific poses only after master QA.
4. Existing experimental `retarget_cc0_glb.py` still uses original 53-bone
   input for the three pilots and is deliberately **not** switched over yet.
5. Evaluate group hierarchy and geometric labels in Blender by an expert;
   test real device performance. CC BY-SA ecorche references require
   credit/share-alike obligations and cannot silently replace this CC0
   base inside a proprietary pipeline.

## Project safeguards
No touch `apps/app_web`, Supabase database/records, prior workout history,
exercise IDs, or any production assets. 229 drafts; 0 approved, 0 enabled.
Private STK-Haven is source of truth; CI only on STK-Haven_CI; PR #43 stays open.
