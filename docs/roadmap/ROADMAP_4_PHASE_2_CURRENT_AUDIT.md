# Roadmap 4 — Auditoría de continuidad de Fase 2

Fecha: 2026-10-05 UTC (2026-10-04, Perú).
Rama de desarrollo: `feat/roadmap-3-foundation`.

## Alcance y evidencia

Revisión del árbol privado `74eb3c818b65d72f369cb962ac4f9706d18d9deb`,
mirror `394871a31549db9f104e78b2ea33018584d2b459`.
Ambos HEAD se volvieron a verificar antes de esta actualización documental.
Los archivos locales coinciden con todos los blobs de la fuente revisada.

- Public CI #114, run `37221166087`: **7/7 success**.
- Analyze/Core: 432 tests; Supabase: 588 assertions pgTAP tanto después del
  upgrade incremental como después del rebuild limpio.
- Mobile, Android, Web dart2js/WASM, iOS release/profile sin firma y Edge Functions:
  success.
- Preview #75, run `37221712478`: success. Pages #37, run `37221821332`: success.
- Estos resultados validan automáticamente el código indicado. No prueban
  migraciones aplicadas al Supabase remoto, smokes físicos ni cierre de Fase 2.

La documentación anterior conserva valor histórico. Sus frases «próximo paso»
y casillas sin marcar no sustituyen esta comparación del código y sus límites.

## Cobertura actual frente a Fase 2

| Área | Implementado en la fuente revisada | Pendiente o límite real |
| --- | --- | --- |
| Entrada profesional | Dashboard propio desde Perfil móvil y web, separado de Coach & Clientes. | Smoke del flujo completo con backend remoto autorizado. |
| Cartera | Página de 25, búsqueda acotada, filtros activo/pausado y requiere revisión; orden por revisión, nombre o último entreno. | Orden por adherencia; no existe aún un cálculo profesional de adherencia. |
| Resumen | Métricas permitidas por cliente y estado comercial separado; conteo de clientes activos del entitlement. | Resumen global completo de cartera, tareas pendientes y alertas. No sumar la página actual para fingir totales globales. |
| Estados y layout | Carga, vacío, error/reintento, aviso de reconexión; tarjetas/tabla responsive, refresh y descarte de datos durante recarga/cambio de sesión. | No hay cartera persistida para lectura offline; pruebas de widgets no equivalen a smokes físicos. |
| Ficha | Resumen y sección seleccionada; permisos individuales y paginación. Número fijo de lecturas por sección, sin consultar cada cliente o elemento desde Flutter. | Auditoría final de seguridad, escala y experiencia E2E. |
| Programas | Lista y detalle de rutinas/ejercicios de la asignación actual; versión esperada validada en cada página. | Historial real de revisiones, comparación entre revisiones y flujo de actualización aceptada. |
| Tareas | Lista, detalle e historial de ocurrencias paginados. | Historial de ocurrencias no es por sí solo una tasa de adherencia ni historial de cambios de prescripción. |
| Comentarios | Lectura paginada y envío en tareas con `comment` independiente, autor/fecha y validación backend. | No hay bandeja general de comunicación. El envío existente no tiene clave de idempotencia; no reintentar automáticamente tras resultado incierto. |
| Check-ins | Lectura paginada bajo `view_checkins`. | Configuración profesional, resumen global y automatización de seguimiento. |
| Entrenamientos | Resúmenes paginados bajo `view_workouts`. | La sincronización existente comparte hasta 30 entrenamientos recientes; no permite afirmar historial completo, tendencias por ejercicio ni comparativas 90 días. |
| Progreso | Snapshot con conteos 7/30 días, minutos, series, volumen y RIR de 7 días; fecha de generación visible, ausencia diferenciada de cero. | Comparaciones entre periodos, series temporales, PRs, tendencias por ejercicio y adherencia contextual. |
| Orientación alimentaria | Lista, detalle por versión, comidas paginadas y selector de versiones reales; permiso `view_nutrition`, alcance no clínico. | No habilita edición profesional nueva, rollback ni aplicación automática de otra versión. |
| Exportación | No se encontró un flujo de exportación profesional en `features/coach_pro`. | Diseño y prueba de exportación autorizada, acotada y sin notas privadas. |

Referencias de implementación (rutas relativas a la raíz del repositorio):

- `apps/app_mobile/lib/features/profile/presentation/pages/profile_page.dart`
- `apps/app_web/lib/features/profile/presentation/profile_page_web.dart`
- `packages/core/lib/features/coach_pro/domain/coach_pro_dashboard_query.dart`
- `packages/core/lib/features/coach_pro/application/coach_pro_dashboard_provider.dart`
- `packages/core/lib/features/coach_pro/application/coach_pro_client_detail_provider.dart`
- `packages/core/lib/features/coach_pro/data/coach_pro_client_detail_service.dart`
- `packages/core/lib/features/coach_pro/presentation/coach_pro_dashboard_page.dart`
- `packages/core/lib/features/coach_pro/presentation/coach_pro_client_detail_page.dart`
- `packages/core/lib/features/coach_pro/presentation/coach_pro_task_comments_page.dart`
- `packages/core/lib/features/coach/application/coach_progress_snapshot_builder.dart`
- `packages/core/lib/features/coach_pro/presentation/coach_pro_nutrition_versions_page.dart`

