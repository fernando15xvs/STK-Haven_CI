# C.2 — Traslado de interfaz y temas de Core a Mobile

## Cambios funcionales conservadores
- 54 archivos de `packages/core/lib` de las carpetas visuales `features/*/presentation/pages`, `features/*/presentation/widgets`, rutas visuales `features/*/presentation/*.dart` y `core/theme` son reubicados a `apps/app_mobile/lib` manteniendo la topología.
- Dos archivos de temas Flutter (`app_palette.dart`, `appearance_theme.dart`) pasan a `apps/app_mobile/lib/core/theme`; Core retiene `domain/models/appearance_settings.dart` como dato serializable.
- Mantener 8 providers ubicados todavía en `features/*/presentation/providers/` por ser lógica de estado; requerirán traslado posterior a application/providers y dependencia `riverpod` sin Flutter. **No se han dado por limpios**.
- 14 pruebas de páginas y estilos antiguas de Core se reubican a `apps/app_mobile/test/migrated_core` y se ajustan imports. Los tests sin UI permanecen en Core.
- Los imports de UI que antes apuntaban a `package:core/...` ahora apuntan a `package:gym_tracker/...`. Los imports relativos de fuentes movidas a lógica Core ahora son `package:core/...` explícitos. Los proveedores de datos siguen en Core.
- Conservados identificadores, rutas de negocio, cálculos, estado, pantallas existentes, tema Outfit, OAuth/consentimiento, historial, Supabase/Hive y records; no se ha ejecutado migración de DB.
- La Web queda congelada **sin modificación**. Las rutas Web que referencian antiguos componentes UI de Core pueden quedar incompatibles; esa deuda se evaluará al reanudar Web y no bloquea Android/iOS según el alcance aprobado.

## Aceptación
- [ ] Analizar Core y Mobile para detectar import faltante, API no visible, posible colisión de clase, uso de assets e imports relativos.
- [ ] Correr las 14 pruebas migradas y el conjunto de pruebas Android/iOS en CI espejo; comprobar 7/7 y paridad SHA.
- [ ] Auditar imports semánticos restante Core y reubicar providers desde carpetas `presentation`.
- [ ] Retirar Flutter y plugins de UI de Core; registrar zero UI/Flutter/SDK y eliminar allowlist heredada.
- [ ] QA física visual y de accesibilidad real pendiente de revisión humana en dispositivos.
