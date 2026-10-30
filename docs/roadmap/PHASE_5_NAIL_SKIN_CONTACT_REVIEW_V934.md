# STK Haven — Fase 5 v9.34: auditoría uñas-piel a 60 Hz

La versión v9.33 añadió 10 uñas cerradas 3D con UV y animación real
por piloto. La v9.34 NO altera ningún GLB y añade una comprobación
sobre las propias superficies del modelo y de los dedos deformados.

Para cada una de las 241 posiciones a 60 Hz (0 a 4 segundos),
calcula skinning/morphs de vértices reales y consulta 48
triángulos distales cercanos como máximo por dedo. Compara
nueve posiciones del reverso de cada uña con su triángulo de
piel más próximo, mediante punto más cercano a triángulo (no
solo distancia a vértices o esferas proxy). Genera estadísticas
de aproximación, posible penetración orientada de 0,5 mm y
posible separación de más de 6 mm. Registra la primera pose
problemática por dedo. Todo el resultado se conserva en
nail_plate_skin_proximity_v934_report.json.

El signo de la normal NO demuestra que una uña esté dentro
de una superficie anatómica abierta: son detecciones
**sospechosas**, no clasificación topológica robusta. Al
muestrear nueve puntos por placa y fotogramas a 60 Hz,
pueden escapar intersecciones de aristas, penetraciones entre
muestras y otras colisiones. Por eso ningún resultado puede
aprobar ni habilitar automáticamente el contenido.

Se prueban los tres GLB (press banca, remo y sentadilla),
30 uñas, 65 070 probes en conjunto, campos numéricos,
consistencia de malla, origen, prohibición de activos aprobados
y no certificación. Fuente privada STK-Haven, espejo
STK-Haven_CI solo para CI; rama
feat/mobile-lottie-batch1-drafts-20261018, PR #43 abierto.

Sigue pendiente: revisión artística del dorsal de uñas,
materiales físicos mejores, cutícula anatómica, LOD de GPU,
colisiones continuas completas, IK, benchmarking físico y
revisión humana. Ningún cambio en app_web, Supabase,
catálogo de producción o assets. 229 drafts, cero aprobados.
