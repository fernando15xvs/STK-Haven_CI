# STK Haven — reusable 55-joint master motion laboratory v3

The neutral CC0 master v2 now has seven glTF motion **preview clips** in ONE
55-joint authoring GLB. This avoids constructing a separate character
for every fitness exercise.

A separate animation channel for glTF morph WEIGHTS connects all 8 previously
inactive correctives (left/right scapular elevation, elbow flexion,
hip flexion and knee flexion) to appropriate rotational joint motion.
The 41 keyframes span 4 seconds with looped neutral start/end and
glTF LINEAR rotation and weight interpolation.

Pattern names: overhead_reach_bilateral, unilateral_reach_left,
unilateral_reach_right, bilateral_elbow_curl, hip_hinge,
squat_articulation, split_lunge_left. These are generic articulation
diagnostics, not complete exercise demonstrations.

Generated files, in PUBLIC CI review artifacts only:
- stk_master_55_motion_lab_v3_unapproved.glb
- master_motion_v3_report.json

QA checks validate morph target count/order and correct SCALAR output
length (41 × 8), quaternion normalization, interpolation, loop closure,
opposite-side independence, and unmodified master skin/mesh.

**Known limitations**: poses lack equipment, IK foot planting and
biomechanics validation; the Dart CPU renderer does not yet sample animated
morph weights from this master GLB. Existing 53-joint exercise pilots remain
separate. The procedural relief still is not a professional anatomical sculpt.
No catalogue deployment, no pubspec assets, no GIF; 229 drafts remain
0 approved and 0 enabled. No modifications to web, Supabase, history.
PR #43 stays open and unmerged.