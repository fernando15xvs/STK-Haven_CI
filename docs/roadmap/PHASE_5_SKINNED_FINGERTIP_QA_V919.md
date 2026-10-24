# STK Haven — Fase v9.19: auditoría de superficie real de los dedos y la barra

**Alcance:** únicamente GLB de revisión para Flutter iOS y Android. El personaje final sigue sin aprobación anatómica ni publicación. Código privado `fernando15xvs/STK-Haven`, CI y espejo público `fernando15xvs/STK-Haven_CI`, rama `feat/mobile-lottie-batch1-drafts-20261018`. No se modifica web, main, Supabase, historial ni los 229 ejercicios.

## Problema identificado

La fase v9.17 animó las 30 falanges y v9.18 comenzó a corregir la orientación de muñeca. Sin embargo, la métrica anterior medía **el origen de la articulación distal**, no la superficie deformada de la piel; un dedo puede aparentar acercarse a la barra aun cuando la geometría visual quede separada o atravesada por ella.

## Implementación

Se agrega `review_fingertip_mesh_v919.py`, un evaluador **sin efectos sobre producción** que abre los GLB móviles de los tres ejercicios en sus versiones v9.17 y v9.18. Para cada una de las dos manos y los cinco dedos identifica los vértices reales de malla que reciben peso de skinning de la **tercera falange**. Se requiere una población mínima de seis vértices por dedo, y se seleccionan como máximo 36 por región, sin inventar puntos de piel.

Se muestrean **121 cuadros a 30 FPS por modelo**, aplicando la jerarquía real de **55 articulaciones**, los ocho correctivos morph originales, matrices inversas de bind y skin weights de glTF. Cada punto transformado se compara con el cilindro longitudinal de la barra (radio 19 mm). Para cada dedo se reportan:
- Distancia positiva media del vértice más próximo.
- Máxima separación positiva del vértice más próximo.
- Distancia firmada mínima (indicio de posible penetración).
- Número de cuadros con superficie muestreada a menos de 10 mm del cilindro.
- Cuadros con posible penetración de la malla superior a 2 mm.
- Variación de la distancia media al comparar v9.17 y v9.18.

El análisis produce `fingertip_skin_contact_v919_report.json` dentro de la carpeta experimental `contact_v918/skin_v919/`. No genera GLB nuevos porque **no es honesto afirmar que una malla de dedos con proporciones provisionales pueda corregirse anatómicamente solo extendiendo vértices hacia la barra**. El reporte revela cuáles son las falanges y posturas que aún necesitan ajuste del rig y retopología.

`test_cc0_interpolated_motion.py` añade tests sobre los **GLB reales**, sin simulaciones inventadas; comprueba presencia de diez regiones de dedos, uso completo de 121 cuadros, ausencia de datos no finitos, procedencia e integridad de seguridad, y preserva la prohibición de aprobar o habilitar los archivos.

## Límites importantes

El algoritmo es **muestreo discreto** sobre vértices asociados a la falange, no una prueba de intersección triángulo-cilindro continua, contacto piel-fricción, agarre humano, biomecánica clínica ni ausencia de penetración en todos los puntos de superficie. Tampoco incluye los collares de agarre de 22 mm ni un modelo completo de compresión de palma/yemas. Las falanges existentes tienen pocas decenas de vértices por segmento: el personaje exige una verdadera malla artística de mano con yemas y uñas proporcionadas, más una fase de IK/contacto por dedos.

El siguiente paso real es utilizar las brechas medidas para diseñar/retopologizar una **nueva superficie anatómica de manos** y ajustar un solver basado en los dedos reales, manteniendo rig, rendimiento y animaciones. Hacen falta revisión profesional y captura en iPhone y Android físicos antes de activar nada.

**Estado:** 229 borradores, 0/229 aprobados, 0/229 habilitados. Los pilotos no se integran en web ni en producción.
