# STK Haven — Checklist operativo: Progreso 2.0 visual y funcional

> **Estado general:** 🟡 implementación P0 en curso. Gráficos/QA de dispositivos y comparación e1RM de 30 días ya integrados tras CI; mejoras UX y pruebas físicas siguen pendientes.
> **Fecha base:** 2026-11-02 · **Repositorio canónico:** `fernando15xvs/STK-Haven`.
> **Roadmap:** [PROGRESS_2_VISUAL_QUALITY_ROADMAP_20261102.md](./PROGRESS_2_VISUAL_QUALITY_ROADMAP_20261102.md).
> **Roadmap histórico (mantener):** [PROGRESS_2_UNIFICATION_AND_MUSCLE_BALANCE.md](./PROGRESS_2_UNIFICATION_AND_MUSCLE_BALANCE.md).
> **Regla:** `[x]` significa **integrado + verificado + evidencia enlazada**; `[ ]` significa pendiente aunque haya código parcial, una propuesta o pruebas de otra versión. No inferir aprobación a partir de capturas o un PR abierto.

## Cómo continuar sin perder el hilo

1. Empezar por la **primera casilla P0 pendiente**. Leer el contrato del roadmap antes de cambiar código.
2. Crear rama corta desde `STK-Haven/main`; enlazar ID de tarea en PR; ejecutar pruebas en `STK-Haven_CI`, nunca introducir workflows del espejo en el repositorio privado.
3. Registrar PR, SHA del código, ejecución de CI y resultado manual cuando corresponda en «Evidencia / bitácora» al final. Solo después marcar `[x]`.
4. No borrar datos del usuario ni reescribir IDs de rutinas/ejercicios, históricos, backups o persistencia Hive. Preservar STK Motivation, minimizing/resume workout, Coach y otros módulos.
5. Al finalizar una sesión de trabajo, dejar aquí: «última tarea cerrada / primera pendiente / bloqueo / siguiente paso / SHA actual». No prometer pruebas físicas inexistentes.

## A. Auditoría y definición (documental)

