# STK Haven — anatomical master surface v2 (2026-10-21)

The 55-joint CC0 neutral master from v1 remains unchanged. This new
derived GLB is an AUTHORING-only candidate, not a professional écorché.

- Base: 70,985 source vertices and 107,024 original triangles, 55 bones;
  all source mesh indices, joint hierarchy and skin weights remain intact.
- Mesh relief: 11 existing approximate muscle-region labels are welded
  across duplicated UV seam vertices; membership is blurred over three
  adjacency passes and displaced along averaged outward vertex normals.
  6,703 vertices move by >0.2 mm, at most 9 mm. No original face flipped
  in local QA. Normals are recomputed for adjusted geometry.
- Eight distinct glTF morph targets: left/right shoulder, elbow, hip, knee
  joint-neighborhood volume correctives (3.4–4.8 mm nominal limits).
  Their default weights are all ZERO: no joint-angle drivers yet and the
  current Flutter CPU renderer does not apply morphs.
- The master still has NO exercise-specific animations, barbell or bench.
  The old three prototypes and all 229 draft exercises stay unchanged.
- Geometry test checks preservation, no inverted faces, independent left/
  right correctives and four elementary unilateral FK joint motions.
- Output: build/cc0_master_surface_v2/stk_haven_master_surface_v2_unapproved.glb
  and master_surface_v2_report.json. The 13.1 MB model is kept only in
  public CI review artifacts, NOT added to pubspec.yaml, NOT shipped.

Unmet gates: anatomical sculpt based on real muscle origins/insertions,
expert muscle masks, shoulder-blade sliding, forearm twist, anatomical
joint and bar collisions, physically validated exercise patterns, native
GPU glTF renderer and device-level FPS/battery/API23/iOS trials.

No changes to apps/app_web, production Supabase, workout history or user
accounts. 229 drafts; approved:false, enabled:false. PR #43 stays open.
