# STK Haven — Fase 1 / Bloque 4: proporciones fitness naturales (v10.4)

**Estado: nueva malla 3D generada y probada localmente; revisión artística pendiente.**
Partimos del master independiente v10.3, nunca de un personaje de producción.

## Corrección visual tras la revisión

El v10.3 presenta hombros muy redondos, pecho sobresaliente,
muslos enormes, pantorrillas abultadas, glúteos proyectados y
surcos abdominales duros. Para alcanzar un físico musculoso **pero
estético y humano**, v10.4:

- Ajusta bilateralmente las proporciones de pecho, cabeza/cuello,
  trapecios, deltoides, brazos, muñecas, pelvis, glúteos,
  cuádriceps, isquios, rodillas, gemelos, tibial, tobillos y pies.
- Reduce el relieve de los surcos de la malla frontal al **36 %**
  y de los surcos del brazo al **32 %** de sus intensidades originales.
- Fusiona transiciones musculares usando blend de tejidos y
  un filtrado de campo para disminuir la apariencia de armadura.
- Mantiene 106 volúmenes maestros bilaterales, malla única
  cerrada, coordenadas físicas en metros y materiales neutros PBR.

## Validación y entrega

Ejecutar en `apps/app_mobile/tool/anatomical_3d/master_v10`:

```bash
python -m pip install -r requirements-authoring.txt
python -m unittest test_aesthetic_lower_body_v104.py -v
python sculpt_aesthetic_lower_body_v104.py --output build/master-v104-review --pitch .012
```

En la revisión local (pitch 0,012 m), la geometría pasó 4/4
pruebas, contiene **67.580 triángulos**, es watertight y sigue
siendo una sola pieza. La masa volumétrica pasó de 0,22603 m³
a 0,20076 m³ (**-11,18 %**), un cambio evidente de silueta y no
un microdesplazamiento de milímetros. Este indicador por sí solo
no certifica belleza ni exactitud biomecánica.

Renderizar con la herramienta de autoría existente:

```bash
python -m pip install -r requirements-render.txt
python render_master_v10.py \
  --glb build/master-v104-review/stk_master_v104_aesthetic_lower_body_unapproved.glb \
  --output build/master-v104-review/renders
```

El nuevo archivo `stk_master_v104_aesthetic_lower_body_unapproved.glb`
**no debe registrarse en Flutter ni sustituir assets de ejercicios**.

## Lo que NO está aprobado

El nuevo personaje es menos voluminoso pero **aún se ve
procedural**: cabeza sin rostro acabado, manos y dedos provisionales,
anatomía de hombro, cadera, pies y abdominales por perfeccionar.
Faltan retoque artístico de alta calidad, retopología para rig,
UV/materiales, skinning, animaciones, aprobación visual humana y
pruebas en teléfonos físicos. **0/229 ejercicios aprobados y habilitados**.

Solo `apps/app_mobile`, documentación y **CI en repositorio público**.
Ramas `feat/mobile-lottie-batch1-drafts-20261018` en ambos
repositorios. Fuente de verdad privada STK-Haven. PR público #43
permanece abierto; no tocar main, web, Supabase ni historial.
