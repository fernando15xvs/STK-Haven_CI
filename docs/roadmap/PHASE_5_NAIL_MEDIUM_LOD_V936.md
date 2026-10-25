# STK Haven — fase 5 v9.36: LOD medio real para uñas móviles

La auditoría del CI #554 confirmó 7 desplazamientos mejorados y
conservados (4 press banca, 3 remo). En sentadilla los 3 propuestos
se revirtieron sin modificar la geometría, conforme al filtro
fail-closed. v9.34 también identificó posibles desprendimientos
de más de 6 mm especialmente en ambos pulgares. No se pueden
considerar uñas profesionalmente terminadas ni libres de colisión.

v9.36 crea, **solo para QA**, un LOD reducido para las 10 uñas
3D vinculadas al rig de los 3 ejercicios piloto. Cada placa pasa de
70 a 30 vértices y de 136 a 56 triángulos; los diez dedos pasan de
1360 a 560 triángulos, reducción del 58,82% de la geometría de uñas.
Se conserva el UV0 por muestreo del original, las dos superficies,
las paredes cerradas, el material PBR de prueba (rugosidad
ajustada a 0,46), la vinculación real con las falanges y
todo el rig (55 huesos), las 8 morph targets y pistas de dedos.

Se verifica cada uno de los 70 vértices de alta resolución contra
los triángulos reales del LOD generado, con un límite de distancia
inferior o igual a 0,55 mm. Esta medición NO es Hausdorff completo
ni prueba colisiones contra la piel de cada pose animada.
Los GLB de alta resolución v9.35 permanecen intactos y sirven de
base para la auditoría de contacto de riesgo.

Los archivos QA solo se generan en
build/.../nail_plates_v933/offset_v935/lod_v936,
conforme a un reporte JSON para los 3 pilotos. Se añaden pruebas
de exportación, UV, rig, equivalencia corporal, rechazo de modelos
aprobados y seis capturas Flutter (claro, oscuro y 8 acentos).

NO se ha medido consumo real de GPU, frame pacing ni rendimiento
de dispositivos. El archivo GLB puede crecer debido a la retención
de streams históricos mientras disminuye la geometría renderizada.
No hay cutículas profesionales, ni materiales definitivos, ni
detección de colisiones continuas, ni contacto IK completo.

Repositorio autoritativo privado fernando15xvs/STK-Haven,
espejo fernando15xvs/STK-Haven_CI solo CI; rama
feat/mobile-lottie-batch1-drafts-20261018 y PR #43 abierto.
No modificar web, Supabase, activos productivos, pubspec o historial;
229 ejercicios siguen en borrador y cero aprobados/habilitados.
