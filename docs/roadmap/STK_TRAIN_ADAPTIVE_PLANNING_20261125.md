# STK Haven — Entrenar compacto y planificación adaptable (25/11/2026)

## Alcance aprobado
Continuación de STK_TRAIN_DAILY_STATES_20261125.md. Base funcional privada 71880d3647b5df85c830f6b5297874b4852e78c4; espejo 8581b4bfaaca48d6d03c396246666e907f51328e; CI #45619174450 7/7. Paridad 1516/1517 blobs del alcance Mobile/Core/Supabase/tools/ci/public, única excepción privada preexistente ci/public/nutrition_private_qa.yml. Este documento no altera código ni datos. No iniciar implementación hasta instrucción del usuario.

## A — Motor único de planificación (Core Dart puro)
- [ ] Inventariar TrainingProgram, repositorio/shadow de backup, ProgramRotationCoordinator, ProgramScheduleProjector, ProgramPlanInsights, TrainingDayDecision, providers de sesión, editor, duplicación, plantillas y consumidores.
- [ ] Separar modalidad de calendario (flexible sin días, continuo con días de oportunidad, fijo día→rutina) y política de secuencia (rotación por sesiones, repetición semanal; fijo usa su mapa y no necesita selector adicional).
- [ ] Secuencia semanal explícita por posiciones/IDs de slot, que pueda repetir IDs de rutinas, independiente del catálogo de rutinas únicas. Validar frecuencia 1–7, referencias válidas y ausencia de duplicados de identidad de slot. Sin duplicar entidades Routine.
- [ ] Flexible/rotativo y continuo/rotativo: avanzar al completar la sesión asignada, mantener puntero entre semanas. Flexible: sin fechas artificiales ni deuda por ausencias. Continuo: oportunidades según días elegidos; faltar no consume slot.
- [ ] Flexible/semanal y continuo/semanal: repetir la secuencia configurada por semana local, recuperar pendientes dentro de la semana; al comenzar otra, no arrastrar deuda automáticamente (ofrecer recuperación explícita). Continuo añade días de oportunidad.
- [ ] Fijo: mapa semanal exacto; una ausencia no desplaza todo automáticamente. Recuperación/intercambio explícito sin alterar la plantilla.
- [ ] Compatibilidad: defaults rotativos para flexible/continuo existentes; conservar mapa fijo, IDs, puntero reconciliado, completions, startedAt, duración, notas, deload, rutinas, perfil y preferencias. No inferir un reinicio ni sustituir el programa activo. Mantener datos de otros modos inactivos sin utilizarlos.
- [ ] Definir semana local y semana de ciclo como conceptos distintos, límites lunes/domingo, medianoche, cambio de zona/DST; no confundir semana de calendario con duración activa. Reconciliación determinista e idempotente.
- [ ] Proyección por slots: objetivo semanal, completadas reales, pendientes, omitidas, pausadas y próxima válida; sin mostrar estimaciones con fecha en flexible. Mantener una fuente de verdad para Entrenar, detalle, planificación y estadísticas.
- [ ] Pruebas unitarias: cuatro rutinas y cinco sesiones, secuencias A B C D A / B C D A B (rotativo) frente a A B C D A / A B C D A (semanal), semanas incompletas, cambio de modo/orden, rutinas repetidas, borradas y legacy.
**Gate A:** CI 7/7 + contrato Core puro. Sin cambios UI innecesarios.

## B — Excepciones y recuperación de planificación (Core)
- [ ] Modelo persistente de excepciones con identidad de slot/fecha cuando aplica, estado, alcance y vigencia; separar plantilla, ocurrencia, sesión de historial y excepción. No reutilizar solo routineId como identidad de una ocurrencia repetida.
- [ ] Posponer: mover pendiente al siguiente día permitido o fecha explícita; no marcar completa. Intercambiar: sustituir el orden de dos ocurrencias; si se desplaza, mostrar efecto sobre otras pendientes. Omitir: avanzar/resolver slot sin completion ficticia.
- [ ] Recuperación de ausencia: flexible no tiene deuda por fecha; continuo conserva pendiente por defecto; semanal recupera dentro de semana; fijo conserva calendario salvo decisión explícita. No generar acumulación infinita de vencidas.
- [ ] Pausa de una o varias rutinas hasta fecha o reanudación manual: excluir temporalmente de sugerencias sin borrar ni modificar rutina; si no quedan disponibles, estado descanso/pausa. No imponer ejercicios alternativos ni recomendaciones médicas.
- [ ] Pausa del programa completo (distinta de desactivar/archivar): fecha opcional, conservar historial, congelar duración efectiva de ciclo/desload sin reescribir startedAt; sin acumular vencidas; reanudar explícitamente o al vencer plazo configurable.
- [ ] Inicio fuera de secuencia: ofrecer adaptar planificación, recuperar, intercambiar o independiente según contexto. Independiente conserva historial y no avanza la rotación. Resolver vínculo explícito entre workout y slot, sin recontar sesiones por reconciliación histórica.
- [ ] Mantener una sugerencia diaria: activa > completada hoy > disponible > descanso/pausa > sin plan; extra voluntario con confirmación, no prohibición general. Definir qué sesión consume slot al acabar y cómo se revierte una excepción futura no ejecutada; no alterar sesiones finalizadas.
- [ ] Persistencia backward-compatible en Hive, backup/restore, plantillas, duplicación y reapertura offline. Plan de migración sin reset, escritura idempotente y pruebas de recuperación. Si una regla no puede preservar semántica anterior, detener y documentar.
- [ ] Casos: lesión con Lower A/B pausadas y Upper disponible solo según autorización del usuario, ausencia martes y recuperar Lower miércoles, mantener calendario, intercambio, pausa completa, objetivos cumplidos, cambio modalidad durante pausa, finalización cerca de medianoche.
**Gate B:** CI 7/7; pruebas de persistencia y replay sin duplicados.

