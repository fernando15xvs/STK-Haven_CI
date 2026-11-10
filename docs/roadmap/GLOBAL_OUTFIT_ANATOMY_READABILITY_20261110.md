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
