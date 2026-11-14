# STK Haven — QA para Inicio/Entrenar: mensaje, bienestar y rutinas

**Plan:** [HOME_TRAIN_LAST_MILE_UX_ROADMAP_20261113.md](../roadmap/HOME_TRAIN_LAST_MILE_UX_ROADMAP_20261113.md)  
**PR:** #57 en `STK-Haven` · **estado:** PLAN, NO IMPLEMENTADO.  
**Evidencia visual de origen:** capturas del usuario (13-11-2026) en iPhone; una card de bienestar más alta, mensaje al final, launcher de Motivation encima de la barra inferior y chips L–D no configurados en las rutinas.  
**Regla:** ninguna casilla física se completa basándose únicamente en GitHub Actions.

## A. Inicio

- [ ] Orden exacto `Tu entrenamiento → Recuperación → Mensaje de hoy → Bienestar → Actividad → Novedades` para usuarios que optaron por Fe.
- [ ] Sin Fe habilitada o con `showDailyVerse=false`: NO se muestra mensaje ni se inserta espacio vacío.
- [ ] Versículo corto/largo: máximo 2–3 líneas, referencia legible y CTA «Leer completo»; contenido íntegro en su pantalla propia.
- [ ] Pasaje loading/error: estado compacto y reintento sin bloqueo ni spinner infinito.
- [ ] Entrenamiento activo/finalizado/pendiente conserva hero y navegación; ninguna tarjeta legacy se interpone antes del Mensaje.
- [ ] Agua/Pasos horizontal: mismo ancho, **mismo alto renderizado** para ambos en la misma fila, misma posición de valor/meta/barra/footer cuando sea posible.
- [ ] Agua/Pasos vertical: altura natural y sin overflow.
- [ ] Agua: +250, +500, +750, edición de meta, recordatorios sin cambios.
- [ ] Pasos: estado de conexión, permisos denegados, «Conectar pasos», progreso superior a meta, sincronización desde sensor intactos.
- [ ] Números largos y metas largas no cortan la barra, botón ni estado; el texto no se reduce a fuentes ilegibles.

## B. Entrenar

- [ ] El pie «STK Motivation» no aparece en Entrenar cuando no hay reproducción.
- [ ] Con audio activo, Entrenar tampoco añade footer fijo; audio no se corta y el usuario accede al control mediante «+ → Motivation».
- [ ] «Mi programa» mantiene semana, plan, creación rápida y configuración avanzada; Inicio conserva su único hero diario.
- [ ] Mis rutinas: ninguna tarjeta muestra los siete círculos decorativos; los días guardados en el modelo no se eliminan.
- [ ] Rutina incluida en programa activo: se muestra el nombre del programa **real**.
- [ ] Rutina independiente: etiqueta neutra «Rutina guardada» o «Libre», sin insinuar agenda asignada.
- [ ] Rutina con/sin historia: «Última vez» y duración solo si `routineId` y tiempos históricos permiten mostrarlos; ninguna fecha o duración fabricada.
- [ ] Rutina con ejercicios sin resolver, músculos desconocidos y nombre muy largo: fallback neutro, sin error.
- [ ] Rutinas con notas, superseries, unilateral y repetidos; menú editar/duplicar/notas/eliminar, iniciar entrenamiento sin errores.
- [ ] Plan fijo, continuo, flexible, pausado, vacío: la proyección usa `TrainingProgram`, no chips opcionales de rutinas.
- [ ] Audio en background no se reinicia al cambiar pestaña.

## C. Matriz obligatoria

| Dimensión | Pruebas |
| --- | --- |
| Tamaños | 320 / 390 / 430 dp |
| Escalas | 100 / 160 / 200 % |
| Temas | Claro, oscuro, OLED |
| Acentos | Todos los 8 de `AppAccent` |
| Datos | 0 %, meta cumplida y superior, sin permiso, rutina vacía, varias rutinas, nombre largo |
| Accesibilidad | VoiceOver, TalkBack, orden de foco, contraste y tamaño de toque |
| Integridad | Persistencia de días opcionales, sesiones, historial, programas, audio y Fe sin migraciones |
| CI | Tests de disposición/navegación y 7/7 espejo; mismos SHA de blobs |

- [ ] Capturas de ambos tamaños de bienestar en dos columnas, con altura medida.
- [ ] Captura del mensaje inmediatamente después de Recuperación sin hacer scroll prolongado.
- [ ] Captura de Entrenar sin footer Motivation ni chips de semana.
- [ ] Widget tests de layout y opciones Fe.
- [ ] Tests de integración de etiquetas de pertenencia, último uso, ausencia de historial, audio persistente.
- [ ] CI espejo final 7/7, SHA canónico/espejo coincidente.
- [ ] iPhone físico: modelo/OS/build/capturas.
- [ ] Android físico: modelo/OS/build/capturas.
- [ ] Aprobación explícita de usuario antes de fusionar PR #57.

**No marcar «completado» hasta que haya código implementado, pruebas y evidencia.**
