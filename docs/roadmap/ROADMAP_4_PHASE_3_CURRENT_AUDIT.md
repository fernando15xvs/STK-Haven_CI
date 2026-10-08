# Coach Pro Fase 3 — estado de implementación

## Primer bloque: biblioteca de plantillas profesionales

Fuente de verdad: `fernando15xvs/STK-Haven`, rama `feat/coach-pro-phase3-templates`.
Mirror sanitizado de CI: `fernando15xvs/STK-Haven_CI`, rama `ci/coach-pro-phase3-templates`.
**No ejecutar GitHub Actions en el repositorio privado.**

### Contrato implementado (sujeto a CI)

- `stk_coach_pro_templates`: almacén privado por entrenador con RLS activada y sin permisos directos de tabla para `anon` ni `authenticated`.
- `stk_save_coach_pro_template_from_revision`: guarda una copia independiente de una revisión autorizada; nunca conserva notas personales, fecha de inicio, identificadores de cliente o estado de aceptación.
- `stk_list_coach_pro_templates`: metadatos paginados (25 por UI, 50 máximo por RPC), sin descargar prescripciones.
- `stk_assign_coach_pro_template`: valida pertenencia, Coach Pro vigente, relación activa y permiso `assign_programs`, bloquea la relación, crea una nueva asignación mediante el flujo existente y no altera programas del cliente previamente instalados.
- `stk_archive_coach_pro_template`: archiva la plantilla del entrenador, conservando asignaciones previas.
- UI: biblioteca desde dashboard y programas de cliente; guardar desde historial de revisiones; confirmaciones explícitas para archivar y asignar.
- Tests: RLS/pgTAP con adversarios, límites y preservación de campos unilaterales y descansos, además de parsing Flutter fail-closed.

### Límites y seguridad

- Fuente desde revisión existente, no desde un ejercicio suelto.
- Cien plantillas activas por entrenador.
- El entrenador no puede acceder a la biblioteca ajena aunque conozca un UUID.
- Una relación sin `assign_programs` no permite clonar hacia ese cliente.
- El cliente sigue necesitando aceptar e instalar su programa conforme al contrato existente.
- Sin cambio de billing, Smart Coach, PWA estable ni despliegue automático a Supabase remoto.

### Pendientes del resto de Fase 3

1. Editor y duplicación/actualización de plantillas con vista previa explícita y auditoría de versiones.
2. Bandeja operativa «requiere revisión» y seguimiento de tareas/check-ins configurables.
3. Recordatorios opt-in sin datos sensibles en pantalla bloqueada.
4. Escala, accesibilidad, tests completos y smoke en dispositivos reales.
5. Integración a `main` y migración remota **solo tras CI verde y revisión**.

La Fase 2 permanece cerrada como base; este documento no declara completa la Fase 3.