## Hallazgo: el número de versión de programas no es un historial de revisiones

La migración `supabase/migrations/20260924063000_stk_assigned_programs.sql`
crea tres tablas: asignación, rutinas y ejercicios. La fila de asignación tiene
`version` con valor inicial 1; las rutinas dependen de la asignación y los
ejercicios de la rutina. No existe una entidad de revisión entre esas tablas.

`stk_assign_program` crea una asignación nueva y sus snapshots normalizados.
No recibe una asignación predecesora, no conserva un linaje de revisiones y no
incrementa una versión anterior. `stk_accept_assigned_program` y
`stk_archive_assigned_program` actualizan estado/fechas. En el conjunto actual
de migraciones no se encontró una RPC que revise la prescripción y conserve
simultáneamente sus valores anteriores.

`supabase/migrations/20261003043047_stk_coach_pro_program_detail.sql` compara
`p_version` con la versión de la fila actual. Una versión diferente produce
`Assigned program version changed; reload`. Esto protege la coherencia entre
páginas; no permite recuperar una versión histórica.

`supabase/tests/database/coach_pro_program_detail_rls_test.sql` siembra una
asignación en versión 2 y después cambia su número a 3 para comprobar el rechazo
de consultas obsoletas. Esa prueba no crea ni verifica una colección de
revisiones. No debe citarse como evidencia de historial completo.

La instalación local introduce otra dependencia:
`packages/core/lib/features/coach/application/coach_program_installer.dart`
usa `coach_program_imports_v1`, cuyo índice es `assignmentId`. Si ya existe un
programa importado, devuelve ese programa. No distingue revisiones de la misma
asignación. `coach_program_assignment_provider.dart` obtiene la asignación,
acepta en backend y luego instala localmente. Cualquier futuro flujo de revisión
debe definir explícitamente qué versión se acepta y qué sucede si la instalación
local falla, sin reescribir silenciosamente el programa personal.

Conclusión: **el historial de cambios de programas sigue pendiente**. No es
correcto copiar el selector de nutrición y poblarlo con el número de versión,
con asignaciones de nombre parecido ni con fechas inferidas.

## Próximo bloque exacto y orden de implementación

Prioridad: contrato backend de revisiones inmutables de programas, antes de su UI.
Esta auditoría define requisitos; no introduce tablas, RPCs ni migraciones nuevas.

1. Definir identidad de programa/asignación/revisión y linaje explícito. Separar
   revisión propuesta de revisión aceptada/instalada. Preservar el contrato legacy
   de asignar, aceptar y archivar, y la copia personal ya instalada.
2. Conservar snapshots de revisiones de forma atómica, acotada y sin estado
   mutable compartido. No reconstruir retrospectivamente cambios que no quedaron
   registrados. Si se captura una asignación legacy, identificarla como baseline
   observado, conservando su número de versión y sin inventar autor/fecha del
   supuesto cambio histórico.
3. Implementar primero persistencia y lectura paginada autorizada: cuenta
   permanente, capability coach, entitlement, relación activa propia y
   `assign_programs`. Aislar asignación/revisión/rutina/cliente y coach; metadatos
   mínimos en listados, sin notas privadas. No debilitar las guardas actuales.
4. Probar en Supabase efímero: baseline legacy, atomicidad, inmutabilidad,
   concurrencia/versiones obsoletas, aislamiento entre coaches del mismo cliente,
   revocación, expiración, anonimato, límites, conteos y orden estable. Mantener
   pruebas de aceptación/archivo legacy y revocación del cliente tras downgrade.
5. Solo con backend verificado, añadir servicio/provider y lectura de historial.
   La publicación de nuevas revisiones y su aceptación/instalación explícita
   requieren después un slice propio con recuperación ante fallos y prueba de
   que no reemplaza silenciosamente programas personales.

No mezclar este bloque con Smart Coach, exportación o comparativas de periodos.
La brecha siguiente queda concretada sin declarar finalizada la Fase 2.

## Validación documental y límites

Se revisaron tablas, RPCs, callers Flutter, instalador local y pruebas existentes;
se contrastaron las rutas citadas y el árbol remoto. Este cambio es documental:
no necesita tests nuevos que solo reproduzcan el texto. Su snapshot debe seguir
pasando el gate público 7/7 y las guardas de publicación antes de cerrar el bloque.

Se mantienen vigentes el Threat Model y las auditorías históricas: fuente privada
primero, mirror sanitizado, sin merge a `main`, sin cambios a la PWA estable ni
despliegue remoto. El ledger Supabase remoto no se consultó ni se modificó.
L01–L10, smoke físico y auditoría final permanecen separados de la evidencia CI.