## C — Compactar Entrenar (Mobile)
- [ ] Hero listo: tres puntos en cabecera junto a flecha; eliminar fila Align separada y hueco; icono, nombre, ejercicios y duración real. Mantener acceso a editar/notas/duplicar/eliminar y adaptar planificación.
- [ ] Hero activo/finalizado: conservar continuar, resumen, ver entrenamiento y editar nota; layout responsivo compacto. Nada de siguiente sesión automática tras completar hoy.
- [ ] Descanso: icono, título y próximo día/rutina como texto informativo; sin menú de rutina ni acción de inicio en hero. La rutina anunciada permanece en Mis rutinas incluso al expandir. Exclusión por ID solo para destacada disponible/activa/finalizada; no para descanso/pausa. Descanso no consume sesión.
- [ ] Mis rutinas: mantener nombre/músculos/ejercicios/duración; menú y play juntos en horizontal cuando caben, evitar columna de dos objetivos táctiles que infla altura. En ancho pequeño/texto grande adaptar con wrap/fallback accesible. No reducir objetivos táctiles ni forzar truncamiento. No duplicar rutina destacada en lista expandida.
- [ ] Preservar tarjeta Programa Stoker, progreso real, Gestionar, Biblioteca, navegación inferior y ausencia de encabezado redundante. Inicio solo acceso compacto a sesión activa.
- [ ] Tokens compartidos de tipografía, escala, colores, radios, márgenes; claro/oscuro/OLED, tres UI Styles, cuatro fuentes. No geometrías rígidas de altura.
**Gate C:** CI 7/7 + widgets 320/390/430dp y escalas 100/160/200%, todos los estados.

## D — Editor y planificación (Mobile)
- [ ] Gestionar programa: modo de calendario, selector de secuencia solo en flexible/continuo, frecuencia, ordenar slots y repetir una rutina en secuencia semanal; calendario fijo conserva día→rutina. Vista previa de dos semanas; avisar cambio de próxima sesión y conservar historial.
- [ ] Modal Planificación flexible: progreso semanal, lista compacta de sesiones reales y pendientes con checks/estado, sin círculos grandes ni fechas/días artificiales, próxima semana navegable y distinguida como estimación. Una lista de cinco slots para objetivo cinco aunque solo cuatro rutinas únicas. Ajustar altura al contenido, scroll, asa y cierre accesibles.
- [ ] Continuo: calendario de oportunidades con fecha, completadas/pendientes y sesiones desplazadas; fijo: semana por día, ausencias/recuperaciones y excepciones claras. Ambos usan motor Core y misma gramática visual.
- [ ] Acceso a Adaptar planificación desde menú contextual de hero y Planificación; posponer/intercambiar/omitir/pausar/independiente según estado. Previsualizar efecto y confirmar cambios que alteran futuras sesiones. Gestión de pausa/reanudar con estado visible y controles accesibles. No agregar botones permanentes que saturen Entrenar.
- [ ] Mostrar objetivo semanal alcanzado sin sugerir automáticamente sesión extra; manual opcional confirmado. No ocultar rutinas en descanso o pausa.
- [ ] Revisar todos los consumidores de proyecciones para que el modo flexible no filtre calendarios artificiales y detalle/editor/hero estén de acuerdo.
**Gate D:** CI 7/7; pruebas de navegación y acciones con los cinco modos, pausas, recuperación e intercambio.

