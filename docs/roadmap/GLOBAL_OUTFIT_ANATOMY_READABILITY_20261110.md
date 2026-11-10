# STK Haven — tipografía global y puntos anatómicos de Medidas

**2026-11-10 · Lote único en PR canónica privada.**
Fuente de verdad: `STK-Haven/main`. El espejo `STK-Haven_CI` solo
ejecuta GitHub Actions; sin PR en el espejo.

## Hallazgo confirmado en código

El proyecto móvil usa la fuente variable local
`assets/fonts/Outfit-Variable.ttf` y Flutter **3.38.9**. En esta versión
`FontWeight` no ajusta automáticamente el eje OpenType `wght`
(Future Flutter 3.41 sí lo hace). Por ello `Outfit` puede parecer
más fina que `w600/w700` aun cuando el `TextStyle` diga "Bold".

Las 14 variantes de `AppTypography` en móvil y web ahora incluyen el
valor `FontVariation('wght', ...) ` que coincide con su
`fontWeight`. El tema Core ajusta de igual manera 15 roles
`TextTheme` para textos y componentes Material sin estilos explícitos.
Se preserva una sola familia tipográfica y el escalado accesible del SO.

- Texto de cuerpo móvil/web: 16, 14 y 13 puntos con peso 500.
- Labels: 13/12/12 puntos con peso 700/600/600.
- Superficies claro/oscuro/OLED: `textSecondary` con contraste mayor.
- No se fija un `textScaleFactor` global ni se introduce otra fuente.

## Hallazgo anatómico confirmado en capturas

Los puntos originales apuntaban a partes equivocadas: Hombros al
pectoral, Tórax al abdomen alto, brazo a la zona del codo, muslos cerca
de la rodilla, cintura sobre glúteos, cadera hacia el muslo y
pantorrillas demasiado abajo.

Las coordenadas de referencia son normalizadas **sobre la imagen PNG**
(0.0 arriba/izquierda, 1.0 abajo/derecha; lado corporal derecho =
izquierda de la imagen de frente). Los cambios son exclusivamente de
**presentación**, no valores de medición ni historial.

| Región | Coordenada anterior | Referencia nueva |
|---|---|---|
| Hombros (frente) | (.68,.225) | (.82,.190) deltoides externo |
| Tórax | (.50,.296) | (.50,.245) pectoral |
| Brazos der./izq. | (.225/.775,.352) | (.215/.785,.300) brazo superior |
| Antebrazos der./izq. | (.165/.835,.432) | (.165/.835,.385) antebrazo |
| Muslos der./izq. | (.418/.582,.655) | (.415/.585,.535) mitad del muslo |
| Cintura (espalda) | (.50,.472) | (.50,.360) por encima de pelvis |
| Cadera (espalda) | (.54,.550) | (.54,.460) máximo glúteo/cadera |
| Pantorrillas | (.40/.60,.820) | (.40/.60,.730) vientre muscular |

Además, el lienzo ya no estira la caja `BoxFit.contain` cuando
el alto crece por texto accesible: preserva la relación 0,4 de las
imágenes y calcula los puntos en ese mismo espacio. Se ampliaron
etiquetas laterales en anchos menores de 360 puntos.

## Extensión aprobada: UX de Progreso y barra inferior

**Aprobación del usuario:** 2026-11-10. Una sola PR #56; no crear
otra PR en `STK-Haven_CI`. Se conserva la solución de tipografía
global y los 13 anclajes anatómicos anteriores.

### Diagnóstico de las cuatro capturas

1. La barra inferior de `HomeScreen` tenía **12 dp** de margen inferior
   dentro del `SafeArea`, por lo que visualmente quedaba demasiado
   alta. Ajustar el margen a **4 dp** (8 dp más abajo) sin invadir
   el indicador de inicio, con ancho flexible de botones y Outfit
   legible hasta 160% de escala.