- [x] **AUD-01** Revisar las 6 capturas proporcionadas (modo claro/oscuro, tarjetas, ejes, tooltips, ficha). *Evidencia: revisión visual del 2026-11-02; las capturas privadas no se suben al repo.*
- [x] **AUD-02** Verificar archivos actuales de Resumen, Ejercicios, ficha, gráficos, métricas, Home, cache, calendario y sistema de temas. *Evidencia: lectura de `main` al redactar el roadmap.*
- [x] **AUD-03** Identificar superposiciones entre Inicio/Resumen/Ejercicios/ficha/historial y reglas de propiedad de datos. *Evidencia: tabla de responsabilidades del roadmap.*
- [x] **AUD-04** Establecer casos de prueba reproducibles y datos sintéticos para los defectos visuales observados. **Aceptación:** fixtures no personales y resultados esperados documentados. *Evidencia: `docs/progress/PROGRESS_CHART_VISUAL_FIXTURES_20261102.md` y tests sintéticos; CI [#41548857694](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41548857694), más aprobación al integrar PR #26.*
- [ ] **AUD-05** Registrar antes de tocar código la base SHA y la lista final de pantallas afectadas en el PR de implementación.

## B. PILAR 1 — P0: gráficos legibles y matemáticas confiables

### B1. Contraste, recortes y tooltips

- [ ] **GRAF-01** Crear/extraer estilo compartido de gráficos usando `AppTypography` (familia `Outfit`), `AppColors`, `AppSpacing`; nada de colores fijos de texto/tooltip. **Aceptación:** claro, oscuro, OLED y ocho acentos sin contraste deficiente.
- [ ] **GRAF-02** Reparar tooltip de volumen ilegible (referencia: `15912.0`). **Aceptación:** fecha + volumen + unidad; separadores de miles; contraste medido >=4.5:1 en texto normal; no tapa el punto ni invade tarjeta.
- [x] **GRAF-03** Corregir corte del extremo derecho («31 o») e izquierdo de e1RM. **Aceptación:** etiquetas de fecha completas en 320/375/390/430 px y escala de texto 1.0/1.3/1.6. *Regresión widget en PR #27; ejecución completa CI [#41553881830](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41553881830); QA física adicional pendiente en QA-05/06.*
- [ ] **GRAF-04** Corregir valores máximos cortados/solapados (ejemplo 39,0 kg), selección vertical y bordes. **Aceptación:** tooltip, máximo, mínimo y puntos extremos visibles, incluidos valores iguales o cercanos.
- [ ] **GRAF-05** Crear regresión de gráficos (`flutter_test`/golden si es viable) con claro/oscuro, OLED, los ocho acentos, texto ampliado y `tester.takeException() == null`.
- [ ] **GRAF-06** Documentar guía común: márgenes, tamaño mínimo de texto, cuadrícula, fechas, unidades, interacción táctil, estados vacíos y semántica accesible.

### B2. Exactitud, unidades y períodos

- [ ] **DATA-01** En volumen, usar X temporal real basado en fechas; definir agregación 7D/1M/3M/1A y ceros sin inventar sesiones. **Aceptación:** espacios proporcionales / buckets claros y etiquetas de período correctas.
- [x] **DATA-02** Unificar formato de métricas y tooltips: miles, decimales, fecha en español y kg/lb. **Aceptación:** nunca `15912.0` suelto. *Implementación: PR #30 y #32 fusionados; [CI de volumen #41560542458](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41560542458) y [CI de tooltips #41562353589](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41562353589), ambos SUCCESS en último SHA. QA visual física continúa pendiente en QA-05/06.*
- [x] **DATA-03** Convertir e1RM y límites Y al mismo `WeightUnit` **antes** de crear `LineChartData`. **Aceptación:** el mismo dato en kg y lb produce posiciones relativas equivalentes y no recorta la curva. *PR #26 y #27, pruebas de límites kg/lb aprobadas en CI [#41548857694](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41548857694) y [#41553881830](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41553881830).*
- [ ] **DATA-04** Separar «última estimación e1RM» y «mejor e1RM histórico» cuando difieren; comparaciones no contradicen la gráfica.
- [x] **DATA-05** Revisar `absoluteChange30Days` / `percentChange30Days`: definir intervalo real, referencia y mensajes sin datos; nunca titular «últimos 30 días» una comparación con fecha arbitraria anterior. *PR #28 integrado: ventana móvil y estado neutral sin referencia; CI completo [#41554717357](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41554717357). Verificar textos y accesibilidad en QA adicional.*
- [ ] **DATA-06** Probar ausencia de datos, 1 punto, valor constante, valores extremos, fechas iguales, sesiones fuera del filtro, lb/kg y período intermitente.
- [ ] **DATA-07** Investigar duración media observada de 252m sin asumir error; rastrear `durationSeconds` y finalizar/reanudar parcial. **Aceptación:** reglas documentadas de inclusión y anomalías con evidencia; no modificar registros existentes.
- [ ] **DATA-08** Definir y probar frecuencia, días activos, series efectivas, calendario, duración y PR cuando hay sesiones parciales; sin premios ni avance de programa incorrectos.
- [ ] **DATA-09** Distinguir pendiente vs omitida vs completada vs fallida. **Aceptación:** `!completed` no aparece automáticamente como «Fallida»; no migración Hive insegura.
- [ ] **DATA-10** Añadir pruebas unitarias del cálculo 30 días, temporización, agregación diaria/semanal/mensual, unidades y estados de series.

**Puerta P0:** todas las casillas GRAF/DATA completadas + QA visual verificado + CI verde; si no, **no** pasar a rediseñar las vistas.

## C. PILAR 2 — P1: estructura sin datos duplicados

- [ ] **UX-01** Simplificar `Progreso > Resumen` a volumen/comparación, consistencia/calendario, conclusiones verificables. **Aceptación:** sin duplicar días activos, cantidad de entrenamientos o estadísticas de otras tarjetas.
- [x] **UX-02** Reducir métricas históricas duplicadas en `Inicio > _WeeklyTracker`; Inicio prioriza sesión actual, rutina y acción; conservar acceso directo a Progreso. *PR #33/#52 fusionados; CI completo [#41572753842](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41572753842). La prueba física sigue documentada por QA-05/06.*
- [ ] **UX-03** Tarjeta cerrada de Ejercicios: nombre, última fecha, estimación/variación útil o «Sin comparación». **Aceptación:** sin abrirse ya informa si existe progreso medible; sin extrapolaciones.
- [x] **UX-04** Ordenar y filtrar Ejercicios por más recientes, alfabético, mejora, descenso e inactividad con estado neutral cuando falta evidencia; conservar búsqueda. *PR #38/#57 fusionados tras CI [#41703475306 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41703475306); incluye filtro muscular y pruebas en 320 px. QA física sigue separada en QA-05/06.*
- [x] **UX-05** Tarjeta expandida: comparación último/anterior y **una** tendencia seleccionable (peso, reps, RIR, e1RM), con comparación unilateral sólo si hay datos. *PR #38/#57 fusionados, controles de tema y estado «Sin datos de RIR», tests Core/móvil y CI [#41703475306 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41703475306). Inspección en teléfono sigue pendiente.*
- [x] **UX-06** Retirar la lista de cinco sesiones dentro de cada ejercicio; sustituir por enlace al historial detallado, sin borrar historial ni registros. *PR #34 y #36 fusionados; historial completo por ID, ruta legacy con lista breve cuando no tiene callback. CI [#41577701602 intento 2 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41577701602). QA físico pendiente por QA-05/06.*
- [ ] **UX-07** Conservar `Progreso > Músculos` exclusivamente para balance, series directas e indirectas explicadas; no añadir PR/e1RM duplicados ni cambiar cálculo de semanas completas.
- [ ] **UX-08** Ficha técnica exclusiva de demostración verificada, ejecución, equipo, músculos y errores; quitar segundo gráfico 1RM/PR/historial duplicados y crear «Ver mi rendimiento» con navegación al ejercicio exacto.
- [x] **UX-09** Si no hay demostración o guía específica, mostrar un único estado vacío compacto sin inventar técnica ni reutilizar media de otro ID. *PR #37/#56 fusionados; tests claro/oscuro y CI completo [#41578045691 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41578045691).*
- [ ] **UX-10** Mantener `Progreso > Medidas` con sus intervalos propios; no inferir hipertrofia/cambio muscular a partir de perímetros.
- [ ] **UX-11** Unificar contrato de filtro entre Resumen, Ejercicios y Músculos, explicar excepciones, y conservar períodos comparables. **Aceptación:** etiqueta y datos corresponden a la misma selección.
- [x] **UX-12** Aprovechar `ProgressAnalyticsCache` al buscar/filtrar; invalidar tras nueva sesión, edición, restauración o descarte sin datos stale. *El panel usa el caché por índice de historial revisionado en PR #38/#57. Validado por CI [#41703475306 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41703475306); la auditoría de comportamiento real en dispositivo sigue en QA.*
- [ ] **UX-13** Validar rutas existentes de Biblioteca, `ProgressIntelligencePage`, Inicio, Historial y acceso a técnica; no dejar navegación circular o sin retorno.
- [ ] **UX-14** Pruebas de no duplicación + navegación contextual en 320/390 px y texto grande, incluyendo nombres extensos y ejercicios personalizados.

**Puerta P1:** cada dato tiene un lugar principal, acceso contextual al resto y pruebas que garantizan que no se borró ninguna funcionalidad.

## D. PILAR 3 — Diseño compartido (obligatorio desde la primera implementación)

- [ ] **DES-01** Verificar `Outfit` en toda pantalla y subcomponente tocado; títulos, cuerpo, tooltips y ejes usan escalas de `AppTypography`, no tamaños inventados. **Auditoría pendiente:** `AppearanceTheme` y `AppTypography` declaran `fontFamily: 'Outfit'`, pero `apps/app_mobile/pubspec.yaml` no registra `fonts:`; comprobar distribución efectiva y licencia del recurso antes de declarar uniformidad tipográfica.
- [ ] **DES-02** Aplicar números tabulares en KPIs y gráficos sin introducir otra familia tipográfica.
- [ ] **DES-03** Centralizar colores en `AppColors.of(context)` para claro/oscuro, OLED y ocho acentos; ninguna etiqueta gris sobre gris ni verde de bajo contraste.
- [ ] **DES-04** Comprobar contrastes >=4.5:1 texto normal y >=3:1 texto grande; gráficos legibles sin depender sólo del color.
- [ ] **DES-05** Usar `AppSpacing`, `AppRadius`, `AppElevation` y componentes compartidos para paddings/radios/bordes/sombras; no añadir brillos, gradientes o animaciones decorativas nuevas.
- [ ] **DES-06** Unificar controles, iconos, buscador, seleccionadores de período, tarjetas, estados vacíos y etiquetas.
- [ ] **DES-07** Respetar `MediaQuery`, áreas seguras, navegación inferior, 320/375/390/430 px, texto 1.0/1.3/1.6, modo ahorro y `reduceMotion`.
- [ ] **DES-08** Revisar las **seis situaciones** que originaron este plan, con datos sintéticos equivalentes y ambas variantes de tema. **Aceptación:** sin recorte, solapamiento, pérdida de contraste ni información redundante.
- [ ] **DES-09** Revisar VoiceOver/TalkBack para fechas, unidades, tendencia, selección de puntos y orden de foco.

**Puerta de diseño:** tipografía, densidad, espacios, acentos y jerarquía iguales en toda la app; «profesional y sobria» es un criterio verificable, no un adorno.

## E. QA, integraciones y publicación

- [ ] **QA-01** PR(s) de implementación pequeño(s), cada uno con IDs cubiertos y cambios limitados. **Nunca** mezclar contenido de otro roadmap.
- [ ] **QA-02** En `STK-Haven_CI`: `flutter analyze --no-fatal-infos` y tests Core/móvil, incluyendo regresiones de P0/P1.
- [ ] **QA-03** Compilar iOS sin firma y Android y verificar artefactos; **compilar no equivale a instalar**.
- [ ] **QA-04** Revisar diferencias con `main`, garantizar cero pérdida de Motivation, playlist, workout reanudable, progreso e historial.
- [ ] **QA-05** Pruebas manuales iPhone físico: claro/oscuro/OLED/acento/texto grande, gráficos y navegación; registrar versión iOS, modelo, build, fecha y evidencia.
- [ ] **QA-06** Pruebas manuales Android físico equivalentes con tamaño de pantalla pequeño y grande; registrar resultado.
- [ ] **QA-07** Revisión de accesibilidad + pruebas con históricos largos, modo ahorro, sesiones parciales, 0 datos, 1 dato y valores extremos.
- [ ] **QA-08** Sincronizar/integrar PR aprobado al `main` canónico y al espejo; comprobar SHA/archivos relevantes. No atribuir al CI una prueba en dispositivo.
- [ ] **QA-09** Generar IPA **a partir del commit final validado**; registrar si está sin firmar, la fuente, SHA, fecha, tamaño, expiración del artefacto y cómo instalarla.
- [ ] **QA-10** Revisar nuevamente el checklist completo; concluir solo si no quedan ítems de implementación o QA pendientes.

## Evidencia / bitácora (actualizar en cada PR)

| Fecha | IDs | Rama / PR canónico | SHA | CI espejo / SHA | Prueba física | Estado / bloqueos |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-11-03 | UX-11 (EN VALIDACIÓN) / AUD-05 | [PR único #39](https://github.com/fernando15xvs/STK-Haven/pull/39), rama `feat/progress-shared-period-20261103` | base `084178f` | Espejo de solo Actions: snapshot a `STK-Haven_CI/main`, CI **pendiente** (sin PR adicional) | No realizada | 7D/1M/3M/1A compartidos en Resumen/Ejercicios/Músculos; Medidas y vista enfocada conservan intervalos propios. Pruebas reproducibles y [contrato](../../docs/progress/PROGRESS_SHARED_PERIOD_CONTRACT_20261103.md). No marcar UX-11 hasta validar el CI y fusionar. |
| 2026-11-03 | UX-04/05/12 (CÓDIGO FUSIONADO; QA FÍSICA PENDIENTE) | [PR #38 fusionado](https://github.com/fernando15xvs/STK-Haven/pull/38) | `9735d25` | [PR #57 fusionado](https://github.com/fernando15xvs/STK-Haven_CI/pull/57), CI [#41703475306 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41703475306) | No realizada | Orden por recencia/nombre/mejora/descenso/inactividad, filtro muscular, tendencia única, gráfico temporal y caché indexado. Fusionado con PR #36 preservando rutas. Primer CI detectó overflow 27 px a 320; controles corregidos y CI completo aprobado; QA física pendiente. |
| 2026-11-03 | UX-09 ✅ | [PR #37 fusionado](https://github.com/fernando15xvs/STK-Haven/pull/37) | `c567c49` | [PR #56 fusionado](https://github.com/fernando15xvs/STK-Haven_CI/pull/56), CI [#41578045691 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41578045691) | No realizada | Un solo estado sin guía/media/instrucciones verificadas, sin material de otro ejercicio. Tests Core/móvil/Android/iOS verdes. |
| 2026-11-02 | UX-06/08/13 (CÓDIGO INTEGRADO; QA FÍSICA PENDIENTE) | [PR #36 fusionado](https://github.com/fernando15xvs/STK-Haven/pull/36) | `eb020a8` | [PR #55 fusionado](https://github.com/fernando15xvs/STK-Haven_CI/pull/55), CI [#41577701602 intento 2 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41577701602) | No realizada | Ficha técnica sin PR/1RM/historial duplicados; rendimiento enfocado por ID y listado completo de sesiones/series validado por CI. La ruta legacy conserva fallback; QA física y accesibilidad siguen abiertas. |
| 2026-11-02 | UX-03 / UX-06 (CÓDIGO INTEGRADO; NAVEGACIÓN COMPLETA EN PR #36) | [PR #34 fusionado](https://github.com/fernando15xvs/STK-Haven/pull/34) | `c14958c` | [PR #53 fusionado](https://github.com/fernando15xvs/STK-Haven_CI/pull/53), CI [#41573262530 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41573262530) | No realizada | Tarjetas cerradas muestran 1RM actual. En móvil se ocultan cinco sesiones duplicadas mientras la ficha conserva historial; ruta legacy sin callback conserva lista. Prueba existente ampliada; CI final verde; historial dedicado integrado en PR #36. Casillas permanecen abiertas. |
| 2026-11-02 | UX-01 / UX-02 (CÓDIGO INTEGRADO; QA FÍSICO PENDIENTE) | [PR #33 fusionado](https://github.com/fernando15xvs/STK-Haven/pull/33) | `de047a5` | [PR #52 fusionado](https://github.com/fernando15xvs/STK-Haven_CI/pull/52), CI [#41572753842 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41572753842) | No realizada | Inicio reduce cuadrícula de 4 KPIs a siete días y botón a pestaña Progreso; Resumen elimina duplicado de días activos en Consistencia. Pruebas widget 320px, claro/oscuro y fuente ampliada. **CI/merge aprobados; QA física y otros criterios UX pendientes**. UX-01 conserva otras áreas pendientes. |
| 2026-11-02 | GRAF-02/04/06 y DES-09 (CÓDIGO INTEGRADO; QA FÍSICO PENDIENTE) | [PR #32 fusionado](https://github.com/fernando15xvs/STK-Haven/pull/32) | `7187c07` | [PR #51 fusionado](https://github.com/fernando15xvs/STK-Haven_CI/pull/51), CI [#41562353589 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41562353589) | No realizada | Tooltips compartidos 184 px, fecha/unidad, semántica para lector de pantalla y pruebas reales de callback de `fl_chart` en kg/lb; último SHA aprobado. GRAF-02/04/06 y DES-09 permanecen abiertos por revisión visual/guía integral y pruebas físicas. |
| 2026-11-02 | DATA-09 (CORRECCIÓN PARCIAL INTEGRADA) | [PR #31 fusionado](https://github.com/fernando15xvs/STK-Haven/pull/31) | `e7612ca` | [PR #50 fusionado](https://github.com/fernando15xvs/STK-Haven_CI/pull/50), CI [#41560953901 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41560953901) | No realizada | Serie no completada = «Pendiente», nunca «Fallida», sin migrar Hive; Flutter/Core/móvil/iOS/Android aprobados. **DATA-09 continúa [ ]**: distinguir también «omitida» y «fallida» realmente registradas exige modelado y pruebas posteriores. |
| 2026-11-02 | DATA-02 ✅ / DATA-08 PARCIAL | [PR #30 fusionado](https://github.com/fernando15xvs/STK-Haven/pull/30) | `cb8147b` | [PR #49 fusionado](https://github.com/fernando15xvs/STK-Haven_CI/pull/49), CI [#41560542458 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41560542458) | No realizada | Formato de volumen compartido, lectura a 320px y ausencia de porcentaje ficticio ante referencia cero; último SHA aprobado en CI. DATA-08 sigue abierta para auditar sesiones parciales, calendario y recompensas. |
| 2026-11-02 | DES-01 (EMPAQUETADO OK; AUDITORÍA ABIERTA) | [PR #29 fusionado](https://github.com/fernando15xvs/STK-Haven/pull/29) | `f0cbc2d` | [PR #48 fusionado](https://github.com/fernando15xvs/STK-Haven_CI/pull/48), CI [#41559759139 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41559759139) | No realizada | Fuente Outfit variable OFL empaquetada, manifest y tests aprobados; falta revisar el uso uniforme en todas las pantallas. |
| 2026-11-02 | DES-01 (EN VALIDACIÓN) | [PR #29](https://github.com/fernando15xvs/STK-Haven/pull/29) | `2e0f9a9` | [PR #48](https://github.com/fernando15xvs/STK-Haven_CI/pull/48), CI en curso | No realizada | Se empaqueta fuente Outfit variable original y licencia OFL, se registra en Flutter y se añaden tests. **No marcar DES-01** hasta completar CI y auditoría tipográfica integral. |
| 2026-11-02 | DATA-05 ✅ | [PR #28 fusionado](https://github.com/fernando15xvs/STK-Haven/pull/28) | `c7cf1bd` | [PR #47 fusionado](https://github.com/fernando15xvs/STK-Haven_CI/pull/47), CI [#41554717357 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41554717357) | No realizada | Comparación de e1RM limitada a 30 días reales; tres regresiones Core aprobadas. |
| 2026-11-02 | GRAF-03/04/05 y DATA-03 (EN REVISIÓN) | [PR #27](https://github.com/fernando15xvs/STK-Haven/pull/27) | `4aea85a` | [PR #46](https://github.com/fernando15xvs/STK-Haven_CI/pull/46) · CI [#41553881830](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41553881830) | No realizada | Test `progress_chart_viewport_matrix_test.dart`: 320/375/390/430 px, escala 1/1,3/1,6, claro/oscuro/OLED, revisión geométrica y de contraste. Analizador, Core, pruebas móviles y compilaciones iOS/Android aprobadas; PR #27 integrado en main. Continúa pendiente la prueba física. |
| 2026-11-02 | AUD-01–03 | Documentación de planificación | No aplica a implementación | No aplica | No realizada | Auditoría completada; mejoras pendientes. |
| 2026-11-02 | AUD-04 ✅ / GRAF-01–04 y DATA-02–03 parcialmente | [PR #26](https://github.com/fernando15xvs/STK-Haven/pull/26) | `1fae807` (previo a esta bitácora) | [PR #45 fusionado](https://github.com/fernando15xvs/STK-Haven_CI/pull/45) · CI [#41548857694 ✅](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/41548857694) | No realizada | Implementado estilo común, fechas y corrección de unidades; core/mobile/analyze/iOS/Android aprobados. **Pendiente:** pruebas más amplias de clipping, tamaños, OLED, UI del tooltip y QA físico. |

## Estado de reanudación

- **Últimas tareas cerradas:** AUD-04, GRAF-03, DATA-02/03/05, UX-02/04/05/06/09/12. PRs principales #26–#38 (según alcance) integrados con CI verde del último SHA; evidencia en bitácora.
- **Siguiente tarea:** validar el PR único [#39](https://github.com/fernando15xvs/STK-Haven/pull/39) mediante push de snapshot al espejo CI (sin PR en `STK-Haven_CI`); corregir resultados, fusionar en principal tras CI verde; después abordar DATA-07/08 y pruebas visuales/IPA. UX-11 y QA físico permanecen abiertas hasta evidencia.
- **Bloqueos conocidos:** inspección física en iOS/Android aún no realizada, auditoría tipográfica integral DES-01 abierta y DATA-07/08 sin contrato final de parciales/duración. PR #38/#57 ya fusionados con CI completamente verde; falta revisión UX-11 y validación visual. La IPA final requiere compilar el commit de publicación y firmarla para instalación convencional en iPhone.
- **Precaución:** no confundir el CI aprobado de STK Motivation y entrenamiento activo del 2026-11-02 con la validación futura de este rediseño.
- **Siguiente actualización:** registrar SHA de la rama de implementación, PR y pruebas antes de cambiar casillas.
