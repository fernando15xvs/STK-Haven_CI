# Nutrición A–F: desarrollo privado en el proyecto actual
Base CI #45729597528: 7/7. PR #57 draft, Web congelada.
A: build privado explícito STK_DEVELOPMENT_NUTRITION=true solo APK debug e IPA personal unsigned; producción por defecto false.
B: se aplicaron las dos migraciones legales existentes en el Supabase actual; el MCP les asignó versiones remotas 20261126004841 y 20261126004844; documentar/reconciliar historial antes de CLI db push, no reaplicar SQL. Nueva migración 20261126004951. Food Vision conserva JWT, cuotas, consentimiento por foto y redacción.
C: autorización privada 18+ por cuenta concreta, revisada por administrador, máximo 30 días, revocable, sesión viva, email confirmado; sin permiso de escritura cliente/service_role. Config por defecto OFF, sin tester real inscrito automáticamente. Al publicar política vigente se deshabilita incluso si flag activo. Activación real requiere confirmar cuenta exacta y mayoría de edad; no inferirla de un perfil editable.
D: se reutiliza planificador y medidas existentes con procedencia, confirmación de actividad y sexo de ecuación; no reiniciar onboarding ni fabricar medidas.
E: estado de prueba pendiente, retry y CTA calcular objetivo; distinción de producción y fallo de red. Mantiene adolescentes descriptivos.
F: pgTAP y tests Core/contratos; un único CI espejo pendiente. IPA personal se obtiene del CI verde; no se afirma foto real ni firma. Antes de lanzamiento deshabilitar y revocar todos los grants de desarrollo; no publicar este IPA.

## Corrección del gate móvil (25/11/2026)
- El snapshot a5b12c6 sustituyó por error el workflow móvil por una plantilla histórica. El CI #45731552432 registró 668 errores de análisis exclusivamente Web y 52 fallos Mobile (pruebas 3D históricas sin GLB y un test de Aspecto fuera de viewport).
- [x] Restaurar el workflow de #45729597528, incluyendo análisis Core/Mobile separados, guard de arquitectura, QA anatómica v10, pruebas focalizadas, Supabase aislado y 3D histórico manual. Web sigue congelada, sin tests, análisis ni builds Web ni web-push en el gate.
- [x] Mantener STK_DEVELOPMENT_NUTRITION únicamente en el APK debug y la IPA de QA sin firma; release Android y profile mantienen OFF. Sin cambiar autorización de backend ni activar usuarios.
- [x] Corregir el scroll del test de Aspecto y ejecutarlo también en el gate de Perfil.
- [ ] Confirmar los siete jobs obligatorios del nuevo CI y QA física. No merge ni publicación.
