# STK Haven — v9.45: revisión anatómica ampliada en Flutter (solo QA)

**Base:** último CI #576 (6/6 verde, 25-10-2026).
Se inspeccionó el artefacto real de v9.44
`stk-haven-visual-pilots` (ZIP de ~81 MB) y se leyó
`pixel_visibility_v944_report.json`: **0 de 36 pares**
alcanzaron el umbral heurístico del 0,5 % de píxeles modificados.
En las seis capturas de ejemplo v9.43, el cuerpo todavía ocupa una
pequeña fracción de la pantalla; en press banca y remo, las manos,
los contactos y las formas musculares **no están aprobados**.

## Corrección funcional

Nuevo test de visor QA `anatomical_focus_v945_visual_test.dart`:
- Abre realmente los tres GLB v9.42 (bench/row/squat), 55 huesos,
  ocho correctivos y equipamiento.
- Compara el encuadre general anterior (**zoom 1.2**) con una
  vista de inspección de volumen (**zoom 0.72**), permitida por
  el renderizador actual, sin modificar animaciones ni la malla.
- Toma dos órbitas laterales (±0.45 radianes) y ambos temas;
  genera **12 pares** de capturas PNG en los mismos pilotos.
- Calcula píxeles del personaje/equipamiento, proporción de
  superficie ocupada y detecta posibles recortes en el borde.
  Comprueba que cada vista próxima exhibe al menos un 10 % más
  de píxeles de primer plano que la panorámica de referencia.
- Valida también que los ocho colores mantengan frames finitos
  en las dos órbitas y ambos modos.
- Emite `focus_v945_report.json`, que entra en el artefacto visual
  existente, y el CI público verifica mediante
  `check_focus_v945.py` y `test_focus_v945.py`.

**Esto mejora el tamaño de visualización para revisión, NO la escultura
muscular profesional.** Puede recortar parte de la barra o del banco;
se informa en el JSON y no se declara aspecto aprobado. Falta
comparación por ojos humanos, retopología, músculos de distintas
cabezas, UV/PBR, agarres naturales, y QA real Metal/GLES.

Solo móvil iOS/Android; sin web, Supabase, usuarios, historial,
catálogo, dependencias o branch main. **229 borradores, 0 aprobados,
0 habilitados.** Fuente privada `fernando15xvs/STK-Haven`,
CI espejo público `fernando15xvs/STK-Haven_CI`, PR #43.
