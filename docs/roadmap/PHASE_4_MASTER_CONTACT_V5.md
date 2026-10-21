# STK Haven — contact-constrained master v5 (experimental QA)

Derived from the same public-domain 55-joint humanoid CC0 v4; seven motion families preserved, as well as all eight glTF corrective morph drivers and 11 named muscle regions. The joint channels now solve two-link arm/leg inverse kinematics against explicit hand or foot targets across 41 keyframes per 4-second cycle.

- Bilateral overhead and left/right unilateral reaches target wrists above head.
- Bilateral curl has explicit wrist destinations in front of chest.
- Squat and hip hinge translate pelvis and plant both foot-joint supports.
- Lunge moves feet into a split stance during transition, then keeps them planted at peak. No gait mechanics are simulated.
- Flat foot orientation is preserved using orientation compensation.
- A separate animated GLB bar proxy follows the midpoint of both wrists in the overhead clip. It is NOT actual finger-to-bar collision or exercise equipment delivered to the app.

The automated test samples 121 frames per clip at 30Hz from real exported glTF rotation and translation samplers and permits at most 18 mm foot/hand deviation between keyframes. Reported exact keyframe IK contact does NOT prove biomechanical correctness. A coach must assess joint angles, equipment contact, shoulder biomechanics, and foot support.

There is no native GPU or physical-device FPS/battery validation. Only public mirror GitHub Actions runs CI; source copied to both branches. This phase never modifies apps/app_web, Supabase, workout history, pubspec.yaml or the production exercise assets. PR 43 unmerged. 229 drafts / 0 approved / 0 enabled.
