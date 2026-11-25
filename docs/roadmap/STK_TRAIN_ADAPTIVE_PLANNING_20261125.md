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
- [ ] A Motor de planificación.
- [ ] B Excepciones.
- [ ] C Entrenar compacto.
- [ ] D Editor y planificación.
- [ ] E Regresiones, QA física y artefactos.

## A.1 — Secuencia semanal y compatibilidad (implementación preparada)
- Se incorpora ProgramSequencePolicy rolling/weekly y lista separada de posiciones semanales (IDs repetibles), con valores legacy rotativos, copia/plantillas/JSON y shadow de respaldo existentes. El modo fijo ignora la política semanal.
- Reconciliación y proyección respetan la semana local: rotación continua conserva puntero, repetición semanal vuelve a posición inicial el lunes. La proyección usa avance de fechas civiles, evitando saltos por DST. Las completions existentes no se reescriben; al cambiar en mitad de semana cuentan para la frecuencia de esa semana.
- Provider y estadísticas consultan la misma secuencia; pruebas de regresión para cinco posiciones, semanas incompletas, repetición, duplicación y JSON antiguo. Pendiente CI 7/7. Identidad persistente de ocurrencias/excepciones y selección explícita al iniciar pertenecen a B; editor y presentación de semanas/estados a D. No se considera cerrado A hasta verificar CI y completar pruebas de integración/validación de edición.