## E — Integración, regresiones y entrega
- [ ] Matriz integral: cinco combinaciones, objetivos 1–7, semanas parciales, día de descanso, cambio de semana/mes/zona, cambios de modo, ausencia, pausa múltiple/total, sesión manual, restore, duplicación/plantillas, datos antiguos sin onboarding nuevo.
- [ ] Core purity estricto, analyzer Core/Mobile, pruebas Dart/widget y regresiones de timers, progreso, Inicio, nutrición y backup; no cambios en Web ni Supabase remoto.
- [ ] Verificar SHA privado y espejo, paridad blobs funcionales y 7/7 del último commit. Entregar por bloques completos, no avanzar con CI rojo.
- [ ] QA física en iPhone/Android con actualización compatible sin desinstalar, revisar densidad de tarjetas y modal, accesibilidad, programa existente y datos históricos.
- [ ] Generar/descargar IPA/APK del último SHA validado; documentar firma (IPA CI sin firmar) y no fusionar PR #57 sin autorización.

## Decisiones operativas
- Un programa activo puede tener muchos entrenamientos históricos; no contarlos dos veces. La secuencia semanal representa slots, no copias de rutinas.
- Semana local de lunes a domingo para frecuencia; semana de ciclo sigue duración efectiva y pausas. Las excepciones son reversibles antes de ejecutar; las sesiones finalizadas no se reescriben. El usuario podrá ajustar desde el editor.
- El objetivo semanal es una meta, no un bloqueo de entrenamientos independientes; después de cumplirla se muestra estado cumplido. La confirmación de extras y su impacto evita avances silenciosos.
- Orden de ejecución A→B→C→D→E. Una PR privada #57 DRAFT; espejo solo Actions, sin PR espejo. Core pura lógica y datos, Mobile UI/adaptadores, Web pausada. Mantener backup y onboarding actual.
- Toda casilla pendiente hasta evidencia de implementación y CI del SHA correspondiente; no afirmar QA física ni firma sin realizarla.

