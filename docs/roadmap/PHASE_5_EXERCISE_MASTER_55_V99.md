# STK Haven — Fase 5 v9.9: los tres pilotos pasan al rig master de 55 controles (QA)

**Estado:** nuevos archivos de prueba y controles de CI. No habilitados en Flutter, sin aprobación anatómica ni biomecánica.

## Problema previo

En v9.8 las tres demostraciones con barra (press de banca, remo y sentadilla) usaban el rig CC0 **original de 53 articulaciones**, mientras que el modelo master v7 con relieve muscular, **55 articulaciones**, 11 regiones y ocho correctivos geométricos tenía siete clips *genéricos* sin animación específica para estos ejercicios. No es correcto llamar al master de 55 huesos «piloto de press» si solo anima un alcance general.

## Implementación v9.9

`apps/app_mobile/tool/anatomical_3d/build_master_exercise_pilots_v99.py` convierte **tres archivos** de revisión `ex_bench_press`, `ex_barbell_row` y `ex_squat` desde los clips de 53 huesos y el master `stk_master_v7_surface_preview.glb`:

- Abre una **copia separada del master** por ejercicio, verifica procedencia CC0 con SHA de origen fijado, licencia/proveniencia y `approved:false/enabled:false`.
- Conserva sin alterar la malla master de doce grupos de superficie, las 55 matrices inversas de bind, los JOINTS_0/WEIGHTS_0 de CC0 y los ocho morph targets.
- Migra al rig master los canales de rotación/traslación reales del respectivo ejercicio (41 poses en cuatro segundos), identificando huesos por nombre en vez de confiar en índices entre los rigs distintos. La antigua jerarquía de 53 se reparentó sin mover el bind pose, por lo que en neutral los controles nuevos **no deben desplazar el agarre de manos ni el contacto de pies**.
- Reconstituye los ocho pesos animados de correctivos según las excursiones angulares de los huesos existentes mediante `build_master_contacts_v5.corrective_weights`. Los nuevos dos pivotes escapulares permanecen **neutrales** y se marcan `scapularMotionIKSolved:false`, porque animarlos sin recalcular el IK alteraría la posición de muñecas respecto a barra.
- Copia las mallas rígidas de barra/mangas/discos y banco (solo press de banca), remapeando índices de materiales/meshes y manteniendo el equipo separado de la piel skinned. Mantiene los músculos y colores semánticos del master de 55 huesos.
- Produce exclusivamente archivos bajo `apps/app_mobile/build/cc0_master_surface_v7/three_exercise_pilots_v99/` dentro del CI público, y un manifiesto con hashes del master y del ejercicio, recuentos de rig, máximos de los ocho pesos y bloqueos manuales. Es un **formato de autoría interna** (límite 1,4 MB), NO la anterior limitación de bundle móvil de 850 KiB y NO se incorpora a `pubspec.yaml`.
- Pruebas integradas en `test_cc0_interpolated_motion.py` reconstruyen la animación glTF de entrada y de salida con **121 muestras por ejercicio a 30 muestras/s**, comparan posiciones de pelvis, manos, pies, brazos y barra, y verifican que las manos conserven la distancia calculada a las zonas de agarre. También verifican 55 huesos, 12 regiones, ocho morph targets y protección contra archivos marcados prematuramente como aprobados.

## Comandos de reproducción (solo en entorno de CI con modelos originales ya generados)

```bash
cd apps/app_mobile
python3 tool/anatomical_3d/build_master_exercise_pilots_v99.py \
  --master build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb \
  --pilots build/cc0_53bone_retarget \
  --output build/cc0_master_surface_v7/three_exercise_pilots_v99
python3 -m unittest discover -s tool/anatomical_3d \
  -p 'test_cc0_interpolated_motion.py'
```

Los pasos ya existentes del CI público generan primero ambos insumos, luego ejecutan las pruebas; se evita tocar workflows privados. El artefacto público de revisión ya incluye la carpeta completa `build/cc0_master_surface_v7/`.

## Bloqueos que **v9.9 no resuelve**

1. **No es todavía un rig biomecánicamente perfeccionado.** Los 53 huesos originales conservan el mismo movimiento provisional; los controles escapulares adicionales permanecen estáticos. Requieren solución IK especializada con marcadores reales y corrección de deformación de hombros/antebrazos.
2. Las ocho deformaciones del master siguen siendo correctivos procedurales, **no músculos esculpidos profesionalmente** con inserciones, fascia y dinámica validada.
3. Los modelos de equipo son proxies de geometría reducida; se necesita detección de intersecciones superficie-superficie y control realista de apoyos de manos, banco y pies a lo largo de toda la repetición.
4. El visualizador nativo GLES3/Metal actual no reproduce todavía todos los nodos rígidos de equipo de estos tres candidatos junto a la malla skinned en el mismo GLB; producir un GLB correcto estructuralmente no garantiza un visor terminado.
5. No se han tomado métricas físicas de energía, memoria/FPS presentados, fotos, ni realizado revisión profesional en dispositivos. Todo permanece en **229/229 borradores, 0/229 aprobados y 0/229 habilitados**.

**Siguiente puerta:** confirmar CI y artefactos v9.9; después añadir correctores de escápula/cadera que preserven contacto, colisiones superficie-equipo y reproducción nativa multicapa para los tres pilotos. Solo expandir al resto del catálogo cuando esos tres cumplan revisión anatómica independiente y pruebas físicas de iOS/Android.
