# STK Haven — Roadmap aprobado: navegación limpia, Progreso enfocado, gráfica y Medidas

**Fecha:** 14-11-2026
**Estado:** Bloques A–D implementados en PR #57; pruebas del snapshot corregido y QA física pendientes. No fusionado.
**PR:** [#57 (única, en borrador)](https://github.com/fernando15xvs/STK-Haven/pull/57).
**Rama canónica:** `fix/home-phase1-data-navigation-20261113`.
**Espejo:** `fernando15xvs/STK-Haven_CI/main` SOLO para Actions; nunca abrir PR ni fusionar allí.
**QA:** [checklist dedicado](../qa/PROGRESS_NAV_DENSITY_CHART_MEASURES_QA_20261114.md).

## Objetivo y decisión final aprobada

Liberar espacio vertical en las pestañas principales **Entrenar, Progreso y Perfil** y dar prioridad a ejercicios, análisis y anatomía. No eliminar las cuatro subpestañas **Resumen / Ejercicios / Músculos / Medidas** ni añadir el período al nombre de ninguna de ellas. **Inicio** conserva saludo y fecha. Las páginas secundarias (p. ej., Rendimiento de un ejercicio, Historial, Editar perfil) conservan AppBar contextual, regreso y acciones.

La barra inferior actual `Inicio | Entrenar | + | Progreso | Perfil` permanece idéntica y respeta SafeArea. Outfit y tokens `AppTypography`, `AppColors`, `AppSpacing` y componentes existentes permanecen coherentes en claro/oscuro/OLED y ocho acentos.

## Diagnóstico contrastado con código y capturas

| Superficie | Causa verificable | Resultado deseado |
| --- | --- | --- |
| Entrenar raíz | `routines_page.dart` declara `AppBar(title: Entrenar)` aunque el dock ya dice Entrenar | `Mi programa` aparece más arriba; se conservan creación, rutinas, plantillas y scroll |
| Perfil raíz | `profile_page.dart` declara `AppBar(title: Perfil)` y usa lista con resumen de usuario | Cabecera grande retirada; resumen personal es primer elemento útil |
| Progreso raíz | `progress_page.dart` declara `AppBar(title: Progreso)` encima de cuatro `Tab` | Cuatro pestañas debajo del SafeArea, sin encabezado duplicado |
| Selector global | `ProgressSharedPeriodSelector` ocupa una fila fija entre `TabBar` y `TabBarView` para 3 pestañas | Control compacto en el contenido visible; `timeFilterProvider` permanece compartido |
| Ejercicios | `ProgressExercisesPanel` suma título, filtros, búsqueda y lista; la lista compacta ya abre una ruta individual | Encabezado funcional y lista visible pronto, búsqueda temporal y filtros en hoja inferior |
| Rendimiento individual | `FocusedExerciseProgressPage` usa el panel con `initialExerciseId`; `_ExerciseInsightCard` sigue usando `ExpansionTile` | No plegable al haber un único ejercicio, con todas las funciones disponibles |
| Último punto del gráfico | `_SelectableExerciseTrend` usa `SingleChildScrollView` horizontal, ancho por sesiones y `CustomPaint`; no garantiza posición inicial en el último punto | Punto reciente visible completo con margen seguro y desplazamiento correcto |
| Medidas frontales | `body_measurement_silhouette.dart` dibuja 9 etiquetas frontales vs. 4 posteriores, todas simultáneas | Frente en modo enfoque: punto activo + etiqueta activa, otros puntos tocables; trasera esencialmente igual |
| Medidas: botones superiores | `BodyMeasurementPage` pone «Historial» y «Nueva medida» antes de la silueta; captura muestra recorte durante interacción | Verificar posición y scroll al cambiar pestaña, evitando solapamiento |

## Reglas de alcance y seguridad

1. **Solo UI y estado efímero de presentación**. Ninguna migración de Supabase/Hive, modificación de rutinas/programas, historia, records, sensores, permisos, audio ni fórmulas de 1RM/volumen/RIR.
2. No fabricar medidas, fecha, PR ni datos ausentes; respetar «Sin registrar»/«Sin estimación» y unidades.
3. El filtro principal **7D / 1M / 3M / 1A** sigue compartido por Resumen, Ejercicios y Músculos mediante `timeFilterProvider`; no se sustituye por tres filtros independientes.
4. **Medidas** conserva fechas propias. **Rendimiento individual** conserva su selector de **30 días / 90 días / Todo** y estado de selección.
5. Conservar la navegación desde Inicio hacia **Progreso → Resumen** y los filtros/revisitas de `IndexedStack`, sin recrear el `TabBarView` por cambios de altura o índice.
6. Mantener **una sola PR #57** en el repositorio privado; snapshots mínimos en `STK-Haven_CI/main` sin PR; exigir **7/7 jobs SUCCESS** y paridad blob SHA en código afectado antes de proponer fusión. Nunca fusionar sin autorización.
7. No confundir CI o IPA sin firma con QA real de iPhone/Android.

## Bloque A — Navegación raíz, sin títulos repetidos (alta)

- [x] **A1. Entrenar:** quitar solo `AppBar` de título redundante en `RoutinesPage` si carece de acciones imprescindibles; `Mi programa` comienza bajo SafeArea con aire coherente, seguido de Mis rutinas y Plantillas. No mover «Tu entrenamiento» desde Inicio ni modificar flujos de entrenamiento.
- [x] **A2. Perfil:** quitar `AppBar(title: Perfil)`; mostrar el `PersonalProfileSummary` como primer contenido útil y mantener edición, menús, Fe opt-in y privacidad.
- [x] **A3. Progreso:** retirar título grande «Progreso», **no** el `TabBar`; colocar las cuatro pestañas inmediatamente bajo SafeArea. Preservar `DefaultTabController`, indicador, scroll y ancla a Resumen.
- [x] **A4. Contextos:** conservar AppBar + back en pantallas secundarias; garantizar que títulos no choquen con barra de estado, notch, Dynamic Island, gestos ni barra inferior.
- [ ] **Gate A:** widget tests para root/secondary, navegación a Resumen desde Inicio, retorno y persistencia de pestañas.

## Bloque B — Selector de período y Ejercicios enfocado (alta)

- [x] **B1. Subpestañas limpias:** mostrar exactamente **Resumen | Ejercicios | Músculos | Medidas**, sin `1A`, iconos extra ni subetiquetas dentro del `TabBar`. Mantener desplazamiento horizontal accesible a 320dp si fuera necesario.
- [x] **B2. Selector compacto único en contexto:** eliminar la barra global fija `PERÍODO | 7D | 1M | 3M | 1A` de encima del `TabBarView`. Ubicar un control `1A ▾` ligero junto al encabezado **del contenido activo**: «Tu progreso», «Tus ejercicios» o «Balance muscular». En Medidas, no mostrarlo. Los encabezados son internos, no nuevos títulos enormes.
- [x] **B3. Estado compartido:** las cuatro opciones mantienen el `timeFilterProvider` existente, fechas, cálculo y selección al pasar entre tres pestañas. No modificar rango del detalle individual ni el historial de medidas. Evitar duplicar la etiqueta `period.label` en Músculos y trasladar texto instructivo repetitivo a un tooltip accesible.
- [x] **B4. Espacio real:** ubicar el encabezado compacto en el scroll del contenido cuando corresponda, sin crear otra franja fija que vuelva a ocupar la pantalla. Mantener el estado de subpestaña al alternar. A escala de texto elevada, usar reflow y menús, nunca comprimir Outfit a tamaños ilegibles.
- [x] **B5. Ejercicios:** reemplazar el buscador desplegado permanentemente por acción de lupa que revele un campo con foco, botón cerrar y limpieza; preservar búsqueda, teclado, accesibilidad y filtro de resultados. Tras cerrar/abrir, no borrar involuntariamente la consulta activa (definir estados visibles y recuperación).
- [x] **B6. Filtros:** mover ordenamiento y filtro muscular a hoja inferior accesible; indicar filtros activos (chip o contador) y ofrecer limpiar/restablecer. Mantener Recientes, Alfabético, Mayor mejora, Mayor descenso, Inactividad y grupos musculares disponibles. No ocultar la causa de un listado vacío.
- [x] **B7. Directorio:** conservar tarjetas compactas con nombre y dato real (fecha/e1RM o ausencia); toda la tarjeta abre rendimiento focalizado. Mantener una vía explícita «Ver todos los ejercicios con historial» para localizar ejercicios fuera de 7D/1M/3M/1A sin falsear su periodo ni reescribir métricas.
- [ ] **Gate B:** misma data/período antes y después, filtros compartidos, lista visible sin exceso de controles, límites 320/390/430dp.

## Bloque C — Rendimiento por ejercicio siempre abierto y gráfica completa (alta)

- [x] **C1. No plegable en ruta focalizada:** con `initialExerciseId`, reemplazar la apariencia de `ExpansionTile` por un panel permanente, sin chevrón ni acción de contraer. No mostrar pantalla vacía al tocar cabecera; preservar el comportamiento expandible en otros contextos donde haya varias tarjetas.
- [x] **C2. Mantener todas las funciones:** Ver historial completo, métrica Peso/Reps/RIR/e1RM, gráfico tocable, lista de sesiones, selección por fecha/hora/ID, Peso máximo, Repeticiones, RIR medio, e1RM máximo y PR/indicadores pertinentes; conservar opción Todo.
- [x] **C3. Límite derecho:** ajustar el padding del `CustomPaint` y el área desplazable para que punto/halo de selección más reciente quede totalmente dentro del lienzo visible; no basta con pintar un punto en el último píxel.
- [x] **C4. Foco inicial:** cuando el historial requiera scroll horizontal, iniciar mostrando las sesiones recientes (extremo derecho) y al seleccionar sesión/punto desplazar hasta mostrar el seleccionado con margen. En gráficos cortos, utilizar ancho completo sin desplazar innecesariamente.
- [x] **C5. Integridad:** preservar selección por `sessionId`, conversión de coordenadas táctiles al punto, valores ausentes sin ceros inventados, fechas reales y orden cronológico. Verificar 1 punto, 2 puntos, 8+ puntos, 50+ puntos, cambio de métrica, escala y orientación.
- [ ] **Gate C:** última observación completamente visible (círculo y halo), back y retorno funcionan, histórico completo navegable y ninguna pérdida de detalle.

## Bloque D — Medidas anatómicas limpias (media)

- [x] **D1. Frente:** mantener figura y coordenadas calibradas de los nueve contornos existentes. Mostrar puntos de todos los contornos; destacar **solo la etiqueta de la medida seleccionada** para evitar nueve cajas simultáneas. Las demás siguen accesibles por puntos y por «Ver todas las medidas».
- [x] **D2. Vista de todas:** lista/hoja secundaria con todos los nombres, valores y «Sin registro», y acción que selecciona/abre el detalle exacto por `MeasurementMetric`. No usar una lista duplicada con datos de otros contornos ni inferencias.
- [x] **D3. Espalda:** conservar la presentación actual de cuatro etiquetas salvo pequeños ajustes de contraste/scroll; respetar su mapeo y recuperar una selección válida al alternar frente/espalda (nunca indicar selección visual inexistente).
- [ ] **D4. Control y scroll:** conservar Frente/Espalda, Historial, Nueva medida, editor, navegación a detalle y resumen inferior. Corregir únicamente solapamiento/offset de scroll de acciones superiores si se reproduce; no modificar coordenadas casi correctas sin prueba.
- [x] **D5. Accesibilidad:** zonas de toque generosas y etiquetas semánticas para TODOS los puntos, VoiceOver/TalkBack y teclado; mostrar nombre y valor completos en detalle aunque una etiqueta flotante sea breve.
- [ ] **Gate D:** frente despejada sin perder acceso a los nueve contornos, espalda igual de funcional, cero cambios en historial y medidas.

## Bloque E — QA transversal, validación y cierre (obligatorio)

- [ ] **E1. Regresión visual:** 320/390/430dp × escala 1.0/1.6/2.0, claro/oscuro/OLED, 8 acentos, estados de vacío/datos largos, scroll y orientación.
- [ ] **E2. Regresión funcional:** selector compartido 7D/1M/3M/1A, período privado de Medidas, Todo focalizado, búsqueda/filtros/orden, chart touch y fecha, altimetría/etiquetas, Guardar/Historial.
- [ ] **E3. Navegación:** dock no se desplaza ni tapa CTA, `IndexedStack` retiene estado; back en páginas secundarias y enlace Inicio → Resumen.
- [ ] **E4. Rendimiento:** no recalcular íntegramente históricos en cada pulsación ni agregar listeners sin dispose; soportar modo ahorro y reducir movimiento.
- [ ] **E5. CI:** enviar snapshots mínimos a espejo sin PR; confirmar paridad de blobs cambiados y 7/7 Jobs SUCCESS, sin relajar tests.
- [ ] **E6. QA físico:** iPhone y Android (tamaños, barras de estado, pantalla larga, desplazamiento horizontal al último punto, lector de pantalla, contraste); registrar modelo, OS, build y capturas. CI no sustituye QA.
- [ ] **E7. Revisión:** mantener PR #57 en draft y no fusionar hasta aprobación explícita; generar IPA solo cuando corresponda a validación aprobada.

## Orden de ejecución y controles de avance

1. A (raíces y SafeArea) → tests → snapshot CI.
2. B (período compartido dentro del contenido y ejercicios) → tests → snapshot CI.
3. C (ficha única y gráfico sin cortes) → tests específicos de scroll/tap → snapshot CI.
4. D (medidas frontales) → tests de mapeo, accesibilidad y navegación → snapshot CI.
5. E (CI final, paridad, QA física y revisión). **No abrir otra PR**.

**Criterio de terminado:** la información útil aparece antes sin perder funciones; las cuatro subpestañas siguen legibles, ningún gráfico corta el último punto, todas las medidas siguen disponibles, CI 7/7 en el último snapshot y QA físico documentado. Hasta entonces, no marcar E como completado.

**Nota histórica:** el commit de creación del plan fue solo documentación. La implementación funcional posterior se hizo en esta misma PR #57; la validación final y aprobación de fusión siguen pendientes.

## Bitácora de ejecución (14-11-2026)

- **A:** código `37f5db452362aefbd14410bb0cc54502c55ed511` — título redundante retirado de Entrenar/Perfil y barra cero en Progreso sin perder SafeArea ni TabBar; prueba de navegación raíz actualizada.
- **B:** `802e57777e2f4e4d3113e2db495ec56d32f825c1` y `0c1aa66666e29beb017121291e692f345cf3503b` — menú compartido en cada contenido, búsqueda opcional, hoja de filtros, historial completo sin mutar `timeFilterProvider`.
- **C:** `57ac11ec78ed7c1bc62e54ce515ec61b57e18b06` — panel de único ejercicio permanente y scroll al punto elegido, con margen de pintura de 24dp; prueba de historial largo añadida.
- **D:** `3b5e19a58758dec55fcae1fff9a86274553192e0` — solo callout frontal activo, nueve puntos intactos y hoja con lista completa; espalda se conserva.
- **CI inicial** [43619335709](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/43619335709): Analyze y Mobile detectaron únicamente un import sin usar y un ancla de test muscular obsoleta; ambos corregidos en `bc4cd86ab50abbb54eba54bc6782f28357e183f2`. Esperando nuevo snapshot y 7/7 antes de cierre.
- **Pendiente puntual D4:** confirmar físicamente el recorte de botones Historial/Nueva medida al cambiar subpestaña; evitar ajustes arbitrarios del scroll sin evidencia.
- **Pendiente:** CI final, revisión de gestos/VoiceOver, capturas en iPhone/Android y aprobación explícita antes de merge.
