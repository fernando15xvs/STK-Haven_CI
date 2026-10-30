# STK Haven — v9.42: anatomía superficial del tren superior (QA)

Se continúa del último CI verde v9.41 sin reiniciar el personaje ni los
movimientos. Se añade relieve **geométrico real** a los vértices de la
piel skinned en tres GLB experimentales derivados de v9.41.

## Cambios

- Se usa la pertenencia real a seis regiones ya existentes del atlas
  CC0: pectoral mayor, deltoides anterior y posterior, dorsal ancho,
  romboides y trapecio medio. Se mantienen los demás cinco grupos.
- El volumen del pectoral mayor recibe dos **guías artísticas** con
  perfiles altos (clavicular) y bajos (esternocostal); son variaciones
  volumétricas, **no** subdivisiones biomecánicas ni regiones de material
  distintas. No se añade todavía una máscara anatómica de deltoides lateral.
- Desplazamiento adicional máximo 1,20 mm, sombreado normal ≤9°,
  reducción automática si hay triángulos invertidos. Se editan solo
  `POSITION` y `NORMAL`, sin añadir nuevas partes móviles.
- 55 huesos, ocho morphs, doce regiones, skin weights, animaciones,
  barra, banco, materiales y nodos conservados. No se altera el catálogo.
- Generador `sculpt_upper_torso_v942.py`, pruebas reales
  `test_upper_torso_v942.py`, test Flutter y seis capturas 360 px
  (tres pilotos × modo claro/oscuro). El test evalúa también los ocho
  colores de la app.

## Evidencia y restricciones

El pipeline CI genera exclusivamente en
`build/.../lower_leg_v940/torso_v941/upper_v942/` tres
`*_v942_upper_torso_mobile_qa.glb` y
`upper_torso_v942_report.json` con hashes y QA.

Este cambio ofrece volumen ligeramente más diferenciado, pero **no**
convierte el modelo en un humano profesional: faltan retopología,
fibras/tendones, UV/PBR, deltoides lateral como máscara separada,
movimientos de hombro certificados y revisión de un artista anatómico.
La compilación automatizada tampoco demuestra render correcto,
rendimiento ni temperatura en teléfonos físicos.

**229 borradores / cero aprobados / cero habilitados.**
Solamente Flutter móvil iOS/Android. Nada en `apps/app_web`, Supabase,
historial, IDs, `pubspec.yaml`, `main` ni medios productivos. Fuente
principal `fernando15xvs/STK-Haven`; Actions únicamente en espejo
`fernando15xvs/STK-Haven_CI`; PR #43 sin fusionar.

Siguiente puerta: revisión de capturas de tres pilotos; capa profesional
de piel/retopología, contactos reales, GPU+equipamiento y pruebas en
dispositivos físicos.
