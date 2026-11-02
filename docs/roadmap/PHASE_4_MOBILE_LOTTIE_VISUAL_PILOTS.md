# Pilotos visuales móviles — candidato v1, 2026-10-20

## Entrega implementada

Tres ilustraciones animadas originales, IDs `ex_bench_press`, `ex_barbell_row` y
`ex_squat`. Comparten personaje atlético de perfil, rostro, cuello, ropa,
segmentos con volumen, manos, calzado, materiales y equipamiento. Son candidatos
para resolver el diseño definitivo; **no son arte aprobado ni biomecánica certificada**.
No se recuperaron las imágenes de los prototipos del chat previo: este candidato
implementa el estándar escrito y debe compararse visualmente con la intención del creador.

Los 229 borradores originales permanecen intactos. Los tres candidatos viven en
`apps/app_mobile/tool/visual_pilots/`, fuera del bundle de Flutter y fuera del
registro de medios aprobados. No hay modificación de IDs, historial, datos,
Supabase ni `apps/app_web`. No se utilizan GIFs, imágenes incrustadas, fuentes
externas, máscaras ni efectos. **229 draft / 0 approved / 0 enabled** continúa vigente.

## Producción reproducible

`python3 apps/app_mobile/tool/build_visual_pilots.py` genera JSON Lottie 5.7.4,
SVG de la pose intermedia, manifiesto y `review.html` con animación vectorial,
pausa, inspección de fotogramas, modo claro/oscuro y ocho acentos. El HTML es una
herramienta local de revisión, no una implementación web de la app. No se guarda
el HTML generado en Git; el CI lo publica como artefacto de revisión.

Las composiciones usan 512 × 512, 30 fps, bucles de 4 segundos con preparación,
descenso/recorrido, reversión y retorno. Un rig de dos segmentos mantiene las
longitudes de brazos en press/remo y piernas en sentadilla en las muestras.
Los apoyos permanecen fijos. La interpolación entre muestras tiene error acotado
por prueba (<5 unidades del lienzo); no es una simulación biomecánica.

Arte SVG y Lottie comparten curvas cúbicas. La vista SVG no reproduce exactamente
el renderizador Flutter. `tool/visual_pilot_preview.dart` proporciona una superficie
interna real de Lottie con `AppColors`, delegados semánticos, pausa y movimiento
reducido. Recibe composiciones ya decodificadas; no vuelve a leer JSON al reconstruir.
Con movimiento reducido muestra la pose intermedia estática. El visor HTML usa
los ocho colores base; el renderizador Flutter usa los colores ajustados por
`AppColors` al tema. Los PNG de Flutter son la evidencia para esa combinación.

## Verificación y límites

- Base verificada: CI público #411 / run 39495183618, seis jobs completados con éxito.
- Comparación inicial: 236 archivos de Lottie, herramientas, pruebas y documentos
  de ese conjunto con SHA idéntico en privado y espejo; árbol Lottie idéntico.
- Seis pruebas Python locales aprobadas: IDs/aprobación, reproducibilidad, presupuesto,
  apoyos/longitudes, curvas/topología y error entre muestras.
- Nuevas pruebas Flutter: decodificación, pintura no vacía, cambio de pose, igualdad
  de extremos del bucle, cambio de píxeles al cambiar acento, pausa y movimiento
  reducido. Generan 144 PNG (3 ejercicios × 2 modos × 8 colores × 3 fases).
- Estas capturas todavía no son golden baselines aprobadas. Los tests detectan
  problemas técnicos; **no juzgan naturalidad, anatomía o calidad profesional**.
- Presupuesto por candidato: <230 KB sin comprimir, <55 capas, sin recursos
  rasterizados. Se registran tiempos de decodificación del runner, sin presentarlos
  como medición de rendimiento en iPhone/Android.
- Pendientes explícitos: aprobación visual del creador, revisión biomecánica por
  persona competente, inspección completa del movimiento en ambos teléfonos,
  jank/frame timings, memoria y batería en dispositivo, accesibilidad física y
  legibilidad en tamaño compacto. No se afirma compatibilidad perfecta ni 60 fps.

## Comandos

Desde `apps/app_mobile`:

```sh
python3 -m unittest discover -s tool -p 'test_visual_pilots.py'
flutter test test/features/exercises/mobile_visual_pilots_test.dart
python3 tool/build_visual_pilots.py --output build/visual_pilots
```

El artefacto público `stk-haven-visual-pilots` contiene el visor, JSON, SVG, capturas
Flutter y métricas. Revisar antes de escalar a las otras 226 variantes. Esta entrega
no cambia ninguna aprobación ni publica/instala medios en la aplicación.
