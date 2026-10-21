# STK Haven — master GLB v6: continuidad de malla articular

**Alcance:** solo revisión interna de Flutter móvil iOS/Android. No se habilitan los 229 borradores de animación ni se modifica la web, Supabase, la biblioteca o el historial de entrenamiento.

## Implementación

- Entrada: archivo GLB **v5.2** de 55 articulaciones, 7 patrones, 8 *shape keys* correctivos y 12 grupos de malla, con `approved=false` y `enabled=false`.
- El script `tool/anatomical_3d/build_master_surface_v6.py` crea un grafo de aristas cortas trianguladas y une vértices con posición coincidente de costuras UV.
- Suaviza de forma leve los **desplazamientos de los correctivos existentes** (hombro, codo, cadera, rodilla × izquierda/derecha), ponderando proximidad y mezcla de pesos óseos. No mueve posiciones base, no elimina triángulos y no cambia rig, animación, índices, normales ni pesos de piel.
- Limita cambios adicionales a **1,5 mm por vértice**, sin mezclar lados del cuerpo; solo 2 pasadas de suavizado. Sigue siendo una corrección visual experimental, no un modelo musculoesquelético anatómicamente certificado.
- Reescribe los 8 buffers morfológicos existentes, evita duplicaciones y rechaza salidas de más de 850 KiB, con gradiente de aristas peor de lo permitido o con metadatos inesperados. Las pruebas del GLB evalúan preservación y límites.

## Construcción offline en apps/app_mobile

```bash
python3 tool/anatomical_3d/build_master_surface_v6.py \
  --input build/cc0_master_contacts_v5/stk_master_v5_contact_review.glb \
  --output build/cc0_master_surface_v6
python3 -m unittest discover -s tool/anatomical_3d -p 'test_master_surface_v6.py'
```

Genera `stk_master_v6_joint_surface_review.glb` y `joint_surface_v6_report.json`. El GLB v6 no está incluido en los assets de Flutter, su renderer GPU aún no existe y faltan ejecución CI pública, inspección visual, rendimiento de dispositivos y revisión anatómica por especialistas. **0/229 animaciones aprobadas; 0/229 habilitadas.**
