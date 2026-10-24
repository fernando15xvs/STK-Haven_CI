# STK Haven — anatomical label atlas v4.2 (internal QA only)

The previous experimental CC0 overlay selected muscle highlights using
large axis-aligned bounding boxes. This often painted torso regions too widely.

## Implemented
- muscle_region_atlas.py defines 11 labelled regions across three pilots:
  pectoralis major, anterior deltoid, triceps brachii; latissimus dorsi,
  rhomboids, posterior deltoid, middle trapezius; quadriceps femoris,
  gluteus maximus, hamstrings, adductor magnus.
- Source glTF skin vertex buffers and all 53 joints are preserved. Each
  labelled region is a separate *index-buffer primitive* with explicit
  stkMuscleRegion/stkMuscleRole metadata. All 107,024 original source
  triangles remain assigned exactly once.
- Current exercise colors still use STK_PRIMARY and STK_SECONDARY and adapt
  to the Flutter 8 accent colors and both brightness modes. The labels
  can support future per-muscle recoloring without changing the body mesh.
- Input constraints use blend-weight support and front/back surface normals
  as well as rough rest-pose coordinates. **They do not constitute
  high-precision medical/anatomical muscle segmentation.**
- Original 53-bone finger joints are curled into approximate partial grips,
  rather than leaving the CC0 source fingers splayed out. Grip-point IK of
  the wrist still applies and the motion remains subject to visual review.
- test_muscle_region_atlas.py checks coverage, 11 region names, 10% bilateral
  symmetry, preservation of geometry; JSON summary to CI visual artifact.
- test_retarget_cc0.py checks each GLB (full and LOD) has the expected
  separate region buffers: bench 4, row 5, squat 5.

## Quality gates still unmet
Expert verified anatomical masks with exact individual muscle heads;
correct wrist rotation/pronation and finger contact with a physical bar;
bench safety, scapular motion, foot placement, shoulder position and squat
bar rack approved by a coach; a true GPU glTF renderer; device CPU/GPU
measurements, energy and 30/60 FPS measurements on Android API23/iPhone.
The current Flutter drawVertices still skins in CPU Dart with no z-buffer.

No change to apps/app_web, Supabase, workouts, exercise IDs or pubspec.
229 drafts, 0 approved, 0 enabled. CI ONLY in public STK-Haven_CI;
PR #43 must not merge until explicitly approved.
