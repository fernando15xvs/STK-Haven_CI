# Inicio — bienestar diario (25/11/2026)
Base CI #45716144817 7/7. Entrega única, PR #57, espejo CI, Web intacta.
- Inicio: espacios consistentes, encabezado Bienestar compacto con Nutrición accesible, padding inferior 24dp, Agua/Pasos de igual altura con padding compacto. Retira Actividad semanal y Finalizado hoy de Inicio, deja solo acceso a sesión activa y último entrenamiento/récord en Novedades. No elimina datos ni cambia Entrenar/Progreso.
- Sueño: diario manual por fecha de despertar, meta personal opcional, edición/borrado/historial y respaldo local existente. La calidad permanece en check-in; no hay lectura de sensores ni diagnóstico. No se solicitan permisos nuevos.
- Mis hábitos: reutiliza perfil habitsEnabled, HabitTasks y completions; muestra hasta tres tareas de hoy y progreso real; tareas con tiempo o de entrenador abren gestor, no inventa minutos. Ocultar no elimina registros.
- Editar perfil: controles de Sueño/Hábitos y versículo; elimina interruptor duplicado en Ajustes, conserva favoritos y notificaciones. Desactivar Fe no destruye la preferencia del versículo; reactivar respeta valor guardado.
- Nutrición: conserva acceso, sin suma ficticia de calorías. Los análisis de platos existentes no son un diario de consumo; no se añade tarjeta de consumo. Pruebas Core, backup y contratos UX; pendiente CI y QA física.

## Accesos rápidos (+) — corrección de contraste
Base #45721441235 7/7. Se conserva el menú circular y todas sus rutas/condiciones. Scrim negro 70% claro / 65% oscuro, texto blanco independiente de acento, tipografía compartida 13dp, dos líneas normales y adaptación sin recorte con texto ampliado. Tres columnas normales, menos con accesibilidad, scroll acotado al espacio seguro. Pruebas de contraste AA incluso sobre blanco, ocho acentos, claro/oscuro/OLED, anchos 320/390/430 y escala 100/160/200%. Pendiente CI único y QA física. No cambios en navegación inferior, Core, Web ni datos.
