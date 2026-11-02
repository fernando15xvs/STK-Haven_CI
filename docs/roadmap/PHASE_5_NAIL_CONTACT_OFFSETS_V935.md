# STK Haven — Fase 5 v9.35, corrección conservadora de uñas

La versión v9.34 detecta contactos sospechosos entre las 10 uñas
tridimensionales y la piel skinned/morphed de los dedos en 241 poses.
La v9.35 propone pequeñas traslaciones de las uñas existentes
(±0,25 y ±0,50 mm) respecto a la normal dorsal local de la placa.

El buscador evalúa nueve fotogramas representativos sobre los
triángulos auténticos del GLB, no proxies. Solo considera candidatos
que disminuyen alguna incidencia de penetración sospechosa o separación
mayor de 6 mm sin aumentar la otra. **Antes de conservar nada**,
la v9.34 vuelve a inspeccionar las 241 poses con los ocho morphs
auténticos, clips reales y búsqueda del punto más cercano al triángulo.

Un candidato solo se conserva si no empeora ninguna categoría
y reduce al menos una incidencia por dedo desplazado. Si cualquier
dedo falla, se deshacen TODOS los cambios del piloto. Si no hay
una mejora suficientemente demostrable, el resultado conserva
exactamente las posiciones v9.33 de las diez uñas.

No se modifican rig, motion tracks, malla humana, pesos,
UV0, normales, materiales, estructura de nodos o geometría
del equipo; se parchean solo los VEC3 POSITION originales
de hasta diez uñas con un límite de 0,50 mm por placa.

La salida es experimental, únicamente en
build/.../nail_plates_v933/offset_v935.
Informe nail_offsets_v935_report.json contiene offsets propuestos,
retenidos, datos de 60 Hz y reversiones. No se habilitan assets.

Las normales dorsales todavía son aproximaciones no verificadas
por artistas. El signo de la normal de una piel abierta NO
certifica interior/exterior, 60 Hz no comprueba colisiones entre
fotogramas y nueve puntos por uña no describen todos los
triángulos de una superficie. Faltan autocolisión 3D,
contacto IK físico, material/cutícula profesional y dispositivos
iPhone/Android. Nunca publicar ni aprobar automáticamente.

Repositorio privado fernando15xvs/STK-Haven, espejo público CI
fernando15xvs/STK-Haven_CI, rama
feat/mobile-lottie-batch1-drafts-20261018, PR #43 abierto.
No modificar web, Supabase, catálogo, pubspec, historial ni
activos productivos. 229 ejercicios en borrador, 0 aprobados.
