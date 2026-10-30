# STK Haven — Fase 5 v9.23: auditoría geométrica de contacto de dedos

**Estado:** implementado como inspección Python de laboratorio; pendiente de validación completa de CI y revisión física. Solo iOS/Android; sin modificación de Flutter de producción.

## Objetivo y alcance

La v9.22 añadió vértices y triángulos conformes sobre las yemas de la malla real. El siguiente bloqueo es el contacto de esa superficie con la barra. La v9.21 medía solo siete puntos por triángulo: podía omitir contactos entre muestras. Esta fase añade una cota geométrica conservadora sobre los **triángulos reales, deformados por el rig y los ocho morph targets** del candidato v9.22.

Nuevo módulo Python: apps/app_mobile/tool/anatomical_3d/audit_finger_contact_bounds_v923.py.

- Solo acepta los tres GLB originales v9.22, con 55 articulaciones, ocho morphs, doce primitivas de atlas, fuente CC0 fijada y ambas banderas approved/enabled en falso.
- Lee las caras reales y las influencias distales de los diez dedos. Aplica la animación glTF con skinning, morphs y orientación real de la barra.
- Para cada triángulo usa una **cota inferior** de distancia firmada al cilindro: distancia del centroide menos el radio de cobertura centroide-vértices (propiedad 1-Lipschitz del SDF). Refina solo casos ambiguos en hasta dos niveles de subdivisión.
- Distingue **penetración observada**, **separación demostrable a esa pose** o **contacto no resuelto**. La zona incierta nunca se considera libre de colisiones.
- Toma **nueve poses, cada 0,5 segundos**, del clip de cuatro segundos. No son 121 cuadros ni una prueba de colisión continua en el tiempo.
- Emite JSON por ejercicio y dedo, incluidas cantidades de triángulos, evaluaciones y conteo de cada estado, bajo la carpeta de evidencias del CI público. No altera ni publica ningún GLB.
- Se añaden tests sintéticos de cota inferior y penetración, y tests con los tres archivos reales v9.22 para asegurar formato, procedencia, seguridad y evidencia.

## Límites y próximas puertas

Esta fase **no crea una nueva mano anatómica ni resuelve finger IK**. La selección de triángulos por pesos distales es aproximada; el cilindro no modela fricción, presión de dedos ni partes exteriores del implemento. Una cota positiva demuestra separación solo para el triángulo planar en la pose examinada, no ausencia de colisiones entre poses, de autocolisiones o técnica biomecánica correcta.

Próximas tareas: examinar el JSON y capturas con cada dedo; reconstruir malla anatómica profesional de palma, pulgar, pliegues, uñas y proporciones; ajustar 30 articulaciones de dedos con objetivos reales de superficie; detección más continua de contacto; validar con especialista y iPhone/Android físicos.

**Invariantes:** privado STK-Haven = fuente principal; STK-Haven_CI = único repositorio con Actions. Rama feat/mobile-lottie-batch1-drafts-20261018 y PR público #43, sin merge ni despliegue. Sin cambios en apps/app_web, Supabase, historial, IDs, pubspec, catálogo o tema. Siguen **229 drafts / 0 approved / 0 enabled**.
