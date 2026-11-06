# Cierre en lote de Progreso 2.0 — 2026-11-05

**Regla solicitada:** preparar las tareas restantes sobre **una sola PR
canónica (#55)** y **no fusionar** cambios parciales a `STK-Haven/main`.
`STK-Haven_CI/main` es únicamente un ejecutor de Actions; los archivos
nuevos se sincronizan byte por byte y se comprueba su SHA Git blob.
No crear PR en el espejo.

## Inventario de los 17 ítems anteriores al lote

| Ítem | Entrega que puede comprobar CI | Requisito restante que no se debe inventar |
| --- | --- | --- |
| DATA-09 | Estado de serie explícito, Hive append-only, draft, historial, backup, UI móvil/web, tests | CI final + merge |
| GAM-01 | Política A conservadora, PR real separado de recompensa de sesión, test + `await` | CI final + merge; decisión reversible |
| DES-01 | Outfit y escalas AppTypography en componentes tocados y pruebas | Auditoría visual de cada pantalla |
| DES-03 | Tema semántico y matriz ocho acentos / OLED | Auditoría de superficies restantes |
| DES-04 | Contraste 4.5:1 para etiquetas y ocho acentos en matriz de tests | Contraste físico en gráficos y pantallas no tocadas |
| DES-05 | Spacing/Radius/Elevation de resumen muscular, calendario y medidas | Auditoría global de controles |
| DES-06 | Etiquetas de estados coherentes móvil/web/historial | Comprobar controles en dispositivo |
| DES-07 | 320/375/390/430px, escala 1/1.3/1.6 y tema en tests | ReduceMotion, SafeArea, dispositivos reales globales |
| DES-08 | Tests sintéticos sin datos privados en gráficos, medidas y balance | Revisar manualmente las seis capturas originales en dispositivo |
| DES-09 | Semántica explícita de días, rangos y estados de serie | VoiceOver/TalkBack físicos |
| QA-04 | CI de Motivation, workout, historial y no cambios remotos | Revisión final de diff y pruebas reales |
| QA-05 | Runbook de iPhone ya escrito | iPhone físico + captura y versión iOS |
| QA-06 | Runbook de Android ya escrito | Android físico + evidencia |
| QA-07 | Test 0/1/muchos datos, unidades, históricos parciales y contrastes | Lectores de pantalla y extremos en equipos físicos |
| QA-08 | Paridad de blobs y CI 7/7 requerido | Merge final tras aceptación |
| QA-09 | CI produce IPA **sin firmar**, registrar snapshot final | Firma Apple/provisioning, IPA instalable y prueba en iPhone |
| QA-10 | Revisión sin falsos cierres y evidencias localizables | Todas las verificaciones anteriores |

## Auditoría incremental de diseño incorporada al mismo lote

- **DES-06/07/08/09:** `ProgressConsistencyMetrics` elimina la
  abreviación por puntos suspensivos de las cifras y redistribuye los dos
  indicadores en 1/2 columnas según ancho y escala real. Conserva las
  etiquetas visibles `ENTRENOS / SEM` y `MEDIA REGISTRADA`, y aporta
  semántica «Entrenamientos por semana» / «Duración media registrada: N
  minutos» sin afirmar esfuerzo activo.
- **DES-01/03/05:** `BodyMeasurementSilhouette` unifica el encabezado
  con `AppTypography.headlineSmall` (Outfit), aplica
  `AppColors.surfaceHigh` al lienzo en lugar de fondos ARGB
  específicos, y usa colores semánticos para texto, selector y puntos
  anatómicos. No toca perímetros ni geometrías de datos.
- **Evidencia nueva:** `progress_consistency_metrics_test.dart`
  contiene matriz de 24 casos 320/375/390/430 px × 1/1,3/1,6 ×
  claro/oscuro; `progress_measurement_badge_theme_test.dart` comprueba
  en los ocho acentos claro/oscuro/OLED el fondo semántico y Outfit.
- **Snapshot CI anterior a estas mejoras:** #753
  (7/7 jobs obligatorios SUCCESS; 23/23 hashes). Es insuficiente
  para validar los cuatro archivos visuales nuevos: emitir snapshot
  espejo completo y CI nuevo antes de cerrar el lote.

## Criterios antes de fusionar

1. Flutter analyze y tests Core/mobile, DB/RLS, Edge Functions,
   Android, iOS y anatomía **7/7 green** en **un mismo snapshot final**
   que abarque todos los archivos modificados; no reutilizar el CI #749
   anterior al lote de DATA/GAM.
2. Igualdad SHA para **cada** archivo del PR entre fuente privada y
   snapshot espejo; PR canónica con un único HEAD verificado.
3. No alterar datos existentes, borradores, backups previos,
   Motivation, playlist, Coach ni gamificación de sesión.
4. **No declarar** ejecutadas QA-05/QA-06/VoiceOver/TalkBack/IPA firmada
   sin evidencia física. Si falta firma o dispositivos, el ítem sigue
   abierto y el merge queda bajo la decisión del propietario.

El objetivo es reducir iteraciones, no ocultar bloqueos de QA ni
forzar un riesgo de migración silenciosa.
