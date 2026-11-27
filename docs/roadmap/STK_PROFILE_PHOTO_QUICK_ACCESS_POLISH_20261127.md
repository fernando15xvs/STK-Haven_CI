# Profile photo and quick access — 2026-11-27

- A: stable per-avatar memory provider, cached resized thumbnail, preloading and gapless playback. A genuine replacement or removal resets the old image.
- B: dedicated private viewer with a viewport-sized contained image, black status area, navigation contrast, safe close button, pinch/double-tap zoom and downward swipe at base zoom. Restores original system appearance on close; reduced-motion users get no animation.
- C: new imports up to 1440 px / quality 82 with 1 MiB byte limit before Base64. Existing schema and photo data unchanged. Old compressed photos cannot regain lost resolution without re-import. Oversized images require a smaller selection.
- D: circles 44 dp, icons 21 dp, border 1 dp, labels 12 sp weight 600, spacing 8 dp, icon-label gap 4 dp. Full tile remains tappable; active theme font and accent retained.
- E/F: preserve system gestures/buttons, primary tabs and appearance. Text remains scalable, menu scrolls at accessibility sizes.
- G: regression coverage for stable avatar provider after settings, removal, viewport/status area, close/restoration, zoom/swipe, reduced motion and menu layout/contrast. Real-device tests remain necessary. No schema, Web or Supabase changes.
