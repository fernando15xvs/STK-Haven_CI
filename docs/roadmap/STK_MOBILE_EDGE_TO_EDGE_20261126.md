# Mobile secondary edge-to-edge — 2026-11-26

- Root MobileContentFrame keeps top/lateral protection; no longer clips Navigator at the bottom.
- PrimaryTabSafeArea is applied below Navigator to HomeScreen (Inicio, Entrenar, Progreso, Perfil) and preserves the existing dock layout.
- Secondary pages use actual MediaQuery padding inside vertical scroll content; fixed actions retain local SafeArea and Scaffold keyboard handling. The last item remains reachable above the system controls.
- Android starts in SystemUiMode.edgeToEdge; transparent navigation background and theme-aware icons. Native contrast scrim remains enabled for three-button navigation; system gesture and button controls are not hidden. iOS keeps the home indicator.
- Shared scroll-padding policy migrated across settings, exercise/routine/program, nutrition, faith/habits, coach, backup, account, achievements and motivation screens; protected forms, sheets and controls continue using safe areas. Fullscreen profile photo uses dark system-bar contrast.
- Tests simulate no inset, Android gesture and three-button insets, iOS inset, navigation back, last action and keyboard; these are not substitutes for physical-device inspection. No Core business logic, Web or Supabase changes. One mirror CI for this snapshot.
