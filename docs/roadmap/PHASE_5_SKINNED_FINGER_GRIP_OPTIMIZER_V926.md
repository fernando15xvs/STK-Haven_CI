# STK Haven — Fase 5 v9.26: ajuste conservador del agarre

Estado: experimental, no aprobado ni publicado. Fuente principal privada y
GitHub Actions exclusivamente en el espejo público.

El nuevo módulo optimize_finger_grip_v926.py evalúa la superficie deformada
de diez dedos del humano de 55 articulaciones y ocho morph targets. Usa los
pesos verdaderos de la falange distal para elegir hasta 28 vértices por dedo.
En 1, 2 y 3 segundos del clip de cuatro segundos prueba correcciones
de ±1,5° y ±3° sobre las tres falanges de cada dedo (12 opciones por dedo).
Solo acepta una corrección por dedo si el error de proximidad del cilindro
mejora y la penetración medida no empeora más de 0,5 mm en ninguna pose.

Los cambios se realizan exclusivamente sobre los accesores de rotación de
las pistas ya existentes, conservando las 30 pistas originales, la malla
v9.25, pesos, bind, morphs, barra, banco, esquemas de glTF, 55 huesos y
animaciones no afectadas. La envolvente seno-cuadrado asegura bucle limpio.
Los límites adicionales son 3 grados por articulación y aproximadamente
12 grados respecto al reposo, con control de velocidad por fotograma.

Entrega 3 GLB y un JSON de decisiones en la carpeta build de
web_v925/grip_v926, además de pruebas Python y capturas Flutter QA para
modo claro, oscuro y ocho acentos. Las correcciones rechazadas quedan
sin aplicar; el informe comunica el número realmente aceptado.

Esto NO es IK completa con targets físicos, ni una garantía de contacto:
solo se muestrean vértices en tres instantes, no interiores de triángulos
ni el tiempo continuo. No se estudia presión, fricción, ROM anatómico
específico, autocolisión o calidad profesional de las manos. Sigue pendiente
el artista 3D, la validación biomecánica y pruebas físicas de iOS/Android.

Repositorio privado fernando15xvs/STK-Haven = autoridad.
Repositorio público fernando15xvs/STK-Haven_CI = único CI.
Rama feat/mobile-lottie-batch1-drafts-20261018. PR #43 abierto.
Sin web, Supabase, historial, pubspec, catálogo ni assets productivos.
229 drafts; cero aprobados; cero habilitados.
