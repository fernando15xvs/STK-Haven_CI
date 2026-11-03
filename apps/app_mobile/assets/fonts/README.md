# Outfit — tipografía oficial de STK Haven

- **Familia utilizada:** Outfit, archivo variable original `Outfit[wght].ttf` (100–900).
- **Origen verificable:** repositorio oficial `google/fonts`, ruta `ofl/outfit/Outfit[wght].ttf`.
- **SHA Git blob:** `466d6245f9582df39bf73da91a8b3c938fd061cd`.
- **Licencia:** SIL Open Font License 1.1 — consulte [OFL.txt](./OFL.txt).
- **Uso:** `apps/app_mobile/pubspec.yaml` registra la familia `Outfit` en `flutter: fonts:` y `AppearanceTheme`/ `AppTypography` ya la seleccionan. La fuente se empaqueta con iOS/Android y no necesita conexión.
- **Cambios de estilo:** no introducir otra familia en títulos, tooltips, números o gráficos; usar `AppTypography` y colores semánticos existentes.
- **QA:** ejecutar `flutter test test/design/outfit_font_bundle_test.dart` y validar en iOS/Android físicos, incluso texto ampliado y ambos temas. No dar por realizada la inspección visual física a partir de CI.
