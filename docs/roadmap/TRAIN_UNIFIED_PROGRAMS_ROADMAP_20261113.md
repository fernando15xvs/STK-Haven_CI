# STK Haven · Entrenar unificado con Programas — Roadmap A/B/C (PR #57)

**Fecha:** 13 de noviembre de 2026
**Estado:** IMPLEMENTACIÓN EN CURSO · Bloque A implementado, B1 preparado; validación final pendiente
**PR canónica:** https://github.com/fernando15xvs/STK-Haven/pull/57
**Rama:** `fix/home-phase1-data-navigation-20261113`
**Espejo CI:** `fernando15xvs/STK-Haven_CI`, escribir solo a `main`, sin PR de espejo.

> Sustituye la propuesta anterior de Entrenar (bloques A/B/C) sin invalidar las fases 1–3 de Inicio. 
> Es un documento de planificación; no modifica widgets, modelos, persistencia ni comportamiento de producción.

## 0. Decisiones de producto — innegociables

1. **Entrenar es el único lugar para organizar rutinas y programas.** Conservar los conceptos técnicos `Routine` y `TrainingProgram`, pero no obligar al usuario a entenderlos o entrar en módulos separados.
2. **Eliminar el acceso «Programas» del botón «+»** únicamente cuando la nueva sección «Mi programa» de Entrenar esté completa y probada; conservar los otros accesos rápidos intactos. Las rutas internas o enlaces anteriores deben redirigir correctamente.
3. **No mostrar otra tarjeta «Tu próxima sesión» ni repetir «Continuar entrenamiento» en formato hero en Entrenar.** Inicio es dueño de «qué toca hoy» y de comenzar/continuar la sesión sugerida. Entrenar puede iniciar manualmente una rutina diferente desde su tarjeta, sin replicar la recomendación de Inicio.
4. **No duplicar métricas históricas** (1RM, RIR por fecha, récords, evolución, volúmenes comparativos, historial detallado): pertenecen a Progreso. Entrenar puede mostrar la planificación futura y avance *del plan*, como «Semana 3/8» o «2/4 sesiones de esta semana», sin reintroducir dashboards analíticos.
5. **Interfaz inicial mínima:** `Mi programa` (tarjeta del activo + administrar / ver calendario), `Mis rutinas` (acceso a crear, editar, iniciar manualmente), `Plantillas`. Mostrar solo estados relevantes. Sin duplicar botones de iniciar sobre un «próximo entrenamiento».
6. **Plan opcional, sin bloqueo:** entrenamiento libre y rutinas sueltas siempre funcionarán sin un programa configurado. Si existe uno instalado en onboarding se muestra directamente; no obligar a volver a configurarlo.
7. **Modo de creación simple primero:** elegir rutinas, frecuencia/días, revisar y activar. Modos de rotación continua, semana fija, flexible, duración del mesociclo, descarga, detalles de frecuencia y edición avanzada en ajustes secundarios, conservando capacidades actuales.
8. **Una fuente de verdad para el programa activo:** `TrainingProgram`/`activeTrainingProgramProvider` y `nextProgramSessionProvider`. Mantener lectura y migración compatible de `SettingsState.activeProgram`/`ActiveProgramState` heredado hasta verificar que onboarding, Inicio y planes no se contradicen; migración no destructiva.
9. **Preservar datos:** IDs de rutinas/sesiones, conjuntos de ejercicios, series/peso/reps/RIR, notas, superseries/unilateral, progreso del plan, plantillas y calendario existente. No borrar históricos ni reiniciar la rotación de programas al reorganizar la UI.
10. **Una sola PR #57**, sin fusionar, cerrar ni generar IPA salvo instrucción expresa. Enviar el código para CI al espejo, no abrir PR de espejo, exigir paridad y 7/7 antes de dar por terminado cada bloque de implementación.

## 1. Mapa de responsabilidad de pantallas

