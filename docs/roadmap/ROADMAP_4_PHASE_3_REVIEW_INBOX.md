# Coach Pro Fase 3 — bandeja operativa de revisión

Estado: implementación propuesta; requiere CI público en `STK-Haven_CI`.

## Contrato existente reutilizado

La bandeja reutiliza la RPC server-side `stk_list_coach_pro_clients` con
`p_status='active'`, `p_needs_review=true`, `p_sort='review'`, y páginas de 25.
No agrega otra función `security definer`, tablas, triggers ni nueva frontera
de autorización. El filtrado y la ordenación suceden **antes de paginar**.

## Motivos transparentes y no clínicos

El servidor determina `needs_review` cuando el entrenador tiene `view_progress`
y falta una instantánea o el último entrenamiento *compartido* no cae en la
ventana de siete días. El cliente Flutter no recalcula el corte temporal ni
concluye que hay inactividad real. Distingue:

- `progressSnapshotMissing`: falta el dato; jamás se supone inactividad.
- `lastWorkoutUnknown`: hay progreso compartido pero no una fecha.
- `lastSharedWorkoutNeedsReview`: el servidor indica revisión, y hay fecha.

Una relación pausada/revocada o sin permiso `view_progress` no muestra un
motivo, aunque el payload fuera malformado o incluyera datos de otra entidad.

## UX y ciclo de sesión

Pantalla independiente «Bandeja de revisión» desde Coach Pro. Lista paginada,
abre la ficha profesional por `relationship_id`, consulta de nuevo al volver,
redacción en carga/error/cambio de sesión, refresco y estado vacío. No persiste
datos profesionales offline ni muestra información clínica. La pantalla no
incluye acciones silenciosas de cambios de programas.

## Verificación

- Tests unitarios para tres razones distintas y los gates de consentimiento.
- Tests de widgets para 320/768/1440 px, falta de snapshot y cierre de sesión.
- Hereda la batería adversarial pgTAP de la RPC de cartera y su filtro.
- CI solo en mirror público. Sin despliegue remoto necesario en este slice.

## Pendientes siguientes de Fase 3

- Check-ins configurables y reglas de seguimiento no clínico con consentimiento.
- Escenarios de tareas recurrentes, recordatorios opt-in y revisión con estados
  persistidos auditables.
- Pruebas de dispositivo real y accesibilidad antes del cierre de la fase.
