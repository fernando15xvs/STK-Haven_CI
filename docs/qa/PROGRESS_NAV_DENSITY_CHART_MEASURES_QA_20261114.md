# STK Haven — Checklist QA: navegación / Progreso / Medidas

**Fecha:** 14-11-2026 · **PR única:** [#57](https://github.com/fernando15xvs/STK-Haven/pull/57).
**Plan:** [PROGRESS_NAV_DENSITY_CHART_MEASURES_ROADMAP_20261114.md](../roadmap/PROGRESS_NAV_DENSITY_CHART_MEASURES_ROADMAP_20261114.md).
**Estado:** implementación A–D en PR #57; comprobación automática final y QA física pendientes. Checks sin marcar hasta evidencia. Nunca aceptar CI como QA físico.

## A. Cabeceras raíz y navegación

- [ ] Entrenar raíz: sin título duplicado, `Mi programa` inicia por debajo de SafeArea y mantiene administrar/crear/ver plan, rutinas, plantillas y acciones.
- [ ] Progreso raíz: sin título duplicado y con las cuatro pestañas visibles/accesibles inmediatamente debajo de SafeArea.
- [ ] Perfil raíz: sin título duplicado, `PersonalProfileSummary` y edición visibles, menús y Fe opt-in intactos.
- [ ] Inicio: saludo, fecha y hero actual conservados.
- [ ] La navegación inferior `Inicio / Entrenar / + / Progreso / Perfil` mantiene tamaño, posición, foco, rutas y safe area.
- [ ] Las páginas de detalle mantienen título contextual y botón atrás. Back regresa al punto de origen.
- [ ] `Inicio → Ver análisis en Progreso` abre Resumen incluso tras haber visitado Medidas u otra subpestaña.
- [ ] Cambiar pestaña no reinicia búsqueda, métrica, scroll o `TabController` de forma indebida.

## B. Período y lista de ejercicios

- [ ] El `TabBar` dice solamente `Resumen`, `Ejercicios`, `Músculos`, `Medidas` (sin `1A` pegado a cada tab).
- [ ] No existe barra global fija de período encima del `TabBarView`.
- [ ] Control compacto `1A ▾` dentro del contenido seleccionado de Resumen/Ejercicios/Músculos; no en Medidas.
- [ ] Seleccionar 7D, 1M, 3M, 1A actualiza correctamente las tres vistas sin que difieran los filtros; cambio persiste en el `IndexedStack`.
- [ ] Músculos no repite banner de período ni texto instructivo redundante; la explicación completa sigue disponible.
- [ ] Medidas conserva sus fechas y no hereda `timeFilterProvider`.
- [ ] Buscar: icono revela campo; escribir, borrar, cerrar, reabrir, teclado, estado activo, mensaje vacío.
- [ ] Filtros en hoja: sort Recientes/Alfabético/Mayor mejora/Mayor descenso/Inactividad; músculos, aplicar/limpiar, indicador activo.
- [ ] «Ver todos los ejercicios con historial» permite encontrar sesiones antiguas sin alterar el filtro principal ni inventar resultados.
- [ ] La primera tarjeta real aparece antes de los controles secundarios y sus valores usan historial auténtico.

## C. Pantalla focalizada y gráfico

- [ ] Abrir un ejercicio no muestra chevrón de colapso ni permite contraer su única tarjeta.
- [ ] Título, últimos datos, acción Historial completo, métricas, PR, sesiones y detalle permanecen presentes.
- [ ] Selector de 30 días / 90 días / Todo sigue funcionando en pantalla focalizada, independiente de período principal.
- [ ] Gráfico con una sesión, dos sesiones y múltiples sesiones no recorta el punto ni halo lateral derecho.
- [ ] Al abrir historial largo, se ve el punto más reciente completo; el usuario puede desplazarse hasta el primero.
- [ ] Al tocar un punto se selecciona su `sessionId` correcto, sin desfase por scroll horizontal ni margen de pintura.
- [ ] El desplegable de sesiones lleva al punto correspondiente y muestra fecha/hora, rutina y valores correctos.
- [ ] Peso, Repeticiones, RIR medio y e1RM mantienen unidades, datos ausentes honestos y no cambian por el rediseño.
- [ ] Historial completo abre todas las series (peso/reps/RIR/fecha) y back vuelve al gráfico.

## D. Medidas

- [ ] Frente: 9 puntos calibrados en sus ubicaciones; solo se destaca la etiqueta seleccionada, sin recubrir la figura con otras cajas.
- [ ] Todos los puntos y la acción «Ver todas las medidas» permiten alcanzar cada contorno sin perder medida ni historial.
- [ ] Espalda: 4 etiquetas sin degradar posiciones ni interacción; alternar vista elige estado válido.
- [ ] «Historial» / «Nueva medida» no quedan recortados ni debajo de encabezados al cambiar subpestaña o scroll.
- [ ] Guardar o editar una medida mantiene sus valores por ID, fecha, unidad y respaldo; ningún cálculo o migración cambia.
- [ ] «Sin registro» en medidas ausentes y detalle accesible por VoiceOver/TalkBack, teclado y tacto.

## E. Matriz obligatoria

| Variable | Cobertura |
| --- | --- |
| Ancho | 320 / 390 / 430 dp, y dispositivo estrecho |
| Texto | 100 % / 160 % / 200 %, sin letras reducidas artificialmente |
| Apariencia | Claro, oscuro, OLED, ocho acentos |
| Contenido | Sin sesiones, una sesión, muchas, nombres largos, valores nulos, muchos músculos y contornos |
| Gráfico | Extremo derecho/izquierdo, selección táctil, desplazamiento, cambio de métrica, foco, modo ahorro |
| Accesibilidad | VoiceOver/TalkBack, teclado, orden de foco, contraste, semántica de gráfico, targets táctiles |
| Estado | Cambios de subpestaña, regreso desde detalle, pantalla bloqueada/retorno, `IndexedStack` |
| Integridad | No tocar series, historial, periodos reales, programa, backups, Supabase/Hive ni audio |

- [ ] Tests automáticos verdes (Analyze + Core, Mobile, Anatomía, Edge, Supabase, iOS, Android).
- [ ] 7/7 jobs obligatorios `success` sobre último snapshot espejo (3D manual puede estar skipped si así lo define workflow).
- [ ] Paridad Git blob SHA canónico/espejo en todos los archivos modificados.
- [ ] Capturas de iPhone real, modelo / iOS / build: títulos ausentes, four-tab, Ejercicios, foco gráfico y Medidas.
- [ ] Capturas de Android real, modelo / Android / build: mismas condiciones.
- [ ] Revisión visual final y aprobación expresa antes de fusionar PR #57.

**Ninguna casilla representa ejecución real mientras este archivo sea un plan.**

## Registro automático de estado

- Cambios UI revisados en código y replicados al espejo (15/15 blobs del primer snapshot), con tests de contrato / diseño y pruebas nuevas de foco y chart.
- Primer run: [43619335709](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/43619335709), detectó advertencia fatal por import sin usar y test con clave `muscle_shared_period` sin actualizar. Se aplicó corrección; nuevo run debe verificarla.
- No se han realizado comprobaciones físicas en esta sesión. Las casillas de iPhone, Android, VoiceOver y TalkBack permanecen sin marcar.
