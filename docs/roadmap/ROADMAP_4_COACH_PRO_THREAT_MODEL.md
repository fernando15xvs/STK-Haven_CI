# STK Haven — Roadmap 4 Coach Pro Threat Model

**Fecha:** 2026-09-30  
**Rama:** `feat/roadmap-3-foundation`  
**Alcance:** Fase 1 — rol Coach, entitlement Coach Pro, límites de cartera y permisos Coach↔Cliente.

## 1. Activos protegidos

- identidad permanente del usuario;
- estado comercial `coach_pro`;
- límites de clientes;
- relaciones Coach↔Cliente;
- permisos concedidos por el cliente;
- programas, tareas, check-ins, progreso y orientación alimentaria compartidos;
- credenciales futuras del proveedor de billing;
- historial y auditoría de cambios de entitlement.

## 2. Fronteras de confianza

1. Flutter/Web es **no confiable** para autorizar pago.
2. Supabase Auth identifica al usuario, pero un rol `coach` no prueba pago.
3. PostgreSQL/RPC/RLS es la autoridad de relaciones, permisos y entitlement.
4. `service_role`/backend será la única autoridad que puede escribir entitlements.
5. Un proveedor de billing futuro solo será una fuente de eventos; sus webhooks deberán reconciliarse e idempotentizarse en backend.

## 3. Amenazas y mitigaciones

| Amenaza | Mitigación actual |
| --- | --- |
| Usuario cambia un booleano local para activar Coach Pro | El cliente solo recibe snapshot de lectura. Las escrituras profesionales se bloquean con guards server-side. |
| Usuario se añade capability `coach` | `coach` es solo rol. Invitaciones y escrituras premium exigen entitlement activo. |
| IDOR contra otro cliente | La relación activa y los permisos existentes siguen siendo obligatorios; entitlement no amplía permisos. |
| Entrenador sin pago conserva acceso de escritura | Entitlement expirado bloquea nuevas invitaciones y mutaciones profesionales; no borra datos históricos. |
| Billing bloquea al cliente para revocar | Cambiar permisos y revocar relación siguen disponibles aunque el entitlement del entrenador expire. |
| Exceso de clientes | La activación de una nueva relación se valida server-side contra `client_limit`. |
| Carrera entre invitaciones | El límite se vuelve a validar al activar la relación, no solo al crear la invitación. |
| Replay de webhook futuro | `event_key` único y setter idempotente de backend. |
| Evento viejo pisa estado nuevo | Repetir el mismo `event_key` no vuelve a aplicar el cambio. |
| Cliente lee metadata de billing sensible | Tabla privada; RPC self devuelve solo estado/tier/límite/vigencia y conteo de clientes. |
| Cliente modifica entitlement directo | Sin privilegios de tabla; setter ejecutable solo por `service_role`. |
| Sesión anónima usa Coach Pro | RPC self y flujos Coach exigen cuenta permanente. |
| Expiración destruye historial | Los guards bloquean mutaciones premium, no borran relaciones ni datos. |
| Coach comenta después de expirar | Triggers específicos protegen comentarios de tareas/check-ins cuando el autor es el coach. |
| Logs filtran datos sensibles | Fase 1 no añade analytics de contenido; billing futuro deberá registrar solo metadata mínima. |
| Service-role expuesta en Flutter | Prohibido por arquitectura; no existe secreto nuevo en cliente. |

## 4. Invariantes de seguridad

1. `coach` != `coach_pro`.
2. `coach_pro` != permiso sobre un cliente.
3. Acceso profesional requiere backend; UI local nunca es autoridad.
4. El cliente puede revocar aun si el entrenador no paga.
5. Un entitlement activo no autoriza a leer/escribir clientes no vinculados.
6. El límite se verifica al activar la relación.
7. El downgrade/expiración no elimina datos.
8. Eventos comerciales deben ser idempotentes.
9. Ninguna migración Roadmap 4 se despliega al remoto sin auditoría de ledger y autorización explícita.

## 5. Riesgos pendientes para fases posteriores

- integrar proveedor de billing y verificar firma de webhooks;
- protección anti-replay específica del proveedor;
- política de trial/grace/downgrade comercial definitiva;
- rate limit de invitaciones por cuenta/IP;
- dashboard agregado multi-cliente sin N+1;
- feature flags server-authoritative;
- observabilidad con redacción de PII;
- pruebas adversariales de dos coaches sobre el mismo cliente;
- revisión legal/comercial de cancelación y retención.

## 6. Evidencia Fase 1

CI público #87, run `36808744828`: **7/7 success**.

Supabase:
- upgrade incremental Roadmap 2 → Roadmap 3 → Roadmap 4: success;
- pgTAP tras upgrade: success;
- rebuild limpio: success;
- pgTAP tras rebuild: success.

El test específico de Coach Pro valida:
- capability `coach` sin entitlement no desbloquea Coach Pro;
- entitlement activo sí habilita el flujo;
- límite de clientes se aplica al activar una relación;
- entitlement expirado bloquea nuevas invitaciones y asignaciones;
- cliente conserva cambio de permisos y revocación;
- setter backend usa `event_key` idempotente.
