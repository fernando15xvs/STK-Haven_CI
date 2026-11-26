# Coach cliente + entrenador: ejecución A–H (2026-11-26)
Base: CI 45734196693 verde; PR privada #57 draft, espejo solo Actions, Web pausada.
## Entregable 1 — seguridad de sesión y cobertura
- A [ ] Activación de desarrollo: usar exclusivamente el setter de entitlement server-side existente con cuenta de entrenador permanente confirmada, tier/límite acotados y expiración; sin billing ni grant real automático. Falta identificar dos cuentas de QA.
- B [x] Progreso: purga antes de lectura, respuesta tardía descartada por identidad/revocación, rechazo de payload de otro cliente, errores sin datos antiguos.
- B [x] Relaciones: reinicio por identidad, descartar respuestas tardías de invitación/permisos/revocación, nueva carga al cambiar cuenta.
- B [x] Entitlement: consulta reactiva a identidad y refresh por invalidación. [ ] Auditar y corregir tareas/check-ins/programas/nutrición y revalidación al foreground; no declarar revocación remota instantánea de toda UI.
- C [x] Mostrar fecha de generación de resumen y reintento desde progreso. [ ] Reintentos de publicación con coalescing, sincronización de medidas explícita por permiso; evitar datos privados por defecto.
- D [ ] Centro Mi Coach: programa, tareas, check-ins, guías, progreso, permisos.
- E [ ] Integrar hub profesional, cartera, agenda y ficha sin duplicaciones.
- F [ ] Validar flujo asignar/aceptar/revisar/instalar, tareas, check-in y orientación por dos identidades, expiración y revocación.
- G [ ] Motor determinista de sugerencias explicables, sin modificar prescripción automáticamente.
- H [x] Incorporar las nueve suites móviles Coach/Coach Pro migradas al gate existente. Añadir cuatro regresiones Dart de progreso. [ ] Confirmar CI y QA física dos cuentas.
Sin cambios de base remota, flags, pagos, Web, datos personales ni merges. El último CI previo no ejecutaba estas suites móviles específicas; su resultado nuevo no se anticipa.
