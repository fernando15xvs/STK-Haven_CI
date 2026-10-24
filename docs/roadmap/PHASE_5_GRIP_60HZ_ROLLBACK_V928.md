# STK Haven — Fase 5 v9.28: reversión de agarre, 60 Hz

Estado: QA experimental, tres GLB no aprobados ni habilitados.

Los candidatos de agarre v9.26 se evalúan contra el GLB original v9.25
mediante la auditoría v9.27 de 241 poses a 60 Hz. Una corrección de
articulación solo se conserva si no produjo regresión observada de
distancia firmada superior a 0,5 mm, no introduce penetraciones profundas
y reduce la separación media con la barra al menos 0,015 mm.

La herramienta stabilize_grip_v928.py reescribe los datos reales de
rotación glTF para restaurar exactamente los canales de articulaciones
rechazadas. A continuación se repite la auditoría completa de 241
poses: si el nuevo conjunto provoca interacción desfavorable entre
dedos, se revierten TODAS las correcciones del clip al estado v9.25.
Nunca se fuerza la aprobación para alcanzar un resultado verde.

Se generan tres GLB exclusivamente en build/.../grip_v926/stable_v928
y grip_temporal_rollback_v928_report.json con hashes, motivos de
aceptación/reversión y comparaciones iniciales/finales. No se cambia
el esqueleto de 55 articulaciones, la malla, los ocho morphs, la
barra, el banco ni las animaciones ajenas a los dedos.

Este control no demuestra ausencia de colisiones entre muestras,
contacto físico en todos los triángulos, presión, fricción ni IK
completa, ni sustituye revisión biomecánica y artística profesional.
Continúan pendientes las pruebas físicas iOS/Android, UV y LOD
profesionales y la expansión del catálogo.

STK-Haven privado = fuente principal; STK-Haven_CI público = solo CI.
Rama feat/mobile-lottie-batch1-drafts-20261018; PR #43 sin fusionar.
Sin apps/app_web, Supabase, historial, IDs, pubspec ni producción.
229 drafts, 0 aprobados, 0 habilitados.
