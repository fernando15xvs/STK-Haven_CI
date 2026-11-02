# STK Haven — fase 5 v9.44: auditoría de visibilidad en píxeles reales

Última base comprobada: **CI público #573, seis jobs verdes**, versión
v9.43. Esa validación demuestra funcionamiento del pipeline de pruebas,
**no** que los relieves anatómicos se vean suficientemente profesionales.

## Implementación

La nueva prueba móvil
`apps/app_mobile/test/features/exercises/anatomical_pixel_visibility_v944_visual_test.dart`
compara el renderizado real de **v9.41 y v9.42** por Flutter
`CustomPaint`. Captura sus píxeles RGBA (no solo datos del vértice)
para los tres ejercicios piloto en tres poses (0, 2 y 4 segundos),
dos temas y dos resoluciones físicas equivalentes a DPR 1x/2x.

Son **18 pares de escenas y 36 mediciones**. Cada medición registra:
- Píxeles del personaje/equipo frente al fondo.
- Píxeles modificados por la nueva malla y su porcentaje visible.
- Delta máximo y promedio de intensidad de canales de color.
- Cambios accidentales sobre fondo plano.
- Una etiqueta heurística (≥0,5% de píxeles de primer plano modificados).
  La etiqueta **no** es una certificación de belleza, legibilidad,
  biomecánica ni visibilidad por un humano real.

Se genera
`build/cc0_master_v7_flutter_qa/pixel_visibility_v944_report.json`
en el artefacto visual existente. Un verificador Python
`check_pixel_visibility_v944.py` comprueba cobertura completa,
consistencia numérica y conservación del estado de no aprobación;
`test_pixel_visibility_v944.py` incluye las pruebas unitarias para
verificar que las diferencias inexistentes no se convierten en
aprobaciones automáticas.

## Política de aceptación

**Si la comparación no muestra cambio apreciable, no se debe afirmar
que v9.42 mejoró perceptiblemente la apariencia**, incluso cuando
CI salga verde. Se necesitan revisar visualmente las capturas ya
generadas en v9.43, retopología real, subdivisión artística de
músculos, UV/PBR, iluminación, agarres y benchmark GPU físico.

Los JSON de evidencia siguen indicando **229 borradores,
0 aprobados y 0 habilitados**. Sin modificar `main`, web,
Supabase, historial o ejercicio IDs; sin activar assets en
`pubspec.yaml`. GitHub Actions únicamente en espejo público
`fernando15xvs/STK-Haven_CI`, PR #43; fuente privada
`fernando15xvs/STK-Haven`.
