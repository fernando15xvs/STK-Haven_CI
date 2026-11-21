# STK Haven — Matriz de QA física Inicio ↔ Entrenar (21/11/2026)

**Código:** PR [#57](https://github.com/fernando15xvs/STK-Haven/pull/57) · **Roadmap:** [Inicio/Entrenar](../roadmap/STK_HOME_TRAIN_SESSION_OWNERSHIP_REDESIGN_20261121.md)

> **Estado:** checklist preparado, **pruebas físicas NO ejecutadas por CI**. Un IPA sin firma Apple **no es instalable**. No desinstalar la app actual, no eliminar Hive, no restablecer onboarding y no cambiar el Apple Team ID/Bundle ID si hay datos existentes. Usar actualización firmada compatible o dispositivo de pruebas.

## Preparación común

- [ ] Guardar evidencia de la versión, build, SHA, dispositivo, OS, modo oscuro/OLED, escala de texto y reloj; tomar captura antes/después de cada flujo.
- [ ] Disponer de cuenta de prueba con rutinas existentes y, si es posible, otra sin programa; **no reutilizar ni borrar el historial real de una persona**.
- [ ] Verificar que la app existente conserve rutinas, registros por serie, medidas, notas y ajustes tras actualizar.
- [ ] No asumir que tests verdes o compilación iOS sin firmar validan reproducción multimedia, notificaciones, sensores o restauración tras cierre de proceso.

## A. Propiedad de acciones y navegación

- [ ] **Sin sesión activa:** Inicio solo muestra «Ir a Entrenar» compacto, sin la tarjeta grande «Siguiente sesión». Tocar abre **tab Entrenar** sin duplicar pantalla en Navigator.
- [ ] **Entrenar:** una hero «Siguiente sesión», una tarjeta compacta de programa, accesos Planificación/Administrar/Plantillas y la lista Mis rutinas; sin segunda vista semanal o paneles 2×2 cuadrados.
- [ ] Rutina recomendada también presente en Mis rutinas: **un único «Iniciar»** en hero; su menú editar/duplicar/notas permanece disponible.
- [ ] **Sesión activa:** Inicio ofrece «Continuar» pequeño y Entrenar muestra **Continuar** en hero; ambos reabren el **mismo ID de sesión**, sin crear copia ni perder valores.
- [ ] Navegar Inicio → Entrenar → Inicio → Entrenar, y Progreso → Entrenar: no retroceder a una ruta apilada, no reiniciar scroll ni temporizador por cambiar tab.
- [ ] Volver con gesto atrás/botón del SO desde entrenamiento activo: la sesión sigue viva y recuperable; no activar un segundo inicio.

## B. Rotación y programación

- [ ] Programa continuo de **4 rutinas / 5 sesiones por semana**: A → B → C → D → A en semana 1; la siguiente continúa B, no reinicia en A.
- [ ] Programa flexible: «sin día obligatorio», no afirmar «para hoy» si no hay fecha fija.
- [ ] Programa fijo: si la siguiente sesión es futura, mostrar su fecha, aunque hoy sea un día elegible para otra rutina; diferenciar «próximo día» de «hoy».
- [ ] Pausar programa: no recomendarlo como activo; Administrar permite reanudar sin reiniciar indebidamente su fecha.
- [ ] Reordenar A/B/C con B pendiente: conservar **B como próxima rutina**; eliminar B de la lista de un plan debe escoger la siguiente rutina superviviente, no una posición numérica arbitraria.
- [ ] Sesión fuera de secuencia: conservarla en historial, pero no adelantar la rotación ni contabilizarla retroactivamente en reconciliaciones posteriores.
- [ ] Sesión parcial (faltan series efectivas): no avanzar indebidamente la rotación; conservar el resultado en historial y Progreso.

## C. Registro, audio y continuidad

- [ ] Registrar kg/reps/RIR, unilateral izquierda/derecha, marcar/editar serie y salir/entrar; valores e ID de sesión se conservan.
- [ ] Abrir Memoria del ejercicio, cambiar ejercicio, reordenar/eliminar el seleccionado: no mostrar información de otro ejercicio.
- [ ] Activar descanso con YouTube Music/Spotify reproduciendo; bloquear pantalla, cambiar tab y volver: **la música continúa**, el contador conserva duración y no parpadea 0:00.
- [ ] Al llegar a **0:00**, eliminar/restaurar el estado de notificación nativa sin permanecer atascado; no tomar control de audio externo.
- [ ] Finalizar entrenamiento parcial/total; verificar historial, última sesión, próxima rotación y nota editable tras reiniciar app.
- [ ] Reabrir app tras suspensión y cierre del proceso por el SO: cuando hay datos persistidos deben recuperarse, sin reiniciar onboarding ni sobrescribir historial.

## D. Visual, accesibilidad y compatibilidad

- [ ] iPhone (modo claro, oscuro, OLED si corresponde), Android (oscuro/claro); anchos 320/390/430 dp equivalentes, escala de texto 100/160/200 % y distintas fuentes del SO.
- [ ] Safe areas del iPhone, teclado numérico, VoiceOver/TalkBack, todos los controles primarios ≥44 dp; chips redondeados permiten wrap, sin overflow.
- [ ] Entrenar y Inicio no repiten «Siguiente sesión», ni Progreso duplica la planificación; no aparecen etiquetas musculares repetidas.
- [ ] Con app ya instalada y datos históricos, comparar cantidad de sesiones, rutinas, medidas y referencias antes/después.

## Evidencia de cierre

Para cada prueba: dispositivo/OS/build, resultado (OK/FAIL), captura o vídeo, pasos de reproducción si falla y estado del historial. La firma iOS, pruebas de música/notificaciones, actualización sin pérdida y QA manual son **gates externos**, no sustituibles por GitHub Actions.

**No marcar un ítem como aprobado sin evidencia real en un dispositivo.**