## Estado
- [x] Diseño y reglas aprobados por usuario.
- [x] Baseline funcional CI #45619174450 7/7.
- [x] A Motor de planificación (CI #45633916378 7/7).
- [x] B Excepciones Core (CI #45640731951 7/7; acciones UI y recuperación entre semanas según D).
- [x] C Entrenar compacto (CI #45646554997 7/7).
- [x] D Editor y planificación (CI #45707671809 7/7).
- [ ] E Regresiones, QA física y artefactos.

## A.1 — Secuencia semanal y compatibilidad (implementación preparada)
- Se incorpora ProgramSequencePolicy rolling/weekly y lista separada de posiciones semanales (IDs repetibles), con valores legacy rotativos, copia/plantillas/JSON y shadow de respaldo existentes. El modo fijo ignora la política semanal.
- Reconciliación y proyección respetan la semana local: rotación continua conserva puntero, repetición semanal vuelve a posición inicial el lunes. La proyección usa avance de fechas civiles, evitando saltos por DST. Las completions existentes no se reescriben; al cambiar en mitad de semana cuentan para la frecuencia de esa semana.
- Provider y estadísticas consultan la misma secuencia; pruebas de regresión para cinco posiciones, semanas incompletas, repetición, duplicación y JSON antiguo. Pendiente CI 7/7. Identidad persistente de ocurrencias/excepciones y selección explícita al iniciar pertenecen a B; editor y presentación de semanas/estados a D. No se considera cerrado A hasta verificar CI y completar pruebas de integración/validación de edición.

## A.2 — Cierre de implementación Core (25/11)
- CI A.1 #45629921273 7/7. Se incorpora ProgramWeekPlan: slots por programa/semana local/ordinal, completadas reales, pendientes, estimación próxima semana, flexible sin fechas y sugerencia compartida por provider e insights. Se conserva la sugerencia legacy rotativa hasta que D exponga objetivo cumplido; las posiciones semanales no se sobreconsumen.
- Validación de nuevas secuencias semanales (frecuencia, referencias, catálogo único); edición sobre progreso reconciliado, puntero preservado y frontera persistente sequenceEffectiveAt contra replay retroactivo. JSON/Hive/backup/restore real con datos sintéticos y pruebas de edición, ausencia, cinco slots, calendario, límites y referencias inválidas.
- Implementación base A preparada para gate; pendientes de B: identidad persistente de ocurrencias/excepciones, atribución explícita, pausas y estados omitido/pausado. D conecta editor/planificación y estados de objetivo. Las proyecciones históricas de calendario son estimaciones; no se reescribe historial. CI nuevo pendiente, sin QA física.

## B — Motor de excepciones (entrega de implementación)
- Modelo persistente de ocurrencias, estados pending/completed/omitted/expired, pausas y vínculos explícitos workout→slot; serialización integrada en TrainingProgram/Hive/shadow y fixture backup real. Las copias/plantillas no heredan excepciones.
- Política Core: posponer, intercambiar, omitir/restaurar, recuperar/desplazar, pausas de rutinas/programa y reanudación; duración efectiva descuenta pausas totales. Rotación adaptada conserva pendientes limitados al objetivo y no acumula semanas enteras; semanal/fijo expiran pendientes al cerrar semana. Vinculación independiente no cuenta como completada. Provider y proyección leen estados; puente Mobile de inicio reserva identidad antes del draft.
- Pruebas de comandos, pausa, recuperación y atribución. Pendiente CI. UI de acciones en D; estados hero en C/D. Edición estructural: rebase de pendientes conserva pausas, historial, vínculos e identidades archivadas; se bloquea únicamente mientras exista un entrenamiento vinculado pendiente. Se libera reserva al descartar y se respeta fecha explícita de posposición flexible. D expondrá estos comandos. Posposición intersemanal semanal/fija se limita a la semana actual; recuperar deuda entre semanas exige decisión explícita posterior. No se afirma QA física.

## C — Entrenar compacto (implementación)
- Hero disponible: menú y flecha horizontales junto al nombre, sin fila Align aislada; fallback accesible para ancho pequeño/texto ampliado. Hero activo/finalizado conserva acciones y resumen; paddings verticales compactos derivados de AppUiTokens.
- Descanso: solo anuncio próximo día/rutina, sin menú/inicio ni exclusión en Mis rutinas. Core featuredRoutineId distingue anuncio de sesión destacada; pausa, objetivo cumplido y ausencia de sesión no activan fallback legacy. Prioridad activo > completado > descanso permanece.
- Mis rutinas: menú y play juntos, padding compacto y espacio entre cards reducido, fallback accesible; nombres/músculos/duración intactos. Gestión, biblioteca, barra inferior e Inicio sin cambios.
- Regresiones Core y Mobile: identidad destacada, descanso expandido, geometría de acciones, targets 48dp, anchos 320/390/430, escala, claro/oscuro/OLED, combinaciones de estilo/fuente. Pendiente CI y QA física. D seguirá con editor/modal/acciones y resolverá recuperación intersemanal.

### Corrección gate C
CI #45644200522: 6/7; Mobile tests 73/74 en Entrenar, menú de 40 dp frente a mínimo 48 dp. Se fijan targets de menú, iniciar y play en 48×48 con densidad estándar, conservando alineación horizontal y padding compacto. Regresión comprueba ambos ejes en los cuatro controles; no se desactiva ni relaja ninguna prueba. Nuevo CI pendiente.

## D — Editor y planificación adaptable
- Editor: selector rotativo/semanal para flexible/continuo, posiciones repetibles, vista previa de dos semanas y guardado compatible. Fijo conserva mapa. Modal unificado desde calendario y menú destacado, progreso y estados, previa de siguiente semana, acciones de posposición/intercambio/omisión/recuperación y pausa/reanudación. Entrenamiento independiente explícito en descanso/completado y fuera de secuencia. Recuperación de ocurrencias históricas persistidas con sustitución explícita de una pendiente (sin deuda ilimitada). Pendiente CI y QA física. Los programas legacy sin ocurrencias persistidas anteriores no pueden reconstruir con certeza una deuda histórica; no se inventa.

- D integración adicional: vista previa de secuencia calculada por Core, reportes de programas consumen slots reales en vez de calendario sintético, pausa desde gestión conserva duración, fuera de secuencia ofrece adaptar o independiente. Prueba interactiva confirma omitir/restaurar y evita completion ficticia. Pendiente CI completo y QA física.

## E — Cierre de integración y regresiones
- Base D verificada 7/7 en #45707671809. Se corrige la previsión de próxima semana en planes adaptados: si se completan posiciones disponibles, el cursor rotativo continúa; las bloqueadas o pospuestas se conservan. El rollover real conserva pendientes reales, no utiliza la estimación.
- El inicio adicional después del objetivo semanal se reserva como independiente con confirmación; el motor rechaza un vínculo de programa si el objetivo ya se alcanzó. La recuperación explícita puede usar un día libre, sin modificar el calendario habitual. No se desplazan ocurrencias reservadas. El reloj compartido alimenta el provider, y si falla el inicio se libera la reserva.
- Matriz Core de cinco combinaciones × frecuencia 1–7, slots, identidad, preview, rollover real, JSON y pausa. Pruebas de recuperación explícita y objetivo cumplido. Pendiente CI del nuevo SHA; no se afirma validación física ni firma.
- QA física: actualizar sin desinstalar, probar programa existente, sesión finalizada, descanso, ausencias, secuencias repetidas, reinicio offline y accesibilidad en iPhone/Android. La firma de IPA requiere identidad compatible; no usar datos reales en fixtures. No merge sin autorización.
