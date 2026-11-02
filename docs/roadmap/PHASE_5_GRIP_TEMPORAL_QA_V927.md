# STK Haven — Fase 5 v9.27: auditoría de agarre temporal a 60 Hz

Estado: Implementación de laboratorio; pruebas y validación visual pendientes de los nuevos resultados CI.

Se comparan los tres GLB originales de v9.25 con sus versiones de agarre v9.26, a 60 Hz: 241 muestras por cada clip de 4 segundos, incluidas las 200 muestras que no coinciden con los 41 keyframes originales. La herramienta audit_grip_temporal_v927.py utiliza skinning real de 55 huesos, ocho morph targets, hasta 28 vértices por dedo y el cilindro finito de barra animado.

Para los diez dedos del piloto se registran las trayectorias de distancia firmada, las nuevas penetraciones observadas mayores de 2 mm, las regresiones de proximidad mayores de 0,5 mm, la separación respecto a la barra y, de forma diferenciada, regresiones detectadas entre keyframes. Cada ejercicio conserva su trazabilidad SHA256.

La auditoría solo admite el par exacto de origen v9.25 y candidato v9.26, con geometría idéntica, todos los canales originales y sin modificaciones ajenas a la rotación de dedos. No modifica ningún GLB: genera únicamente finger_bar_temporal_v927_report.json en la carpeta de evidencias CI de grip_v926/temporal_v927.

Una trayectoria sin regresiones a 60 Hz NO garantiza colisiones inexistentes entre muestras ni en el interior completo de los triángulos. No hay IK multiarticulación completa, anatomía profesional aprobada, físicas de presión o fricción, ni verificación en teléfonos físicos.

Siguiente puerta: decidir correcciones o rechazo de los cambios v9.26 según las regresiones detectadas. Después avanzar al solver de contacto continuo y al esculpido anatómico/UV/LOD con revisión biomecánica y mediciones iOS y Android físicas.

Repositorio de autoridad: privado fernando15xvs/STK-Haven. El único CI se ejecuta en fernando15xvs/STK-Haven_CI. Rama feat/mobile-lottie-batch1-drafts-20261018. PR público #43 abierto, sin merge a main ni cambios en web, Supabase, historial, catálogo ni pubspec. 229 borradores, 0 aprobados y 0 habilitados.
