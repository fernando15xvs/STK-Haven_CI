# STK Haven — v9.43: auditoría temporal de piel y proximidad en 60 Hz (QA)

Partiendo del **CI #569 6/6 verde** para la v9.42, este bloque
añade pruebas en **241 poses interpoladas a 60 Hz** de los tres
movimientos reales: press banca, remo con barra y sentadilla.

## Objetivo

La v9.42 cambió `POSITION`/`NORMAL` de la piel móvil en el tren
superior pero los controles geométricos se centraban en el GLB en
reposo. Aquí se comprueba que **el desplazamiento sigue acotado tras
aplicar las 55 matrices del esqueleto y los ocho correctivos morph**,
y no desplaza las superficies respecto de los proxies rígidos de la
barra o del banco más de lo previsto.

## Implementación

- `audit_dynamic_torso_v943.py` abre parejas SHA-256 vinculadas
  v9.41/v9.42 y exige conservación exacta de rig, canales de
  animación, pesos, morphs, equipos y materiales.
- Selección determinista hasta 160 vértices esculpidos repartidos
  por lados y hasta 32 vértices intactos; incluye el vértice con la
  máxima variación en pose de descanso.
- Desplazamiento real después de skinning ≤ **1,24 mm** y delta de
  distancias firmadas hasta barra/banco ≤ **1,25 mm** en cada una
  de las 241 poses. Verifica también que los vértices intactos no
  deriven y que no empeore inesperadamente la costura temporal del
  ciclo. Rechaza entradas aprobadas, cambiadas de ejercicio o
  sin pareja de versión verificable.
- El reporte `dynamic_torso_v943_report.json` registra por piloto
  60 Hz, vértices auditados, muestras de skin, máximos, distancias
  mínimas, comparaciones y bloqueo de aprobación.
- `test_dynamic_torso_v943.py` corre en GitHub Actions del
  repositorio **público**, después de generar el v9.42 y antes
  de ejecutar las pruebas Flutter.
- `upper_torso_comparison_v943_visual_test.dart` genera
  capturas comparativas lado a lado v9.41/v9.42 en Flutter para
  tres tiempos × tres pilotos × claro/oscuro (18 PNG) en el
  artefacto de revisión `stk-haven-visual-pilots`.

## Restricciones claras

La geometría móvil real sí se muestrea, pero **esto NO es un test de
colisión continua**, no detecta necesariamente contactos entre
vértices o entre los instantes de 60 Hz, ni certifica biomecánica o
anatomía profesional. Las capturas no sustituyen la revisión de un
artista anatómico, un entrenador experto o pruebas físicas
Metal/OpenGL ES3 (FPS presentados, latencia, térmicas y batería).

Se conservan los **229 borradores / 0 aprobados / 0 habilitados**;
sin distribuir GLB en `pubspec.yaml`. Únicamente iOS/Android:
nada en web, Supabase, historiales, IDs de ejercicios, `main`
o producción. Fuente privada `fernando15xvs/STK-Haven`;
espejo CI público `fernando15xvs/STK-Haven_CI`, PR #43.

Siguiente paso: revisar lado a lado capturas en CI, luego abordar
retopología manual, materiales PBR, rig específico y GPU mixed
body/equipment antes de escalar a los 226 ejercicios restantes.
