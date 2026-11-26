# Nutrición A–F: desarrollo privado en el proyecto actual
Base CI #45729597528: 7/7. PR #57 draft, Web congelada.
A: build privado explícito STK_DEVELOPMENT_NUTRITION=true solo APK debug e IPA personal unsigned; producción por defecto false.
B: se aplicaron las dos migraciones legales existentes en el Supabase actual; el MCP les asignó versiones remotas 20261126004841 y 20261126004844; documentar/reconciliar historial antes de CLI db push, no reaplicar SQL. Nueva migración 20261126004951. Food Vision conserva JWT, cuotas, consentimiento por foto y redacción.
C: autorización privada 18+ por cuenta concreta, revisada por administrador, máximo 30 días, revocable, sesión viva, email confirmado; sin permiso de escritura cliente/service_role. Config por defecto OFF, sin tester real inscrito automáticamente. Al publicar política vigente se deshabilita incluso si flag activo. Activación real requiere confirmar cuenta exacta y mayoría de edad; no inferirla de un perfil editable.
D: se reutiliza planificador y medidas existentes con procedencia, confirmación de actividad y sexo de ecuación; no reiniciar onboarding ni fabricar medidas.
E: estado de prueba pendiente, retry y CTA calcular objetivo; distinción de producción y fallo de red. Mantiene adolescentes descriptivos.
F: pgTAP y tests Core/contratos; un único CI espejo pendiente. IPA personal se obtiene del CI verde; no se afirma foto real ni firma. Antes de lanzamiento deshabilitar y revocar todos los grants de desarrollo; no publicar este IPA.
