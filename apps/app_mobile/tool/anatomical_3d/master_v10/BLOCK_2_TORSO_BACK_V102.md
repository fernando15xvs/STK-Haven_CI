# STK Haven — Fase 1, bloque 2: pecho, abdomen y espalda (Master v10.2)

**Entregado:** nuevo GLB *estático* del maestro v10, no una modificación del modelo v9 ni una animación aprobada. El v10 original permanece congelado para comparación.

## Cambios que afectan la malla real

- Reesculpidos **20 volúmenes bilaterales** del nuevo master en 10 grupos: pectoral mayor, porción clavicular, romboides, trapecio superior, dorsal ancho, tres segmentos abdominales, oblicuo y serrato.
- **35 canales geométricos** con límites de profundidad y anchura: separación esternal/pectoral, pliegue inferior, unión deltopectoral, linea alba, tendones abdominales, oblicuos, serratos, escápulas, trapecio, borde de dorsales y surco torácico.
- SDF de unión en vóxeles y marching cubes con normales coherentes, material neutro PBR y **topología cerrada**; sin pintura de falsas líneas musculares.
- QA local con pitch de **9 mm**: **68 936 vértices**, **137 868 triángulos**, volumen **0,231261 m³**, GLB estático no aprobado. La resolución CI utiliza pitch de 12 mm y tests a 18 mm, de modo que los números de triángulos difieren de la prueba local.
- Comparación real renderizada con la **misma cámara e iluminación** contra la base v10: porcentaje de píxeles con diferencia RGB máxima > 12 de 255: frente **4,91 %**, espalda **4,24 %**, perfil **1,58 %** y 3/4 **4,67 %** (resolución 700×850). Son diferencias medibles, **no** puntuaciones de belleza ni anatómicas.

## Reproducción

```bash
cd apps/app_mobile/tool/anatomical_3d/master_v10
pip install -r requirements-authoring.txt
python -m unittest test_torso_back_v102.py -v
python sculpt_torso_back_v102.py --output build/master-v102-review --pitch .009
pip install -r requirements-render.txt
python render_master_v10.py --glb build/master-v102-review/stk_master_v102_torso_back_unapproved.glb --output build/master-v102-review/renders
```

Entrega de QA: `stk_master_v102_torso_back_unapproved.glb`, `stk_master_v102_torso_back_report.json`, vistas frontal, espalda, lateral y tres cuartos. *No* se empaquetan en el catálogo ni en `pubspec.yaml`. El workflow de GitHub Actions existe exclusivamente en el repositorio público `STK-Haven_CI`.

## Límites artísticos y siguientes correcciones

Los nuevos pliegues pueden verse aún demasiado marcados; cabeza, manos, cintura y glúteos no están terminados y las proporciones generales requieren revisión artística. Por tanto, este **no es un personaje anatómico profesional listo para producción**: falta escultura/retopología manual, UV, materiales, rig, deformación, agarres, rendimiento móvil y visto bueno humano.

Sin cambios en web, Supabase, historial, IDs del catálogo, `main` ni app publicada. **229 ejercicios / 0 aprobados / 0 habilitados**. El PR #43 sigue abierto.