2. `ProgressExercisesPanel` dejaba fijos el título, la descripción,
   el buscador y dos desplegables, reduciendo la altura del `ListView`.
   En la pestaña principal se conservan buscador y tarjetas, pero
   los filtros adicionales se pliegan; en rutas independientes
   siguen disponibles.
3. `FocusedExerciseProgressPage` reutilizaba el panel completo de
   la lista: el usuario volvía a ver los mismos KPI/PR y la curva
   de 65 dp sin poder seleccionar una sesión. En la pestaña principal,
   las tarjetas ahora se resumen; tocar una abre la ruta específica
   con **gráfico de 180 dp** y sesión seleccionable.
4. `_SelectableExerciseTrend` solo pintaba los puntos. El modelo
   `ExerciseSessionPerformance` **ya tiene** `bestWeight`,
   `bestReps`, `averageRir`, `estimated1RM`, `sessionId`
   y `date`. Se usan datos reales por sesión, sin migración,
   sin interpolar RIR y sin alterar historial.

### Comportamiento de rendimiento

- La métrica del gráfico puede ser **Peso / Reps / RIR / e1RM**.
- Cada punto y el selector de sesión por **fecha y hora** muestran
  simultáneamente cuatro datos de la sesión: peso máximo,
  repeticiones correspondientes, RIR medio (o «Sin registrar»)
  y e1RM máximo (o «Sin estimación»).
- El orden visual es **gráfico → datos por fecha → récords y
  comparativas**, de modo que la funcionalidad principal es visible.
- Si hay varias sesiones el mismo día, cada una conserva su
  `sessionId` y la hora de inicio para desambiguar.
- El gráfico muestra observaciones por sesión real; evita
  inventar valores de RIR y permite desplazamiento horizontal en
  historiales largos. **Historial completo** sigue mostrando las
  series individuales, no es una copia de los KPI de Progreso.
- Se mantiene el modo sin navegación de las rutas antiguas para
  no romper acceso a datos; la pantalla principal usa acceso único
  a rendimiento por ejercicio.

### Criterios añadidos

- [x] Barra 8 dp más baja sin ocupar SafeArea; etiquetas sin elipsis.
- [x] Directorio de ejercicios compacto; filtros secundarios plegables.
- [x] Pantalla de rendimiento detallada sin duplicación del listado.
- [x] Gráfico táctil de 180 dp y selector de fecha/hora por sesión ID.
- [x] Mostrar peso, reps, RIR y e1RM reales, con valores ausentes explícitos.
- [x] Priorizar el gráfico por encima de tarjetas secundarias.
- [x] Tests para 320/390 px × 100/160% de texto; métricas
      y selección de tres sesiones, incluido RIR ausente.
- [ ] Ejecutar flutter analyze, Core, mobile y compilaciones
      en espejo CI; corregir eventuales regresiones.
- [ ] Inspeccionar en iPhone/Android físico con muchos ejercicios
      e historiales; verificar scroll con teclado abierto.
- [ ] Integrar la PR #56 solo después de la validación de código
      y revisión del checklist, sin tocar historiales.

## Checklist antes de fusionar

- [x] Mantener Outfit y reforzar estilos globales móvil/web/Core.
- [x] Declarar eje `wght` explícito para Flutter 3.38.9.
- [x] Mejorar contraste secundario en claro y oscuro.
- [x] Reubicar los 13 indicadores de medidas (9 frontales, 4 dorsales).
- [x] Hacer consistentes imagen, puntos y líneas ante texto ampliado.
- [x] Añadir test de peso real, 8 acentos × 2 temas.
- [x] Añadir pruebas de posiciones anatómicas a 320/390/430 × 100/160%.
- [ ] Verificar el CI final verde, flutter analyze, Core y widget tests.
- [ ] Inspeccionar render/capturas reales en iPhone y Android y corregir
      cualquier error que los tests no detecten.
- [ ] Fusionar **una** PR a `main` después de validar el código.

**Límite:** la prueba de posición verifica el contrato de coordenadas
relativas al PNG y el dimensionado Flutter, pero no sustituye la revisión
visual sobre el teléfono. No cambia la semántica de perímetros.
