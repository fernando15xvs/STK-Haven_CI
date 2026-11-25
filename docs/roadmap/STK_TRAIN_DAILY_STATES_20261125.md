# Entrenar — estados diarios y planificación flexible (25/11/2026)

Base: CI #45517845659 7/7, PR #57 DRAFT. Diseño aprobado: sin título superior,
hero compacto, programa con progreso semanal real, Gestionar y Biblioteca,
lista simple de rutinas y navegación inferior intacta.

- [x] Core: prioridad sesión activa > completada hoy > disponible > descanso según fecha real.
- [x] Flexible: puntero de rotación reconciliado, sin calendario obligatorio. La sesión completada
  permanece hasta el siguiente día; no se adelanta la recomendación.
- [x] Mobile: refresco de reloj local al minuto y al volver de background; mismos datos persistentes.
- [x] Rutinas: exclusión por ID del elemento destacado incluso al expandir; menú de edición en hero
  y lista, inicio manual explícito con confirmación si ya entrenó o descansa.
- [x] Planificación flexible: objetivo semanal y orden desde el puntero guardado, sin días inventados.
- [x] Biblioteca de ejercicios accesible y progreso semanal derivado del historial reconciliado.
- [x] Actualización de pruebas de contratos y regresiones de estados, rotación y lista.
- [ ] CI 7/7 del commit nuevo y QA visual en iOS/Android, incluidos texto grande, medianoche,
  notas, sesiones activas, cambios de modo y días reales.
- [ ] IPA final solo tras CI; no merge ni cambios en Web, Supabase o datos del usuario.

Decisión: se conserva el inicio manual de otras rutinas con confirmación tras completar/descansar;
no se fuerza un bloqueo global ni se modifica la regla de avance de rotación o el historial.
