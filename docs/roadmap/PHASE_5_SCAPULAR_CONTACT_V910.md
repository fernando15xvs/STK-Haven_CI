# STK Haven — Fase 5 v9.10: movimiento escapular limitado y agarre conservado

**Alcance:** laboratorio de los tres modelos de ejercicio sobre el master CC0 de 55 articulaciones, creado durante v9.9. No se habilita contenido del catálogo, no se toca web, historial, Supabase ni `main`.

## Implementación

`tool/anatomical_3d/solve_exercise_scapula_v910.py` recibe los derivados de v9.9, sin sobrescribirlos, y genera variantes `*_master55_v910_scapular_qa.glb` para `ex_bench_press`, `ex_barbell_row` y `ex_squat`. También deja `scapular_qa_v910_report.json` en los artefactos existentes de revisión del CI público.

En cada uno de los 41 fotogramas clave originales (cuatro segundos), el algoritmo:

1. Lee las posiciones 3D de muñeca, hombro y codo **del clip ya retargeteado de 55 articulaciones**, usando la cinemática real del GLB y su jerarquía; nunca supuestas coordenadas 2D.
2. Propone un giro bilateral *muy suave* del control de cintura escapular: hasta 1,4° en press, 2,8° en remo y 0,65° en sentadilla. Son límites artísticos de laboratorio, **no valores clínicos** ni una descripción generalizable del patrón escapulohumeral.
3. Recalcula ambas cadenas de brazo `upperarm → lowerarm → hand` mediante el IK de dos segmentos de v5 con un plano de codo derivado de la pose previa y la muñeca original como objetivo. Si ese objetivo no se alcanza, intenta ángulos cada vez menores o conserva la pose de origen; nunca acepta una desviación de muñeca superior a 1 mm en las claves.
4. Mantiene la traslación de la barra, las piernas y la geometría original, sin editar `skin`, el atlas de doce regiones, las matrices inversas de bind ni los ocho correctivos; genera un nuevo canal de control escapular izquierdo/derecho.
5. Regenera los ocho pesos de morph según las rotaciones articulares corregidas y deja su procedencia reproducible.
6. Rechaza fuentes habilitadas/aprobadas, faltantes de huesos, canales glTF no lineales, NaN, pesos fuera de intervalo, longitudes excesivas o intentos que no resuelvan ninguna pose.

Los tests añadidos al paso CI público `Check actual GLB linear interpolation and planted contacts at 30 FPS` examinan **121 muestras a 30 muestras/segundo por ejercicio**. Comparan manos, pies, pelvis y barra respecto de v9.9, además del estado del rig original. Se verifica que el movimiento escapular no produce una diferencia mayor de 5 mm en muñecas, manos contra barra o apoyos de pie. Los registros incluyen cantidad de poses IK resueltas, máximos de ángulo y errores; son diagnósticos geométricos sin acreditación profesional.

## Límites y seguridad

- No implementa todavía giro clínicamente correcto de escápula/serrato, ni segmentación independiente de escápula, manguito rotador, inserciones tendinosas o contacto de dedos.
- Preservar una posición de articulación de muñeca **no prueba** que una mano humana agarre la barra sin intersección de piel o dedo. El GLB tampoco tiene física de placas/discos, suelo, banco ni compresión de tejido.
- Las poses originales retargeteadas siguen siendo tentativas: la solución IK evita deslizar la mano pero no valida cargas, torque articular, amplitud técnica o volumen muscular.
- Esta etapa continúa sin enlazar equipamiento rígido y malla skinned al mismo renderer GPU nativo de la app. Es una **salida glTF para pruebas offline**, no reproducción de usuario.
- Las visualizaciones/validaciones en Android físico y iPhone físico y la firma profesional de anatomía/entrenamiento siguen pendientes. Mantener `approved:false` y `enabled:false` y **0/229** activos.

## Comprobación y salida

```bash
cd apps/app_mobile
python3 tool/anatomical_3d/solve_exercise_scapula_v910.py \
  --pilots build/cc0_master_surface_v7/three_exercise_pilots_v99 \
  --output build/cc0_master_surface_v7/three_exercise_pilots_v99/scapular_v910
python3 -m unittest discover -s tool/anatomical_3d -p 'test_cc0_interpolated_motion.py'
```

**Puerta siguiente:** una vez verde el CI, añadir comprobaciones reales de colisión entre la superficie de piel/manos y barra/banco, separar las superficies musculares anatómicas y adaptar el renderer Metal/GLES a escenas con skinned mesh y equipo rígido, antes de dar el salto a más de tres ejercicios.