| Dominio | Inicio (hoy) | Entrenar (organizar) | Progreso (analizar) |
| --- | --- | --- | --- |
| Próxima sesión recomendada | **Tarjeta y acción** | **No duplicar** | No |
| Entrenamiento en curso | Continuar desde el hero | Sin hero duplicado; acceso contextual solo si indispensable | No |
| Programa activo | No añadir otra tarjeta de administración; conservar únicamente el contexto mínimo existente si aporta información distinta | **Tarjeta «Mi programa», estado, semana, calendario y editar** | Análisis histórico del desempeño |
| Rutinas | Acceso desde sesión sugerida | **Listado y operaciones CRUD; inicio manual** | Resultados asociados |
| Calendario | Solo orientación de hoy | **Calendario futuro y distribución del plan** | Calendario y sesiones realmente completadas |
| Plantillas | No | **Selección/instalación y edición posterior** | No |
| Peso/reps/RIR y 1RM por fecha, PR, volúmenes | No | Captura en entrenamiento activo, sin gráficos históricos | **Gráficos, evolución e historial** |

Reglas de precedencia: si hay plan activo, el calendario visible de Entrenar deriva de `TrainingProgram` (modo fijo/continuo/flexible), no de los `Routine.scheduledDays` opcionales; si no hay plan, estos últimos pueden presentarse claramente como «programación opcional de rutinas».

## 2. Bloque A — correcciones funcionales + seguridad para unificar

**Objetivo:** resolver defectos preexistentes y fijar contratos de estado antes de mover la navegación. **No rediseñar pantallas en este bloque.**

- [x] A1. Instancias duplicadas de un mismo ejercicio en sesión: reemplazar las keys `ValueKey(exerciseId)` de `ReorderableListView` por identidad única de *instancia* estable, sin alterar IDs canónicos del catálogo ni datos históricos. Pruebas de duplicado/reordenación/edición/enfoque.
- [x] A2. Duración del plan: al «Duplicar semana actual», no asignar a `durationWeeks` valores imposibles para el `DropdownButtonFormField` (lista actual 4/6/8/10/12/16/20/24); definir si duplicar semana es una operación real o simplemente extender duración. Evitar prometer duplicación que no se hace. Pruebas de límites.
- [x] A3. Borradores de series: guardar o drenar edición pendiente (500 ms debounce) antes de navegación, reordenación, eliminación de serie, cambio a modo enfoque, cierre/finalización y `dispose`. No sobrescribir series completadas; pruebas de cambios rápidos de kg/lb, reps, RIR y teclado.
- [x] A4. Fechas de entrenamientos nocturnos: unificar criterio de fecha local en Historial de ejercicios, tarjeta de Inicio, calendario y Progreso (fecha de inicio vs fecha de finalización según significado explícito). Pruebas 23:59→00:01 y cambios de zona horaria.
- [x] A5. Asegurar fuentes de verdad: documentar/implementar compatibilidad entre `TrainingProgram`, `nextProgramSessionProvider`, `SettingsState.activeProgram` y el onboarding. Garantizar que Inicio y Entrenar muestran el mismo programa vigente y progreso, también al activar, pausar, cambiar o eliminar; sin duplicaciones ni migraciones destructivas.
- [x] A6. Días opcionales de rutina frente a calendario real de programa: precisar precedencia en lógica y tests de semana fija, rotación continua y flexible; distinguir días de descanso y sesiones libres fuera de secuencia.
- [x] A7. Pruebas de regresión para preservar notas, rutinas, ejercicios, superseries, datos unilaterales, sesiones incompletas/continuación, recordatorios y historial tras editar un programa.
- [ ] A-GATE. Core + mobile tests del bloque A; CI 7/7 en espejo; revisar diffs y paridad; **sin merge**.

## 3. Bloque B — unificación de Entrenar + diseño profesional

### B1. Arquitectura y navegación (antes del pulido estético)

