# Roadmap 3.0 — Auditoría de despliegue Supabase remoto

Fecha de auditoría: 2026-09-26  
Rama fuente: `feat/roadmap-3-foundation`

## Alcance y limitación

Esta auditoría cubre **todo el delta Supabase introducido por Roadmap 3.0** respecto a la base Roadmap 2.0.

La conexión Supabase disponible en la sesión actual apunta al proyecto **StOmniApp**, no al backend de STK Haven. Por seguridad no se consultó ni modificó ese proyecto. Por tanto:

- la rama privada es la fuente de verdad del código a desplegar;
- CI ha validado todas las migraciones en un Supabase efímero aislado;
- **no se afirma que el ledger remoto de STK Haven haya sido verificado en vivo**;
- los documentos del Roadmap mantienen que ninguna migración Roadmap 3 se ha aplicado todavía al remoto de STK Haven.

## 1. Migraciones Roadmap 3 pendientes de despliegue remoto

Deben aplicarse **en este orden**, sin saltar archivos:

1. `20260924052000_stk_user_profiles_and_capabilities.sql`
   - tablas: `stk_user_profiles`, `stk_user_capabilities`
   - RPC principal: `stk_sync_own_profile`
   - fundamento de identidad permanente y capacidades `athlete/coach`.

2. `20260924060000_stk_coach_client_relationships.sql`
   - tablas: `stk_coach_invitations`, `stk_coach_client_relationships`
   - invitaciones, aceptación, permisos, revocación y `stk_coach_can_access`.

3. `20260924063000_stk_assigned_programs.sql`
   - tablas de programas/rutinas/ejercicios asignados
   - RPC de asignación, lectura, aceptación y archivado.

4. `20260924070000_stk_shared_progress.sql`
   - snapshots de progreso y resúmenes de workout compartidos
   - RPC de sincronización y lectura autorizada.

5. `20260924073000_stk_coach_tasks.sql`
   - tareas, ocurrencias y comentarios Coach↔Cliente
   - recurrencia, adherencia y permisos.

6. `20260924080000_stk_nutrition_guidance.sql`
   - planes alimentarios no clínicos, versiones, comidas e ítems
   - versionado inmutable y permisos `view_nutrition`.

7. `20260925010000_stk_coach_checkins.sql`
   - check-ins y comentarios
   - consentimiento `view_checkins`, lectura y revocación.

8. `20260926090000_stk_food_vision_safety.sql`
   - verificación adulta backend-only
   - cuota Food Vision
   - métricas agregadas sin imagen/contenido del plato
   - RPC fail-closed de acceso adulto.

9. `20260926130000_stk_web_push.sql`
   - suscripciones Web Push privadas
   - registro/desactivación por usuario
   - lectura booleana de estado, sin exponer endpoints/keys al cliente.

## 2. Edge Functions nuevas que deben desplegarse

### `food-vision-ai`

Estado local:
- implementada;
- `verify_jwt = true`;
- CI/Deno check verde;
- usa cuota y verificación adulta del backend.

Secretos requeridos:
- **obligatorio:** `GEMINI_API_KEY`
- opcional: `GEMINI_FOOD_MODEL`
- fallback opcional existente: `GEMINI_MODEL`

Antes de invocarla en remoto debe existir la migración
`20260926090000_stk_food_vision_safety.sql`.

### `web-push-test`

Estado local:
- implementada;
- `verify_jwt = true`;
- CI/Deno check verde;
- solo envía a suscripciones del usuario autenticado.

Secretos requeridos:
- **obligatorio:** `WEB_PUSH_VAPID_SUBJECT`
- **obligatorio:** `WEB_PUSH_VAPID_PUBLIC_KEY`
- **obligatorio:** `WEB_PUSH_VAPID_PRIVATE_KEY`

Antes de invocarla en remoto debe existir la migración
`20260926130000_stk_web_push.sql`.

La clave privada VAPID **nunca** debe ir al frontend, repositorio ni `dart-define`.

## 3. Configuración de funciones

`supabase/config.toml` exige JWT para:

- `haven-faith-ai`
- `food-vision-ai`
- `web-push-test`

`haven-faith-ai` ya existía antes de este cierre. Solo debe redeplegarse si la configuración/versión remota no coincide con la rama auditada.

## 4. Configuración de build Web/PWA

La PWA necesita recibir exclusivamente la clave VAPID **pública** mediante:

`WEB_PUSH_VAPID_PUBLIC_KEY`

Esta variable se usa como `String.fromEnvironment`, por lo que debe incluirse al construir Web/PWA con `--dart-define` o mecanismo equivalente del pipeline de deployment.

No incluir:
- VAPID private key;
- Supabase secret/service-role key;
- Gemini API key.

## 5. Acceso adulto de Nutrición Inteligente

El frontend no puede autoconcederse acceso numérico.

La migración crea:
- tabla privada `stk_nutrition_adult_verifications`;
- RPC pública de solo lectura booleana `stk_has_adult_nutrition_access()`;
- RPC administrativa `stk_set_adult_nutrition_verification(...)` ejecutable solo por backend/service role.

Antes de release debe existir un procedimiento administrativo confiable para conceder/revocar esa verificación. No debe exponerse un botón cliente que llame al RPC privilegiado.

## 6. Orden recomendado de despliegue futuro

Cuando exista autorización explícita:

1. verificar project-ref real de STK Haven;
2. recuperar/comparar ledger remoto en **solo lectura**;
3. crear backup/snapshot lógico apropiado antes de cambios;
4. aplicar las 9 migraciones en orden;
5. ejecutar advisors de seguridad/performance;
6. verificar tablas/RPC/RLS con consultas de solo lectura;
7. configurar secretos de `food-vision-ai`;
8. desplegar `food-vision-ai`;
9. generar/configurar VAPID y guardar los 3 secretos remotos;
10. desplegar `web-push-test`;
11. construir/deplegar Web con la VAPID **pública**;
12. smoke remoto autenticado de Food Vision;
13. smoke remoto Web Push;
14. smoke Coach↔Cliente con dos identidades de prueba;
15. verificar logs sin PII/secrets inesperados.

## 7. Lo que NO debe hacerse durante esta auditoría

- no ejecutar `supabase db push`;
- no ejecutar `migration repair`;
- no ejecutar `db reset --linked`;
- no desplegar funciones;
- no crear/modificar secretos remotos;
- no modificar el proyecto Supabase StOmniApp;
- no hacer merge a `main`.

## 8. Evidencia automática actual

El candidato CI #29 terminó **7/7 verde**:

- Analyze + Core tests;
- Mobile tests;
- Android artifacts;
- iOS release/profile sin codesign;
- Web dart2js + WASM;
- Edge Functions static check;
- Supabase DB + RLS en entorno efímero.

Esto valida el paquete local/aislado, pero **no sustituye la auditoría del ledger remoto real antes del despliegue**.


## 9. Evidencia adicional de CI #32

CI #32 validó explícitamente el camino de actualización antes de cualquier deploy remoto:

1. dejó temporalmente solo las 3 migraciones Roadmap 2;
2. reconstruyó ese baseline;
3. restauró las 9 migraciones Roadmap 3;
4. ejecutó `supabase migration up --local`;
5. ejecutó pgTAP con éxito;
6. reconstruyó desde cero con toda la cadena;
7. volvió a ejecutar pgTAP con éxito.

Resultado del job `Supabase DB + RLS tests`: **success**.

Esto reduce el riesgo técnico del despliegue, pero no sustituye la comparación en solo lectura del ledger remoto real de STK Haven antes de aplicar cambios.
