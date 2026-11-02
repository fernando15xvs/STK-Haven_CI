# STK Haven — Fase 5 v9.7: revisión real de iOS/Android y tres pilotos

**Estado: instrumentos y guías implementados; ninguna revisión física completada.**
Solo `apps/app_mobile`. Cero cambios en web, Supabase, rutinas, historial, catálogos o 229 borradores. No se fusiona el PR experimental hasta las puertas de calidad.

## Por qué no basta CI verde

`flutter test`, un APK compilado y un IPA sin firmar NO prueban funcionamiento del shader GLES3/Metal en teléfono. Los contadores v9.6 son tiempos hasta confirmación MethodChannel; Android puede devolverla antes del dibujado. Un gráfico de 12 poses por segundo **no garantiza 12 FPS presentados**. No etiquetar ninguna medición simulada o de runner como física.

## Instrumentación móvil añadida

- `tool/anatomical_3d/mobile_device_qa_probe.dart` registra la duración de `FrameTiming.totalSpan`, `buildDuration`, `rasterDuration` en Flutter con una ventana circular de hasta 240 muestras por defecto. Expone p50 y p95, y número de intervalos Flutter por encima de 16,667/33,333 ms.
- En iOS/Android el mismo módulo lee **`ProcessInfo.currentRss`** de Dart y conserva el último valor y el máximo **observado** en instantes de muestreo. No confundirlo con pico de asignaciones, memoria exclusivamente GPU ni PSS total del equipo.
- El reloj y la captura de observaciones están desactivados si la bandera `experimentalGpuTelemetry` no fue habilitada manualmente, o si la aplicación no está activa. No hay analítica remota, nueva base de datos, timers periódicos ni persistencia.
- El visor añade `Copiar informe de dispositivo (QA)` solo cuando están habilitadas **ambas** opciones `experimentalIndexedGpu:true` y `experimentalGpuTelemetry:true`; el JSON local incluye hora UTC, plataforma, ID de escena, percentiles Flutter, RSS observado, contadores/ACK nativos y **límites explícitos de medición**. Requiere etiquetar manualmente el dispositivo, OS, perfil de build y condiciones al archivar la evidencia; copiar al portapapeles no equivale a subir un resultado.
- Opcionalmente `experimentalIndexedGpuPlayback:true` habilita la sonda **12 Hz** de v9.5. Un clic explícito debe habilitar el conjunto de banderas solo en una build de QA: ningún código de producción activa estas opciones automáticamente.

## Checklist de dispositivo (ejecutar en iPhone real y Android ES3 real)

1. Registrar modelo de dispositivo, versión de iOS/Android, modo claro/oscuro, color de acento, modo térmico, energía/ahorro de batería y perfil de build (preferir `profile`).
2. Revisar una misma malla y movimiento en **los ocho colores × dos modos**; confirmar que solo músculos implicados están coloreados; principal y secundario deben tener intensidad distinta; el resto permanecer gris neutro.
3. Para cada uno de los tres pilotos de catálogo `ex_bench_press`, `ex_barbell_row`, `ex_squat`: capturar posición inicial, máximo rango y posición final, de frente, perfil y tres cuartos; inspeccionar oclusiones y deformación de hombros, codos, cadera, rodillas, manos y pies. Conservar video/fotos únicamente según consentimiento/licencias de activos.
4. Verificar **equipamiento real** (barra, discos, banco o suelo), agarres, contactos y restricciones biomecánicas. **El GLB master de siete clips genéricos todavía NO representa estos tres ejercicios con equipamiento certificado**: si faltan, anotar `bloqueado` y no aceptar el piloto.
5. Comparar Canvas CPU con Metal/GLES3 para clipping, triangulación, iluminación, Z-buffer, tejido muscular, normal y alineación de articulaciones. Repetir con cámara girada y 0.65–1.6 de zoom.
6. Repetir a 12 Hz durante sesiones cortas y luego prolongadas. Guardar JSON del inspector Flutter y registrar **FPS reales con herramientas de GPU externas** (Android GPU Inspector/Perfetto, Xcode Metal System Trace/Instruments), FPS de presentación, jank, memoria total, térmicas y batería.
7. Forzar interrupciones: app al fondo y retorno, orientación/tamaño, pérdida de surface/context EGL, retorno de Metal, cambio de tema, pausa/reducir movimiento, cambio de escena. Confirmar inicialización de malla por vista, fallback a Canvas en timeout y que no se restaure animación con movimiento reducido.
8. Solicitar revisión de anatomía/biomecánica por profesional competente; no aprobar solo porque las pruebas matemáticas y CI sean verdes.

## Matriz explícita de revisión

`anatomical_pilot_review_qa.dart` conserva IDs históricos y define por piloto músculos primarios/secundarios y cinco comprobaciones **pendientes**. El visor expone `reviewPilotId` solo para lectura en QA, sin atribuir una animación genérica al ejercicio ni marcarla como aprobada. La validación prueba que todas las regiones existen en la superficie CC0 y que ningún piloto aparece `enabled`.

| Piloto | Músculos primarios | Ejemplo de bloqueo |
|---|---|---|
| Press banca | Pectoral mayor, deltoides anterior, tríceps | Sin banco o barra con trayecto/contactos reales |
| Remo con barra | Dorsal, romboides, trapecio medio, deltoides posterior | Sin agarre y bisagra de cadera verificables |
| Sentadilla | Cuádriceps, glúteo mayor, aductor mayor | Pies deslizan, rodillas mal alineadas o barra sin soporte |

**Siguiente decisión, no ejecutada automáticamente:** una vez disponibles videos/dispositivos reales, ajustar malla, rig y contacto específico de los tres movimientos y volver a medir. Si no hay esculturas musculares profesionales ni rig validado, no escalar el master a 229. **0/229 aprobados y 0/229 habilitados**.
