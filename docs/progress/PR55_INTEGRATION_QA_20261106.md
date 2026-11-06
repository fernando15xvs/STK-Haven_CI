# PR #55 — auditoría previa a integración del lote de Progreso 2.0

**Fecha:** 2026-11-06. **Estado:** validación de código lista; no es
certificación de QA física, firma Apple ni cierre de 17 tareas.

## Resolución del conflicto

- PR: https://github.com/fernando15xvs/STK-Haven/pull/55
- Rama: `fix/progress-muscle-summary-responsive-20261105`.
- `main` al resolver: `91737b78c321766b43851ff58b7c05198534d559`.
- HEAD de la rama antes de integrar `main`:
  `c5fe90963014f901923d9c5d6b7e1021ccc2e16f`.
- Commit de integración de dos padres (no fusiona la PR a main):
  `288696a1d9b54999041f60250c03a95a8345473d`.
- Resultado GitHub: `mergeable: true, mergeable_state: clean`.
- El único conflicto de contenido era el checklist. Se conservaron
  la anotación del CI anterior en main y las notas de estrategia/lote
  en la rama. Las 17 tareas siguen con su estado sin certificar.

## Inspección del alcance (QA-04, revisión de código)

Comparación Git `main...PR`: conjunto de archivos auditados, exclusivamente:

- UI Progreso móvil: silueta de medidas, cuadrícula y KPIs musculares,
  indicadores de consistencia.
- UI entrenamiento: selección explícita del estado de cada serie en
  Android/iOS y Web; historial marca Pendiente/Omitida/Fallida solo
  cuando hay evidencia.
- Core: `WorkoutSet.recordedOutcome` opcional, adaptador Hive campo
  16 añadido sin reutilizar IDs, formato del borrador, lectura/escritura
  de historial, backup y política de estados.
- Gamificación: espera la persistencia del logro first_pr tras
  detectar un PR real, manteniendo la barrera de XP y avance para
  entrenamientos incompletos.
- Tests nuevos o ampliados (Core y widget) y documentación.

**Fuera del diff de producto:** Motivation/playlist, Coach, programas de
entrenamiento y su rotación, migraciones o funciones remotas de Supabase,
recursos 3D/PNG de anatomía, claves, certificados y secretos.

La ausencia de una modificación no garantiza por sí sola el
comportamiento en un dispositivo; los tests de recuperación e histórico
sí pasaron en el CI.

## CI y paridad de código

- Primer snapshot completo: `3dbb7bb4a6e2f49968d7e0d6ea61164d642c3659`,
  CI #753, **7/7 SUCCESS**; 23/23 blobs exactos.
- Segundo snapshot con mejoras de consistencia y silueta:
  `56bb14019e709c4a0a45c3fa72bc7b84f4cc3d9c`,
  CI #754, **7/7 SUCCESS**, 27/27 blobs exactos.
- Un CI nuevo debe validar el commit de resolución de conflicto
  y la documentación final; el CI #754 no demuestra por sí solo el
  estado posterior a la integración de main.
- El espejo público ejecuta Actions **sin PR**. Solo se transfieren
  rutas cambiadas y se compara el SHA Git blob de todas ellas.

## Artefacto iOS sin firma en CI #754

Artefacto de GitHub Actions: `stk-haven-ios-unsigned`, ID
`13469183232`, creado `2026-11-06T01:32:01Z`,
tamaño del ZIP del artefacto **25.293.554 bytes**,
digest **del ZIP del artefacto**:
`sha256:af13640fd5982eae149b93345759999a51f7e23e3e74834806750d86d7c69eeb`.
Caduca `2026-11-13T01:31:59Z`.
**No** confundir este hash con el SHA-256 del IPA interno ni una IPA
firmada o instalable en un iPhone.

## Auditoría final de diseño y preparación de iPhone

- Auditoría de todas las pantallas afectadas y las seis incidencias:
  `docs/progress/PROGRESS_2_FINAL_DESIGN_AUDIT_20261106.md`.
- Resumen: porcentajes con coma española y texto contrastado,
  regresión `progress_summary_scope_test.dart`.
- e1RM y volumen: animación cero con `MediaQuery.disableAnimationsOf`,
  regresión `progress_chart_viewport_matrix_test.dart`.
- Guía de firma local para Runner, extensión WidgetKit y App Group:
  `docs/progress/IOS_PHYSICAL_TEST_SIGNING_20261106.md`.
- **Nuevo CI obligatorio** para validar estos cambios posteriores al
  último snapshot #756 y antes de integrar en `main`.

## Bloqueos que no se deben cerrar desde el CI

- QA-05/06: iPhone y Android **físicos**, versiones del SO,
  capturas y recorridos reales: **NO EJECUTADO**.
- QA-07/DES-09: VoiceOver y TalkBack reales, Reduce Motion y
  navegación por foco en ambos sistemas: **NO EJECUTADO**.
- QA-09: firma Apple, provisioning y prueba de instalación:
  **NO EJECUTADO**. Un IPA unsigned solo demuestra compilación.
- QA-10: cierre definitivo condicionado a esas evidencias y a la
  decisión de integrar PR #55; no cerrar casillas antes de cumplir
  los criterios.

La decisión de producto GAM-01 está documentada como opción A en
`PROGRESS_GAM_FIRST_PR_POLICY_20261105.md`; no se han otorgado XP
a sesiones parciales ni reescrito registros históricos.
