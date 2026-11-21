# STK Haven — Roadmap: Entrenar como centro de acción, Inicio sin duplicaciones
**Fecha:** 21/11/2026 · **Estado:** Inicio y Entrenar implementados, CI inicial 7/7 verde; regresiones adicionales de fechas/estado activo pendientes de nueva ejecución y QA física · **PR canónica:** [#57](https://github.com/fernando15xvs/STK-Haven/pull/57)

## Decisión aprobada y sustitución de la regla antigua

**La tarjeta principal «Siguiente sesión» se mueve de Inicio a Entrenar.**
El usuario ha aprobado también que **Inicio solo tenga un acceso pequeño «Continuar entrenamiento» cuando haya una sesión activa**, o como máximo un enlace discreto «Ir a Entrenar» cuando no la haya. No presentar en Inicio otra hero card de sesión, un gran botón «Iniciar», ni la lista de rutinas.

**Este contrato sustituye específicamente la asignación anterior de responsabilidades del documento `TRAIN_UNIFIED_PROGRAMS_ROADMAP_20261113.md` (B2.6 y criterios de aceptación), que exigía que Inicio fuera dueño de la hero y prohibía «Siguiente sesión» en Entrenar.** Actualizar esos criterios, sus tests y QA durante la implementación; no aceptar verde un test de la decisión antigua. Mantener las demás reglas de integridad del roadmap anterior.

### Fuente única de verdad

- Selección de próxima sesión desde `nextProgramSessionProvider` y estado real `activeWorkoutProvider`; nunca inventar «Upper B», días, grupos o duración a partir del wireframe.
- `TrainingProgram` gobierna calendario y rotación; no inferir asignaciones a partir de `Routine.scheduledDays` cuando existe programa activo.
- `WorkoutLauncher.launch(context, ref, routine)` inicia una rutina. `ActiveWorkoutPage` reanuda una sesión existente. No lanzar una nueva sesión mientras existe otra activa.
- Conservar la lógica de recordatorio de sesión inacabada, persistencia Hive, historial, progreso del programa, pausa/reanudación, 15+ y Supabase. **Sin migraciones de BD ni reinicio de onboarding.**
- No duplicar funciones de Progreso (gráficos/historial profundo), Inicio (bienestar, recuperación, mensaje del día), ni herramientas de entrenamiento activo.

## Distribución definitiva por pantalla

| Pantalla | Único contenido propio | Navegación contextual permitida | No mostrar |
| --- | --- | --- | --- |
| **Inicio** | Salud del día, recuperación, bienestar, mensaje y actividad según opciones del usuario | **Solo si hay sesión en curso:** fila/chip pequeño «Continuar entrenamiento» que vuelve a la misma sesión; si no, enlace discreto «Ir a Entrenar» opcional | Hero «Siguiente sesión», botón grande «Iniciar», calendario, lista o administración de rutinas |
| **Entrenar** | **Hero «Siguiente sesión»** con CTA «Iniciar» o «Continuar» si hay sesión activa; programa compacto, accesos a planificación/administración/plantillas, «Mis rutinas» | Gestión de plan y rutinas, entrenamiento activo | Historial o gráficas de Progreso; duplicado grande de vista semanal; bloque de bienestar/recuperación |
| **Planificación** | Semana estimada/fija, rotación y descansos, con distinción entre días reales y orientativos | Editar en Administrar | Segunda hero «Siguiente sesión» |
| **Administrar** | Cambiar/crear/pausar/reanudar plan, editar, reordenar rutinas | Volver a Entrenar o Planificación | Repetir el mismo resumen de semana en varias tarjetas |
| **Plantillas** | Rutinas predefinidas y programas guardados, como categorías diferenciadas | Instalar o crear copia editable | CTA duplicado de próxima sesión |
| **Progreso** | Estadísticas, historial, gráficos, comparación por fechas | Acceso desde contextos puntuales | Otra pantalla de planificación o botón principal de inicio de rutina |

### Orden de contenido en Entrenar (sin cuadrícula 2×2)

1. Encabezado sobrio **«Entrenar»**, sin subtítulo «Tu entrenamiento de hoy» ni duplicar título del tab inferior.
2. **Hero principal** «Siguiente sesión» con nombre real, cantidad de ejercicios, músculos válidos y tiempo **solo cuando exista una estimación sustentada**. Un botón destacado **«Iniciar»**. Si hay sesión activa, sustituir la hero por **«Entrenamiento en curso — Continuar»** y enlazar a la sesión existente.
3. **«Mi programa» compacto**, de una o dos líneas: nombre, semana X/Y, estado y progreso. Toda configuración detallada vive en Administrar.
4. Accesos ligeros, redondeados y sin cuatro cards cuadradas: **Planificación · Administrar · Plantillas**. En 320 dp / texto 200% admitir wrap o scroll horizontal accesible (no recortar ni convertirlos en tarjetas gigantes).
5. **«Mis rutinas»** como lista vertical compacta: nombre, ejercicios, grupos musculares únicos normalizados, fecha real de último uso, duración habitual solo si hay datos suficientes, menú editar/duplicar/notas/borrar. CTA «Nueva».
6. **No duplicar el CTA de la hero**: si la rutina sugerida también aparece en la lista, mantener su ficha y operaciones pero no un segundo botón «Iniciar» prominente para la misma acción; usar «Detalles» o presentación pasiva según diseño final.
7. No añadir una segunda tarjeta «Vista semanal» al final: el resumen semanal detallado está en Planificación. Si se usa «Ver todas», solo cuando realmente se haya limitado la lista; nunca mostrar navegación inerte.
8. Respetar **Outfit, AppTypography, AppColors, AppSpacing, iOS safe areas, light/dark/OLED** y el estilo existente STK Haven. El wireframe en gris/claro es **conceptual**, no autorización para transformar la app a tema claro.

## Estados y transiciones obligatorias

- **Sesión activa**: Entrenar muestra «Continuar» como única hero; Inicio muestra solo un enlace compacto a **la misma sesión**, sin nuevo `WorkoutLauncher`. Si la sesión es antigua, mantener mensaje prudente «Pendiente de revisar» y posibilidad de continuar o finalizar dentro de la pantalla activa.
- **Programa activo sin sesión**: Entrenar muestra la próxima rutina conforme al motor de programación. En modo flexible no afirmar que existe un día obligatorio o que hoy «toca» por calendario.
- **Día de descanso en modo fijo/continuo**: distinguir «Próxima sesión» de «Entrenar hoy» y no falsificar asignación; permitir gestionar o iniciar una rutina manual por separado.
- **Programa pausado**: no proponer como próxima sesión activa una rutina del programa pausado; «Reanudar» corresponde a Administrar; lista de rutinas sigue siendo utilizable.
- **Sin programa, con rutinas**: permitir iniciar manualmente cualquiera; el espacio hero puede ofrecer «Elige una rutina», sin inventar recomendaciones.
- **Sin programa ni rutinas**: estado vacío útil «Crear rutina / Explorar plantillas» y opción Crear plan solo cuando sea viable.
- **Sesión completada hoy**: no repetir hero de siguiente sesión en Inicio; conservar historial/edición de notas por acceso apropiado y, si se necesita, una confirmación muy pequeña sin duplicar Progreso.
- **Rutina sugerida eliminada, duplicados o datos legacy**: resolver por ID válido, mostrar fallback claro, no perder datos de sesión ni corromper siguiente índice de rotación.

## Bloque 0 — Contrato y pruebas ANTES de mover UI

- [x] 0.1. Actualizar `train_unified_navigation_contract_test.dart`: ahora **sí** debe haber hero de próxima sesión en Entrenar; Home no la muestra. Evitar invertir la expectativa sin añadir nuevos tests.
- [x] 0.2. Actualizar QA y el criterio de propiedad de `TRAIN_UNIFIED_PROGRAMS_ROADMAP_20261113.md` y documentación asociada; marcarlo sustituido **solo para este punto**.
- [ ] 0.3. Tests de fuente única: sesión activa gana al programa; plan flexible/fijo/continuo/pausado; sin programa; sin rutinas; retomar sesión por ID; navegación real desde el dock.
- [x] 0.4. No iniciar dos veces la misma sesión por toques repetidos, ni duplicar la CTA de la rutina destacada en la lista.

## Bloque A — Inicio compacto (sin clones)

- [x] A1. Retirar `_TodayRoutineCard` y la hero grande programada del `DashboardPage`. No perder el cálculo canónico: reusar el provider en Entrenar.
- [x] A2. Reemplazar `_ActiveWorkoutHero` grande por una **fila pequeña** solo en sesión activa, con nombre breve, estado y «Continuar». Mantener recordatorio de sesión inacabada.
- [x] A3. Si no hay sesión activa, acceso opcional discreto `Ir a Entrenar`, enlazado a la **pestaña 1 del HomeScreen**, no a una pantalla duplicada apilada; exponer callback o proveedor de navegación seguro.
- [x] A4. Reordenar con cuidado para que Recuperación, Mensaje del día (solo Fe opt-in), Bienestar y Actividad no pierdan jerarquía ni funcionen distinto. No borrar historial/recent PR, nutrición ni otras secciones validadas.
- [ ] A5. Probar acceso a Entrenar desde Inicio, vuelta al scroll, y continuidad de cronómetro/música al cambiar pestaña.

## Bloque B — Entrenar como destino central

- [x] B1. Construir hero real en `RoutinesPage` con `activeWorkoutProvider`, `nextProgramSessionProvider`, `WorkoutLauncher` y `ActiveWorkoutPage`; fallback ante rutina ausente y no inventar datos del wireframe.
- [x] B2. Compactar `_ProgramOrganizerCard`: programa, semana, estado y progreso. Sacar botones de Planificación/Administrar hacia la fila compartida de accesos.
- [x] B3. Ordenar contenido **hero → programa compacto → accesos → Mis rutinas** (no secciones repetidas) con tarjetas suaves y listas más densas, sin 2×2 de paneles cuadrados.
- [x] B4. Evitar dos acciones principales para la misma rutina; conservar inicio manual y CRUD para las demás. Corregir nombres musculares repetidos y etiquetas vacías.
- [x] B5. «Mis rutinas» expone todas o sección «Ver todas» funcional; crear rutina sigue disponible sin crear un programa.
- [x] B6. Accesos Planificación, Administrar y Plantillas conservan rutas existentes, sin pantallas o CTAs huérfanos.

## Bloque C — QA de diseño, lógica e integridad

- [ ] C1. Tests widget/golden: **320/390/430 dp**, texto **100/160/200%**, claro/oscuro/OLED, 8 acentos, teclado, VoiceOver/TalkBack y controles 44+ dp.
- [ ] C2. Pruebas integración Inicio → Entrenar → Iniciar → editar serie → Continuar desde Inicio → finalizar → rotación siguiente; preservar IDs, Hive, historial, planes y sin onboarding repetido.
- [ ] C3. Escenarios: pausado, sin programa, sin rutinas, rest day, plan flexible, 4 rutinas/5 sesiones por semana, completed today, cambios rápidos y reinicio de proceso conservando estado persistido.
- [ ] C4. Sin duplicados: ninguna hero grande en Inicio, una sola hero en Entrenar, no «Vista semanal» repetida, ni CTA «Iniciar» doble para sugerida.
- [ ] C5. Revisar paridad exacta de blobs canónico/espejo, **7/7 checks verdes del último SHA** en `STK-Haven_CI`. No crear PR de espejo ni fusionar la #57.
- [ ] C6. Prueba física iPhone/Android de navegación, safe area, scroll, rendimiento y continuidad de música/temporizador; CI no sustituye QA física.

## Registro de implementación inicial — 21/11/2026

- Inicio: se eliminó el hero de próxima sesión, se añadió el enlace de pestaña `home_open_train` y la continuación compacta `home_continue_workout`. «Finalizado hoy» se encuentra ahora como fila discreta en Actividad, con el mismo acceso al resumen y notas, sin alterar datos.
- Entrenar: `NextTrainingSessionHero` consume `nextProgramSessionProvider` / `activeWorkoutProvider`, con retorno seguro a sesión existente, sin recomendaciones inventadas. Compatibilidad conservada con el onboarding antiguo cuando no hay programas modernos mediante `legacyTodaySessionProvider`.
- Rutinas: la sugerida no muestra un segundo CTA de Inicio; tarjetas se mantienen editables, notas y menú disponibles. Programas se resumen en una tarjeta compacta; accesos ligeros a planificación, administración, plantillas y creación de plan si corresponde.
- Tests: contratos actualizados de Inicio/Entrenar, nuevos widget tests de hero a 320/390/430 dp y escala 100/160/200 %, estados sin programa ni rutinas, decisión de rotación flexible. **Estos tests no sustituyen VoiceOver/TalkBack ni dispositivo real.**
- Esta implementación **no modifica Supabase, Hive, datos guardados, programa de usuario ni PR fuera de #57**.

## Segundo bloque de QA — sesiones previstas y estados de navegación

- [x] Confirmado **7/7 verde** para el commit anterior del espejo `b353fcc893121b16c6f9d043ee82bbd7df6e51cf` en [CI #44941475923](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/44941475923). Este resultado no valida automáticamente los commits nuevos.
- [x] Nueva clase pura `NextTrainingSessionLabel`: distingue fecha real de la siguiente sesión de «día elegible para entrenar». Soluciona la etiqueta errónea **«hoy»** cuando la siguiente sesión es en otra fecha. No toca la lógica de la rotación ni escribe en Hive.
- [x] Pruebas deterministas de etiquetas: día actual, futuro, flexible, fecha sin asignar y distintas horas del mismo día.
- [x] Pruebas de widget: sesión activa tiene prioridad sobre la sugerida y reemplaza «Iniciar» por «Continuar»; modalidad fija con fecha futura no muestra «hoy», incluso si `isTrainingDay` señala true.
- [x] Matriz de visualización de hero ampliada a **320/390/430 dp × 100/160/200 % × claro/oscuro**, sin usar una cuenta de usuario ni su base de datos.
- [ ] Revisar nueva ejecución CI 7/7, confirmar paridad de blobs tras los nuevos cambios y actualizar checklist si pasa.
- [ ] Validar en equipos reales el salto Inicio → Entrenar y la música/notificaciones al reanudar.

## Criterios de aceptación

- [ ] Inicio mantiene solo **«Continuar entrenamiento» compacto** cuando hay una sesión activa; o un acceso opcional pequeño «Ir a Entrenar» cuando no la hay. Sin gran hero ni «Siguiente sesión».
- [ ] Entrenar posee la **única tarjeta principal de Siguiente sesión** y el CTA primario correspondiente; en sesión activa, la misma superficie se convierte en «Continuar».
- [ ] Los estados actuales de programas, sesiones y datos legacy siguen correctos; una persona con datos anteriores **no repite onboarding ni pierde registros**.
- [ ] La UI se parece a la estética profesional de STK Haven y no al grid de cuatro paneles cuadrados del boceto rechazado.
- [ ] No hay duplicación funcional Inicio/Entrenar/Progreso ni dentro de Entrenar.
- [ ] El usuario aprueba la interfaz después de ver wireframe final adaptado al modo oscuro antes de cambios de implementación si solicita otra revisión.
- [ ] PR única #57 revisada; CI 7/7 verde en espejo y QA física documentada antes de publicar o fusionar.

## Regla de ejecución

1. Código en `fernando15xvs/STK-Haven`, rama existente de PR #57. 2. Documentos y blobs afectados sincronizados a `fernando15xvs/STK-Haven_CI/main`, sin PR extra; **el espejo solo ejecuta Actions**. 3. La PR sigue en borrador, sin merge sin autorización explícita. 4. Sin despliegues de Supabase ni alteraciones de producción por este rediseño.

**Implementación de Inicio/Entrenar realizada en la PR #57. Quedan pendientes los controles manuales y las comprobaciones marcadas en este documento.**
