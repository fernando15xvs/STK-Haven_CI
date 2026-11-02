# STK Haven — Fase 5 v9.21: auditoría de triángulos dedo–barra (QA)

**Estado:** implementación experimental de diagnóstico y evidencia visual, no corrección biomecánica certificada. Solo Flutter iOS/Android; fuente privada fernando15xvs/STK-Haven, espejo público fernando15xvs/STK-Haven_CI para Actions. Rama feat/mobile-lottie-batch1-drafts-20261018, PR público #43 sin fusionar.

## Problema

v9.19 evaluaba vértices ligados a falanges distales y v9.20 generaba un relieve conservador de hasta 0,75 mm. Sin embargo, un triángulo puede atravesar la barra entre sus vértices; asimismo, hay que respetar la rotación de la barra. El resultado es solo diagnóstico, **no es un agarre resuelto**.

## Implementación

Nuevo script apps/app_mobile/tool/anatomical_3d/audit_finger_triangles_v921.py:

1. Acepta exclusivamente tres GLB móviles originales v9.18 y los tres candidatos v9.20 de press banca, remo y sentadilla; exige procedencia CC0 fijada, 55 huesos, 8 morphs, 4.727 vértices, 9.843 triángulos, 12 primitivas, aprobado=false y habilitado=false.
2. Lee los triángulos indexados reales y agrupa las caras adyacentes a los vértices ponderados de las diez falanges distales. Son regiones proximales aproximadas, no un atlas anatómico aprobado.
3. Para 121 posiciones a 30 Hz aplica la animación glTF, las ocho deformaciones morph y el skinning del rig real; transforma los vértices a coordenadas locales de la barra usando el inverso de su cuaternión animado.
4. Sobre cada triángulo deformado evalúa siete puntos: tres vértices, tres puntos medios de aristas y centroide. Calcula distancias firmadas al cilindro finito de la barra (radio 19 mm). Reporta cercanía por debajo de 10 mm, posibles interpenetraciones superiores a 2 mm y brechas por dedo.
5. Compara v9.18 frente a v9.20 sin exigir mejoras artificiales. Emite exclusivamente JSON en la carpeta de QA hand_v920/triangle_v921, bajo el artefacto stk-haven-visual-pilots del CI público.
6. Pruebas Python sintéticas y sobre GLB reales detectan cruces de triángulo que un muestreo de vértices no vería, reproducen rotación de barra y rechazan GLB aprobados o fuentes fuera de versión. Flutter test genera seis capturas reales y comprueba ambos temas, los ocho colores y el equipamiento rígido.

## Límites y seguridad

**No** es detección exacta de intersección triángulo-cilindro ni prueba continua temporal. Siete muestras pueden omitir contactos entre puntos o fotogramas, y el cilindro es un proxy sin collarines, fricción ni presión. Las regiones seleccionadas no son la anatomía exacta de la piel de las yemas. Puede detectar intersecciones que requieren corrección, pero no aprueba biomecánica ni calidad artística.

Tampoco modela una nueva mano, no retopologiza palma/dedos y no resuelve IK por yema o colisiones. No se activan recursos en la app ni se toca pubspec.yaml. **229 borradores / 0 aprobados / 0 habilitados.**

## Siguientes puertas

- Revisar brechas por dedo y las seis capturas de Flutter; identificar fotogramas problemáticos; revisión especializada de agarres y movimientos.
- Modelar y retopologizar **realmente** la mano en alta resolución con palma, articulaciones, uñas y proporciones anatómicas; rig, UV y LOD móvil consistente.
- Incorporar solver de contactos de dedos/palma con la barra y comprobación continua de geometría superficie-objeto, evitando colisiones y corrigiendo poses sin alterar los contactos de pies ni las deformaciones morfológicas.
- Verificar en iPhone y Android físicos, con FPS presentados, memoria, jank, térmicas y batería; solo luego aprobar los tres pilotos y expandir las 226 variantes.

Reglas invariantes: no modificar apps/app_web, Supabase, historial, main, IDs, recursos de producción ni pubspec; GitHub Actions exclusivamente en STK-Haven_CI. No GIF.