- [x] B1.1. Convertir la pestaña 1 en un único `Entrenar`: `Mi programa` → `Mis rutinas` → `Plantillas`. Conserva el estado de pestaña/scroll y navegación de `IndexedStack`.
- [x] B1.2. `Mi programa`: plan activo, nombre, semana X/Y, frecuencia/avance *de planificación*, acceso a «Ver planificación» y «Administrar». Si no hay programa, estado opcional «Organiza tus rutinas» / «Crear un plan», sin bloquear «Mis rutinas».
- [x] B1.3. «Ver planificación»: próximas sesiones estimadas/calendario del programa, descanso y distribución de rutinas; el calendario sigue el modo real del programa. No renderizar historiales/comparativas ni duplicar la tarjeta de Inicio.
- [x] B1.4. «Administrar programa»: crear, seleccionar/activar, pausar, cambiar, editar, duplicar y usar plantillas. Pantallas o sheets secundarias en lugar de una card infinita. Acciones destructivas con confirmación y sin borrar sesiones previas.
- [x] B1.5. «Crear plan» sencillo: elegir una o más rutinas, frecuencia/días, revisar/activar. Valores automáticos razonables sin pedir más campos; ajustes avanzados colapsados para rotación/modo, duración, descarga, calendario fijo y notas. Mantener posibilidad de editar luego.
- [x] B1.6. «Mis rutinas»: crear/editar/duplicar/borrar, iniciar **manualmente** cualquier rutina e ir a biblioteca de ejercicios. Mantener notas, superseries, preparación/unilateral y ejercicios personalizados. Evitar fusionar dos modelos de persistencia.
- [x] B1.7. «Plantillas»: plantillas de rutina y programa bajo el mismo flujo de Entrenar, diferenciadas con etiquetas claras. Conservar las plantillas existentes y las instaladas en onboarding.
- [x] B1.8. Eliminar «Programas» del `+` solo después de poner la nueva ruta de administración en Entrenar; mantener Coach, Hábitos, Biblia, Haven Faith, Nutrición, Motivation y Herramientas según permisos actuales; ninguna nueva pestaña inferior.
- [x] B1.9. Redirigir los enlaces antiguos que abrían `TrainingProgramsPage` a la nueva administración unificada. No dejar rutas huérfanas, saltos circulares ni dos pantallas de edición competidoras.
- [ ] B1-GATE. Tests de navegación Inicio→Entrenar→Programa/Rutina y de deep links, estados sin programa/con programa/pausado, programa del onboarding y workout activo, CI 7/7.

### B2. Pulido visual consistente con Inicio y Progreso

- [ ] B2.1. Aplicar `AppTypography`/Outfit, `AppSpacing`, `AppColors`, `PremiumCard`, acciones primarias y patrones de navegación a Entrenar, editores, plantillas, biblioteca, detalle, historial, programa, modales, calculadora y resumen.
- [ ] B2.2. Rediseñar editor de rutinas y plan: campos legibles, secuencia de acciones, selección de días adaptable, agrupación de configuración avanzada, guardado/cancelación claros y prevención de pérdida de cambios.
- [ ] B2.3. Entrenamiento activo: cabecera sobria, acciones secundarias agrupadas sin saturación, datos de series peso/reps/RIR distinguibles con 320 dp, enfoque accesible, estados completados y descanso; no ocultar controles operativos.
- [ ] B2.4. Resumen final: primero lo registrado (tiempo, series, volumen, récords de esa sesión), después detalles opcionales; enviar comparativas históricas y análisis profundos a Progreso, evitando sección duplicada.
- [ ] B2.5. Plantillas, filtros y páginas de ejercicios: jerarquía coherente, botones de contacto accesibles, filtros progresivos y estados vacíos claros; preservar ficha técnica y demostraciones válidas sin reemplazos de medios.
- [ ] B2.6. Inicio **no** gana una segunda tarjeta/programa de gestión; revisar que su tarjeta de próxima sesión sea el único hero «qué entrenar hoy». Entrenar **no** muestra un clon de esa tarjeta.
- [ ] B2-GATE. Golden/widget tests o inspección equivalente de pantallas clave; contraste/typography consistente; CI 7/7.

## 4. Bloque C — accesibilidad, rendimiento y QA final

