# Roadmap 2.0 — Registro de validación física

## 2026-09-09 — Android — inicio de rutina con draft activo

### Entorno
- Rama: `feat/roadmap-2-complete`.
- Plataforma: Android físico.
- Build usado para descubrir la incidencia: APK debug generado después de la matriz automática Windows verde del candidato `3531a7298a17785c6cc06a2959bc3d0e3c9dc057`.

### Resultado observado
La navegación general funcionó hasta iniciar una rutina. Al existir un workout activo, la aplicación mostró una pantalla roja de Flutter con:

`No Overlay widget found. Tooltip widgets require an Overlay widget ancestor.`

Después de cerrar y forzar cierre, el error reapareció al iniciar porque el draft de workout persistido se restauraba correctamente y volvía a construir los controles globales del workout.

### Causa raíz
`ActiveWorkoutMemoryOverlay` se montaba desde `MaterialApp.builder`. Ese builder envuelve al `Navigator`, por lo que los controles globales quedaban por encima del `Navigator` y no tenían un `Overlay`/`Navigator` ancestro válido. Los `IconButton.tooltip` podían fallar inmediatamente y los flujos que abren diálogos también estaban expuestos al mismo defecto de contexto.

### Corrección
- Android/mobile: los controles globales se insertan mediante `OverlayEntry` en `NavigatorState.overlay` real, con `GlobalKey<NavigatorState>`.
- Web: se aplicó el mismo patrón preventivamente porque compartía la misma arquitectura.
- Se conserva el retraso de ~4 segundos del overlay móvil para no interferir con el splash.
- El workout persistido no se elimina ni se oculta; la corrección permite que se restaure y continúe con un contexto de navegación válido.

Commits de corrección:
- `197b0886a916f97c6a4d3b09f71303d34402c3a4` — mobile.
- `9eb039bc8baa5799f6a901da2e7d7fce69fb14fc` — web.

### Estado
**PENDIENTE DE REVALIDACIÓN.**

La matriz automática Windows verde anterior sigue siendo evidencia válida para `3531a729...`, pero estos cambios de runtime crean un nuevo candidato. Antes de merge se debe:
1. ejecutar análisis/tests/builds sobre el nuevo HEAD;
2. instalar el APK debug actualizado sin borrar datos si es posible;
3. confirmar que el workout activo restaurado abre sin pantalla roja;
4. probar botones del overlay: `Usar última vez`, `Copiar serie anterior`, entrada rápida, 1RM y deshacer;
5. continuar con background/resume y recreación de proceso.
