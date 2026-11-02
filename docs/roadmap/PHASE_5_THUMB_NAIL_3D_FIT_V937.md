# STK Haven — Fase 5 v9.37, ajuste 3D de uñas de pulgares (QA)

La auditoría v9.34 constató separaciones de 12,22 mm y 14,95 mm
en uñas de pulgares, demasiado grandes para las correcciones
anteriores de 0,50 mm. El nuevo candidato toma las mallas LOD v9.36,
examina nueve puntos de la superficie inferior de cada uña y
localiza los triángulos reales de piel animada, con los 55 huesos
y ocho morph targets activos. Calcula un vector de traslación
**tridimensional** mediano en coordenadas locales del hueso.

Evalúa hasta cuatro escalas posibles (25, 50, 75, 100 %) sobre
nueve fotogramas y hace una revisión final de 241 poses a 60 Hz
en cada pulgar. Se acepta solo si reduce las muestras de posible
penetración orientada o la separación superior a 6 mm sin
incrementar la otra ni empeorar la distancia máxima más de
0,65 mm. Se limita a **12 mm** de traslación de la uña QA.
Si no mejora, conserva el nodo original. Los demás dedos,
la geometría, las UV, los materiales, las pistas y el rig no
se modifican.

El informe thumb_nail_fit_v937_report.json registra candidatos
aceptados y rechazados, desplazamientos y pruebas por pulgar.

**ATENCIÓN:** usar normales de triángulos de piel abierta
no certifica que una uña quede fuera del volumen del dedo.
Una aproximación a 60 Hz no identifica todo contacto entre
muestras ni sustituye modelado anatómico profesional.
Ningún recurso se aprueba o habilita por este procedimiento.

Salida QA exclusiva: build/.../nail_plates_v933/offset_v935/
lod_v936/thumb_fit_v937. Se añaden pruebas Python y Flutter
de los tres GLBs con luz/oscuridad y ocho acentos.

Repo fuente privado fernando15xvs/STK-Haven, CI únicamente
en fernando15xvs/STK-Haven_CI; rama
feat/mobile-lottie-batch1-drafts-20261018 y PR #43 abierto
sin fusionar. No tocar web, Supabase, pubspec, catálogo,
historial ni activos productivos. 229 borradores, cero aprobados.
