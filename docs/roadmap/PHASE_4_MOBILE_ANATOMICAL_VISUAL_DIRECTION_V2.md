# STK Haven — Referencia anatómica móvil v2 (aprobada en dirección, no en assets)
Fecha: 2026-10-20

## Decisión del creador
Se aprobó como **objetivo visual** el mockup de tres pantallas de ejercicios: figura atlética
anatómica de apariencia volumétrica/3D, músculos esculpidos en **escala de grises** y
**solo los músculos participantes destacados** con el acento elegido en STK Haven.
No se aprobó la ilustración de atleta vestido ni los Lottie de silueta plana v1.
La imagen de referencia es un mockup estático generado: **no es** un Lottie, ni una
animación validada, ni una pantalla que ya exista en Flutter.

## Sistema visual
- Misma identidad de personaje en todo el catálogo: adulto atlético, músculos y articulaciones
  diferenciables, sombreado por volumen, manos y pies legibles y agarre anatómico realista.
- Paleta base en grises neutros (músculos no protagonistas, equipo, discos y banco).
  Músculos activos en `AppColors.primary`; matiz más oscuro solo para músculos secundarios.
  No convertir toda la ropa/torso a azul. Sin fondos horneados en el asset.
- Materiales: músculos sin texturas raster obligatorias, grises con luces/sombras;
  barras, discos y banco diferenciados por material. El acento **no** cambia la identidad
  de los objetos ni la piel entera.
- Fondo transparente de animación: la superficie Flutter provee fondo acorde a modo
  claro/oscuro. Contraste y legibilidad en 8 acentos × 2 modos (16 combinaciones).
- Cámara oblicua 3/4, coherente por ejercicio para leer anatomía, amplitud de recorrido
  y el apoyo. Usar la misma escala visual; evitar giros de cámara entre fotogramas.
- Animación continua y coherente de 4 s a modo piloto; una repetición técnicamente
  reconocible, agarres y contactos inmóviles cuando corresponda; sin parpadeos.
- Movimiento reducido: pose fija informativa; reproducción con pausa.
- No usar GIF. Priorizar Lottie **si conserva la calidad visual**; un render con sombreado
  anatómico similar al mockup NO aparece por cambiar colores de los Lottie planos.
  Antes de optar por raster/vídeo comprimido de respaldo, comparar tamaño, memoria,
  fidelidad, offline y soportes iOS/Android; registrar resultados sin falsa equivalencia.

## Zonas visibles por piloto
`ex_bench_press`: pectoral mayor (principal), deltoides anterior y tríceps braquial
(secundarios). Vista oblicua con banco, pies plantados, manos sobre la barra,
trayectoria controlada y cintura escapular plausible.

`ex_barbell_row`: dorsal ancho y espalda media (romboides/trapecio medio, principales);
deltoides posterior y flexores del codo secundarios. Vista oblicua posterior,
bisagra de cadera estable, zona lumbar neutra, barra hacia abdomen; no
alargar extremidades para conectar barra y manos.

`ex_squat`: cuádriceps y glúteo mayor (principales), aductor mayor secundario.
Vista oblicua frontal/lateral, cadera/rodillas/tobillos coordinados,
pies estables, profundidad interpretable, barra apoyada en espalda alta.

`apps/app_mobile/tool/visual_pilots/anatomical_style_v2.json` es el contrato
estructurado del diseño aprobado; NO es una declaración de biomecánica aprobada.

## Criterio de cierre por piloto
1. Comparar **capturas reales del render de Flutter** con la referencia de anatomía
   volumétrica (no solo JSON válido); revisar el fotograma inicial, posición de carga
   y transición, y movimiento completo sin deformaciones.
2. Los músculos resaltados corresponden a la anatomía descrita: el tono secundario
   no puede invadir el cuerpo entero; contraste legible en los 16 temas.
3. Pasar pruebas de decodificación, límites de recursos, reproducibilidad, ausencia
   de GIF/raster Lottie y cierre del bucle, cuando aplique la tecnología seleccionada.
4. Revisar técnica por persona competente y medir rendimiento en iPhone y Android.
5. Solo tras todas las aprobaciones cambiar `approved`/`enabled`. Mientras tanto
   **229 borradores / 0 aprobados / 0 habilitados**. No escalar a los otros 226.

## Alcance
Solo `apps/app_mobile`, documentos y QA; **no modificar `apps/app_web`**, IDs,
historial de entrenamientos ni datos en Supabase. Fuente principal privada
`fernando15xvs/STK-Haven`; espejo `fernando15xvs/STK-Haven_CI` solo para CI,
en rama `feat/mobile-lottie-batch1-drafts-20261018` y PR público #43.
