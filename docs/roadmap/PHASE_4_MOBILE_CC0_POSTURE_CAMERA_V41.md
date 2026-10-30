# STK Haven — CC0 pilot posture and camera update v4.1

## Actual implementation on mobile staging
- Press banca is more nearly supine: -1.50 rad torso from vertical, head
  roughly 9 cm above pelvis, facing up; bar presses from ~0.86 m to 1.13 m.
- A *static*, rigid flat bench cushion + frame + two legs is embedded in
  ex_bench_press only. It is NOT animated, and stays in the mobile LOD.
- Barbell row leans from the hip by ~1.15 rad; the bar starts below shoulders
  and travels toward the torso. Both hands hold it during all sampled poses.
- Captures use exercise-specific camera target, azimuth, pitch, and distance,
  rather than a single far overhead camera.
- All data is limited to apps/app_mobile experimental builders/renderers. No
  old ID, history or approval status changed. GLB + MP4 share a source.
- test_cc0_posture.py checks 81 samples per pilot, hand/foot contact,
  bench stability and torso orientation, and squat knee direction.
- Flutter still uses CPU-based skinning and drawVertices. This is a QA
  improvement; NOT full GPU-native rendering, a validated anatomical atlas,
  a clinically accurate motion nor a production sign-off.

## Remaining gates
- Compare actual screenshots at start/mid/end to prior CI and review if bench
  support, camera angle and bar travel really look natural.
- Check inter-keyframe contacts at 16, 30, 60 fps (not only 41 IK keyframes).
- Anatomist/coach review, 8 theme accents × light/dark on physical devices,
  minimum Android API 23 and iPhone support, battery and CPU/GPU profiles.
- Production models, assets and catalog NOT activated. 229 draft, 0 approved,
  0 enabled. Never touch apps/app_web or private repo Actions.
