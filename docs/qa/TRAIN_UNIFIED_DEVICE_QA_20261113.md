# STK Haven — QA de Entrenar unificado (PR #57)

**13-11-2026 · Bloques A/B1/B2/C** · Fuente canónica: `fernando15xvs/STK-Haven` · CI espejo: `fernando15xvs/STK-Haven_CI`.

Este checklist **no equivale a una prueba física realizada**. Las casillas de dispositivos se mantienen pendientes hasta que una persona valide en iPhone y Android. No fusionar PR #57 sin revisión.

## Pruebas automáticas

- [x] Bloque A: duplicados, borradores, duración, fechas, fuente de programa, precedencia de días: CI espejo `43482886539` **7/7**.
- [x] Bloque B1: reorganización de Entrenar, nueva creación rápida, eliminación de «Programas» en +: CI espejo `43485873553` **7/7**.
- [ ] Bloque B2/C: CI 7/7 para responsive, plantillas, historial, tabla de series, resumen, contraste y accesibilidad.
- [ ] Revisar visualmente pantalla de Entrenar en iOS/Android y registrar evidencia reproducible.

## Escenarios de navegación

- [ ] Inicio es el **único lugar** con hero de «Tu próxima sesión» / «Continuar entrenamiento»; Entrenar NO tiene un clon.
- [ ] La pestaña Entrenar muestra **Mi programa, Mis rutinas y Plantillas**; el menú «+» no muestra «Programas».
- [ ] Se puede empezar una rutina manualmente sin crear un programa.
- [ ] Entrenar con un programa instalado en onboarding muestra su nombre, semana y calendario sin pedir configuración otra vez.
- [ ] Crear plan rápido selecciona rutinas y días; cancelar no crea nada; crear lo activa solo una vez.
- [ ] Ajustes avanzados conservan semana fija, rotación continua, flexible, duración, descarga, notas, duplicado, activación/pausa y eliminación.
- [ ] Al pausar o borrar programa, Inicio no recupera un snapshot de onboarding incompatible.
- [ ] Plantillas de rutinas y de programas son accesibles por separado y reutilizables sin destruir el plan anterior.
- [ ] Plan semanal muestra calendario del plan si está activo y días opcionales de cada rutina solo sin plan.
- [ ] Progreso conserva historial, estadísticas y evolución; Entrenar no muestra gráficos históricos duplicados.

## Seguridad de datos en entrenamiento

- [ ] Añadir **dos veces el mismo ejercicio**, reordenar, editar pesos/reps/RIR, cambiar a enfoque, cerrar y reanudar. Cada aparición conserva sus datos.
- [ ] Escribir kg/lb, reps y RIR, cambiar de ejercicio/salir antes de 500 ms, y reabrir: **nunca perder el último carácter**.
- [ ] Completar y descompletar series; izquierdo/derecho unilateral; superseries y descanso conservan estado.
- [ ] Eliminar una serie con pulsación larga y con menú visible, confirmando; no desplazar datos a otra serie.
- [ ] Mantener la aplicación en segundo plano, volver tras varios minutos y completar una sesión sin duplicación ni pérdida de historial.
- [ ] Entrenamiento 23:59→00:01 muestra día local de **finalización** en Historial/Progreso/Inicio, sin desfase.

## Responsive y apariencia

- [ ] 320 dp × escalas de texto 100/160/200 %, vertical: días, tabla peso/reps/RIR, CTA, filtros, modales sin overflow.
- [ ] 390 dp × escalas de texto 100/160/200 %, vertical: las mismas comprobaciones.
- [ ] 430 dp × escalas de texto 100/160/200 %, vertical: las mismas comprobaciones.
- [ ] Tema claro, oscuro y OLED; ejecutar con acentos azul, violeta, esmeralda, turquesa, rosa, ámbar, coral y pizarra. Contraste de campos y bordes.
- [ ] Teclado abierto/cerrado y teclado numérico: campos nunca bloqueados, cierre conserva edición; panel deslizable no oculta CTA.
- [ ] Reducir movimiento en sistema operativo: resumen no reproduce animaciones prolongadas; sin flash visual.

## Accesibilidad iOS/Android

- [ ] VoiceOver: Entrenar, calendario, chips de día, tarjetas, entradas de peso/reps/RIR, completar y eliminar serie, plantillas, acciones/descripciones.
- [ ] TalkBack: mismos escenarios, lectura y orden de foco lógico, botones con etiqueta, no depender del color ni de mantener pulsado.
- [ ] Pulsación y objetivos táctiles: días y acciones accesibles sin errores en pantalla de 320 dp.
- [ ] Orientación horizontal (si admitida por app): ningún corte ni acción inaccesible.

## Gate para revisión final

- [ ] 7/7 en última captura de Actions espejo; los SHA de cada blob modificado coinciden entre principal y espejo.
- [ ] Errores de render o análisis corregidos; registros y migraciones Hive/Supabase sin cambios destructivos.
- [ ] Prueba física iPhone con fecha, modelo, versión de iOS y captura de problemas.
- [ ] Prueba física Android con fecha, modelo, versión Android y captura de problemas.
- [ ] Aprobación explícita del usuario para fusionar PR #57; antes de eso conservarla **abierta y en borrador**.
