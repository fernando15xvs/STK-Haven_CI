# STK Haven Fase 5, bloque v9.32 — superficie de lecho ungueal

**Candidato QA; no apto todavía para producción.**

Nueva herramienta de esculpido de la superficie original GLB:
apps/app_mobile/tool/anatomical_3d/sculpt_nail_beds_v932.py.

La operación identifica la falange distal real (03) de cada dedo,
su eje y la normal del plano de mano del rig. Produce un relieve
muy pequeño de hasta **0,30 mm** sobre los vértices de piel con
pesos de skin relevantes, sin objetos superpuestos ni texturas falsas.

La orientación dorsal *se aproxima mediante el rig* y NO se ha
confirmado contra referencias de artista anatómico. Esta iteración
tampoco construye placas ungueales independientes, cutículas,
uñas pintadas, nuevas islas UV, material queratinoso ni detalle
fotorealista. Si la geometría fuente no ofrece una superficie
suficiente, queda sin cambios de vértices y se registra un fallback.

Se impide inversión de triángulos y cambio de estructura en el
GLB (12 regiones, rig de 55 huesos, morphs, animación, materiales
y equipamiento). Cuando se acepta un relieve, se comprueba la
distancia de los dedos y la barra en 241 posiciones a 60 Hz
con skinning y ocho morphs reales. Si existe nueva penetración
profunda o regresión geométrica mayor que 0,65 mm, se conserva
el GLB v9.31, sin modificar las posiciones de piel. Se recalculan
normales del área afectada cuando sí se acepta.

Se generan tres GLB y nail_bed_v932_report.json exclusivamente
en build/.../knuckle_v930/fold_v931/nail_bed_v932.
Se añaden pruebas Python para los tres pilotos y revisión
Flutter del modo claro y oscuro con ocho colores y capturas
PNG. Ningún archivo se registra en el catálogo productivo.

Faltan: placas de uñas reales, UV/materiales, retopología
anatómica profesional de toda la mano, IK de contacto completa,
detección continua de colisiones y benchmarking en teléfonos
iOS/Android. No se afirma que los 229 ejercicios sean activos:
229 siguen en borrador, 0 aprobados/habilitados.

Repositorio privado fernando15xvs/STK-Haven = autoridad;
fernando15xvs/STK-Haven_CI = exclusivamente CI; rama
feat/mobile-lottie-batch1-drafts-20261018, PR público #43
abierto sin fusionar. No se modifica app_web, Supabase,
historial, pubspec ni activos productivos.
