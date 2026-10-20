# STK Haven — Revisión de 229 Lottie (iOS/Android)

## Estado comprobado

- Borradores: **229/229**; aprobaciones editoriales/biomecánicas: **0/229**.
- Pruebas con iPhone físico realizadas y registradas: **0/229**.
- Pruebas con Android físico realizadas y registradas: **0/229**.
- Recursos distribuidos en `pubspec.yaml`: **0/229**.
- El CI #405 resultó 6/6 verde, pero solo verificó compilación y pruebas automáticas; no suplanta QA humano.

## Evidencia generada por el nuevo auditor

Ejecutar desde `apps/app_mobile`:

```bash
python3 tool/exercise_lottie_review.py --output build/lottie_review
```

Se producen `review_matrix.csv`, `summary.json` y 229 archivos `storyboards/<ID>.svg`, cada uno con cinco poses aproximadas (fotogramas 0/15/30/45/60) para detectar ilustraciones ambiguas y corregirlas antes de distribuirlas. No se cambian ejercicios persistentes ni se publican estas imágenes en web o Flutter. El CI público archiva estos informes 7 días.

**Limitación:** los SVG aproximan geométricamente la animación y NO reflejan exactamente la interpolación/antialiasing/reproducción de Lottie en dispositivos. Un CSV generado no supone aprobación.

## Protocolo de revisión por ejercicio

1. Verificar equipo, agarres, cadera, columna, articulaciones, dirección del movimiento, amplitud, alternancia y diferencias unilateral/bilateral con un especialista técnico.
2. Inspeccionar las cinco poses y la animación continua en Flutter. Rechazar las siluetas esquemáticas que no permitan entender el movimiento correctamente.
3. Reproducir en **iPhone físico** y **Android físico**. Comprobar fluidez, tamaño de la app, memoria, reinicio de bucles, pausa, orientación y funcionamiento sin conexión.
4. Verificar `reduceMotion`, alternativas textuales accesibles, fallback cuando el asset falla y licencia comercial documentada.
5. Registrar evidencias y aprobación por ID antes de modificar `approvedMedia` o distribuir archivos.

**Prioridad alta:** bisagras de cadera, press, sentadillas, movimientos unilateral y en polea, rotadores del hombro, core isométrico, progresiones Copenhagen, rueda abdominal, sissy squat y trabajo con equipo guiado.

Los archivos están preparados **para revisión**, no aprobados para publicación.