- [ ] C1. Pruebas de 320 / 390 / 430 dp y escalado 100 / 160 / 200 %, retrato y rotación si corresponde; ningún `RenderFlex overflow`, corte de fechas, pesos, reps, RIR, dropdowns ni CTA.
- [ ] C2. Temas claro/oscuro/OLED y todas las variantes de acento; texto legible, bordes visibles, sombras discretas, color sin ser único significado del estado.
- [ ] C3. VoiceOver / TalkBack: orden de foco, etiquetas y roles de botones de completar serie, borrar serie (alternativa a pulsación larga), días de la semana, menú, chips y estados de planificación. Tap targets mínimos razonables.
- [ ] C4. Teclado: evitar pérdidas y cambios de formato durante edición; desplazamiento seguro con teclado, sheets y dialogs; cierre/cancelación preserva borradores según política.
- [ ] C5. Motion y modos de rendimiento: reduce motion en resumen, animaciones y despliegues; no computar volúmenes/proyecciones pesados por rebuild en listas de programas sin necesidad; monitorear sesiones de larga duración.
- [ ] C6. Regresión de sesiones largas/nocturnas, superseries, unilateral, continuación de sesión incompleta, 2 rutinas con ejercicios repetidos, cambio entre kg/lb, activación de programa, pausa, borrado y onboarding preexistente.
- [ ] C7. Revisar redundancia entre Inicio/Entrenar/Progreso sobre capturas de interfaz finales. Si dos pantallas muestran exactamente la misma función, asignar propiedad a una y dejar solo navegación contextual donde sea necesaria.
- [ ] C8. Pruebas de widgets + Core + mobile + integridad de histórico; compilar Android e iOS. Sin modificación de migraciones Supabase a menos que un error probado requiera revisión y autorización.
- [ ] C9. Sincronizar **blobs de código** canónico/espejo, 7/7 controles obligatorios verdes en `STK-Haven_CI`. No PR de espejo; no ejecutar Actions en el repositorio canónico.
- [ ] C10. QA físico iPhone/Android: navegación, teclado, accesibilidad, sesiones reales, días programados/descanso y carga prolongada.
- [ ] C11. Revisar la PR #57, conservarla abierta y en borrador hasta autorización explícita del usuario para fusionar.

## 5. Criterios de aceptación end-to-end

- [ ] Desde cero se puede crear rutina y empezar a entrenar **sin** crear programa.
- [ ] Desde onboarding se presenta automáticamente el programa ya instalado, sin pedir que vuelva a configurarlo.
- [ ] Una persona con rutinas existentes puede crear plan con selección + frecuencia/días y guardarlo sin entrar en «Opciones avanzadas».
- [ ] Un usuario avanzado puede editar semana fija, flexible, continua, duración, descarga, rotación, notas, plantillas y reordenación como antes.
- [ ] No existe «Programas» en el menú `+`, y todo su contenido útil tiene acceso lógico desde Entrenar.
- [ ] Inicio sigue siendo el único lugar donde se muestra la **próxima sesión recomendada como tarjeta hero**. Entrenar no repite ese bloque, pero permite iniciar manualmente otra rutina.
- [ ] Entrenar muestra el calendario del programa activo de manera coherente; los días opcionales de las rutinas no contradicen esa agenda.
- [ ] Progreso conserva los análisis de resultados; Entrenar no los duplica.
- [ ] No se pierde un set editado rápidamente, ni se bloquea la lista reordenable al repetir ejercicios, ni falla duplicar semana.
- [ ] Notas, historial, series, PR, programas existentes, rotación y plan del onboarding no se pierden.
- [ ] La interfaz conserva patrón Outfit, tokens, accesibilidad, responsive y temas en todas las pantallas visitables desde Entrenar.
- [ ] CI espejo 7/7, QA de dispositivo documentado; PR única #57 sin merge hasta aprobación.

## 6. Orden de ejecución y reglas del proyecto

**Orden:** A (integridad funcional) → B1 (unificación de producto y navegación) → B2 (uniformidad visual) → C (accesibilidad, rendimiento y QA final). Verificar paridad y CI tras cada entrega de código.

**Repositorios:** `fernando15xvs/STK-Haven` = fuente canónica; `fernando15xvs/STK-Haven_CI` = espejo de Actions. Todos los cambios se acumulan en la rama existente de la PR #57. No crear otra PR. El espejo recibe snapshot directo en `main`. No fusionar la PR hasta autorización expresa.

**Registro de ejecución:** el usuario autorizó implementar. A1–A7 están en código y tests; su gate 7/7 está pendiente del trabajo Android de CI. B1 está preparado para desplegarse a la rama y validarse; B2/C aún no están finalizados. PR #57 no se fusiona sin autorización.
