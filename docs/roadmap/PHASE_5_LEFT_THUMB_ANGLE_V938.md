# STK Haven v9.38 — Pulgar izquierdo: búsqueda de giro y traslación segura

La v9.37 conservó tres correcciones del pulgar derecho. El izquierdo
no superó las condiciones de contacto: en press de banca una mejora
del número de separaciones incrementaba las posibles penetraciones.
v9.38 busca además inclinaciones de ±6, ±12 y ±18 grados alrededor
del centro de la placa, con traslación longitudinal/lateral y relieve
dorsal adicional de hasta 1,2 mm. La forma se mueve mediante el nodo
real de la falange, no mediante imágenes ni texturas.

Cada candidato se compara contra triángulos morphed/skinned del rig
auténtico de 55 huesos (9 fotogramas preliminares y 241 de control a
60 Hz para los mejores). Se conservan únicamente candidatos que reducen
las incidencias de riesgo sin aumentar las de otra categoría.
El desplazamiento de cualquier vértice queda limitado a 12 mm.
Si ninguno mejora de forma verificable, se mantiene la placa original.

Los tres GLB v9.37 y sus v9.36 originales son entradas obligatorias,
y se revisa criptográficamente su procedencia. Quedan sin cambios la
corrección ya aprobada como experimento en el pulgar derecho, las
otras ocho uñas, todas las UV, mallas, huesos, morphs y clips.

Genera tres GLB y el informe left_thumb_angle_v938_report.json en la
ruta QA thumb_fit_v937/left_thumb_angle_v938, con pruebas Python
y capturas Flutter (claro, oscuro, ocho acentos). No se habilita nada.

NO implica colisión continua, acabado anatómico artístico ni
benchmarking de teléfonos. Seguirán pendientes cutículas, piel,
materiales y calidad 3D profesional de los 229 ejercicios.

Privado fernando15xvs/STK-Haven = fuente principal; público
fernando15xvs/STK-Haven_CI = solo CI. PR #43 abierto. No tocar
web, Supabase, pubspec, historia, catálogo ni activos productivos.
