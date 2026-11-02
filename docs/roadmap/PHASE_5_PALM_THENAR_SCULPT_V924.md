# STK Haven — Fase 5 v9.24: volumen anatómico de palma y eminencia tenar (QA)

**Estado:** implementación experimental para revisar; sin calificación profesional ni aprobación visual. Fuente de verdad privada, CI y artefactos solo en el espejo público. Rama `feat/mobile-lottie-batch1-drafts-20261018`; PR público #43 permanece abierto.

## Avance sobre v9.23

La v9.22 subdividió conformemente el área de yemas, pero no hizo una reconstrucción completa de la palma. La v9.23 examinó contacto dedo–barra en poses discretas sin alterar geometría. La **v9.24 crea una nueva malla derivada con desplazamiento real de la superficie de palma y raíz del pulgar**, trabajando sobre los triángulos y skinning glTF existentes. No simula la modificación mediante sobreimpresiones.

Módulo: `apps/app_mobile/tool/anatomical_3d/sculpt_palm_thenar_v924.py`.

- Calcula bases anatómicas locales desde los huesos reales `hand`, `index_01`, `middle_01`, `pinky_01`, `thumb_01/02`, en ambas manos, evitando un eje fijo arbitrario en el espacio global.
- Usa pesos de piel de esos huesos para distribuir una bóveda palmar bilateral, volumen de eminencia tenar alrededor de la base del pulgar y una transición en el borde cubital. Desplazamiento máximo **3,5 mm**, con reescalado automático si aparecen caras invertidas.
- **Cambia las posiciones reales de vértices y sus normales**, conserva la misma conectividad, todos los triángulos, las 12 regiones, 55 huesos, skin weights, matrices bind, ocho morphs, animaciones y geometría de barra y banco. Los vértices de mayor influencia distal no se mueven.
- Recalcula las normales solo sobre el parche afectado y su vecindario. Comprueba exportación y presupuesto de 1.400 KiB por archivo de revisión.
- Produce tres GLB `*_v924_palm_thumb_surface_mobile_qa.glb` y `palm_thenar_surface_v924_report.json` con recuentos por mano, desplazamiento y hashes, únicamente en `build/`.
- Pruebas Python comparan entradas/salidas y bloquean fuentes aprobadas y doble esculpido; revisión de Flutter en modo claro/oscuro y acentos se mantiene exclusivamente en QA interno.

## Lo que NO está terminado

**No es una mano profesionalmente esculpida**. No se ha creado nueva topología de palma completa, uñas, articulaciones anatómicas ni UV finales, ni se ha corregido el movimiento de 30 controles de dedos contra la barra. Los límites en milímetros son topes conservadores de un candidato sobre CC0, no dimensiones clínicas. Los controles de proximidad v9.23 no demuestran contacto físico continuo. Falta inspeccionar las capturas y una revisión experta sobre proporciones, piel y técnica.

### Próxima puerta

Analizar el informe de cambios de ambas manos, comparar imágenes de Flutter y las mediciones de contacto de v9.23; después crear geometría de alta resolución de palma/pulgar con autoría artística verificable, transferir UV/skin/LOD, y resolver agarre con targets de contacto dedo–barra y colisión continua. La aceptación requiere revisión especializada y medición en teléfonos físicos.

**Invariantes:** 229 ejercicios draft, **0 approved / 0 enabled**. Sin cambios en producción, `main`, `apps/app_web`, Supabase, entrenamiento histórico, `pubspec.yaml`, notificaciones ni workflows privados.
