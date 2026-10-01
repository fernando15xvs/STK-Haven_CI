# STK Haven — Roadmap 4.0
## Coach Pro + Coach Inteligente — Master Plan

> Rama de trabajo: `feat/roadmap-3-foundation`
>
> Base verificada al crear este plan: `adaffe80bd56eced98ad6d21ef350a7f56d3f339`
>
> Objetivo: convertir el MVP Coach/Cliente de Roadmap 3 en un producto profesional monetizable para entrenadores y, en paralelo, crear un Coach Inteligente personal basado en evidencia observable de STK Haven.
>
> Restricciones actuales: no merge a `main`, no deploy de backend, no migraciones al Supabase remoto y no modificar la PWA estable. Implementar primero en fuente, sincronizar al mirror y validar en CI/Supabase efímero.

---

## Evidencia automática Fase 1 — 2026-09-30

- Fuente funcional validada antes de documentación final: `85e64befefdb381a5814b2b2ac00384477699d00`.
- Mirror funcional: `fd00dda0ed1a7b5bc8505e2250abb54f8cd20a47`.
- GitHub Actions: **CI #87**, run `36808744828`.
- Resultado: **7/7 success**.
- Supabase validó upgrade incremental Roadmap 2 → 3 → 4 y rebuild limpio, ambos con pgTAP verde.
- Se demostró que `coach` sin entitlement no habilita Coach Pro.
- Se validaron límite de clientes, expiración, revocación independiente del billing e idempotencia por `event_key`.
- Sin merge, sin deploy remoto y sin aplicar la migración Roadmap 4 a Supabase remoto.

---

# 0. Principios no negociables

- [x] Una sola fuente de verdad en `packages/core`; mobile/web consumen los mismos contratos.
- [x] Separar identidad/rol, suscripción comercial, permisos del cliente y capacidades funcionales.
- [x] `coach` nunca equivale a “pagó”.
- [x] `coach_pro` nunca concede acceso a datos de un cliente por sí solo.
- [x] El cliente conserva consentimiento granular y revocación inmediata.
- [x] Ningún entitlement pagado se confía a Hive/SharedPreferences/UI.
- [x] El servidor es autoridad de entitlements y límites.
- [ ] Coach Inteligente explica evidencia, confianza y motivo; no inventa datos.
- [ ] Coach Inteligente no modifica silenciosamente programas, cargas, volumen o nutrición.
- [ ] Sugerencias sensibles de salud quedan fuera del alcance: no diagnóstico ni tratamiento.
- [ ] Cambios importantes deben ser reversibles/auditables.
- [ ] Privacidad por defecto: compartir solo lo necesario y solo con permiso explícito.

---

# 1. Arquitectura comercial y de acceso

## 1.1 Separación de conceptos

Definir cuatro capas independientes:

1. **Identidad**: usuario autenticado.
2. **Rol/capability**: `athlete`, `coach` (qué experiencia usa).
3. **Entitlement comercial**: p. ej. `coach_pro`, estado, vigencia, tier y límites.
4. **Relación + permisos**: qué cliente autorizó a qué entrenador y para qué datos/acciones.

- [x] Eliminar la posibilidad de usar `stk_user_capabilities` como bypass de pago.
- [x] Mantener `athlete/coach` como rol funcional, no como licencia.
- [x] Crear contrato `SubscriptionEntitlement`/equivalente en core.
- [x] Diseñar tabla/RPC server-authoritative para entitlements.
- [x] Definir estados: trial/active/grace/past_due/canceled/expired (sin acoplar UI al proveedor de pagos).
- [x] Definir contrato de tier + `client_limit` server-side; los nombres/precios comerciales se decidirán en la fase de billing.
- [x] Definir comportamiento seguro cuando entitlement vence: conservar datos; bloquear nuevas acciones premium sin destruir historial.
- [ ] Diseñar cache local de solo lectura para UX offline, nunca como autoridad.
- [x] Tests anti-tampering: editar estado local no desbloquea Coach Pro.
- [x] Tests RLS/RPC: ser coach o conocer un UUID no permite saltarse entitlement + relación + permiso.

## 1.2 Billing desacoplado

No seleccionar proveedor de pago dentro del dominio.

- [ ] Crear interfaz/adaptador de billing independiente de Stripe/App Store/Google Play/otro proveedor.
- [ ] Webhooks futuros actualizan entitlement server-side con idempotencia.
- [ ] Registrar `provider_customer_id`/subscription IDs solo en backend protegido si fueran necesarios.
- [ ] No guardar secretos de billing en cliente.
- [ ] Definir restore/reconcile de compra.
- [ ] Diseñar período de gracia y fallos temporales del proveedor.
- [x] Auditoría de eventos de entitlement.
- [~] Replay/idempotencia y expiración cubiertos; downgrade comercial completo queda para la integración de billing.

**Gate A:** ninguna función Coach Pro depende de un booleano editable por el cliente.

---

# 2. Coach Pro — producto profesional para entrenadores

## 2.1 Dashboard multi-cliente

Crear una superficie profesional, no reutilizar simplemente la pantalla “Coach & Clientes”.

- [ ] Resumen: clientes activos / pausados, tareas pendientes, check-ins recientes y alertas operativas.
- [ ] Buscar/filtrar clientes.
- [ ] Ordenar por actividad reciente, adherencia y “requiere revisión”.
- [ ] Tarjetas compactas con último entreno, entrenos 7d, adherencia y check-in más reciente cuando exista permiso.
- [ ] Estados vacíos y errores claros.
- [ ] Responsive: móvil, tablet y web escritorio.
- [ ] Paginación/consulta escalable; no descargar toda la cartera para cada rebuild.
- [ ] Evitar N+1 RPC/query.
- [ ] Índices SQL necesarios documentados y probados.

## 2.2 Ficha profesional del cliente

Una ficha unificada con pestañas/secciones:

- Resumen.
- Programa.
- Entrenamientos.
- Progreso.
- Tareas.
- Check-ins.
- Orientación alimentaria no clínica.
- Comentarios/historial profesional.

- [ ] Cada sección respeta su permiso individual.
- [ ] Una sección sin permiso no filtra datos en payload ni en logs.
- [ ] Historial de cambios de programa.
- [ ] Comparación de periodos 7/30/90 días.
- [ ] Tendencias por ejercicio cuando el cliente comparte workouts.
- [ ] PRs, adherencia, volumen y RIR con contexto.
- [ ] Exportación segura sin notas privadas.
- [ ] Acciones críticas con confirmación y resultado auditable.

## 2.3 Programación profesional

- [ ] Biblioteca de plantillas del entrenador.
- [ ] Duplicar plantilla para cliente sin estado mutable compartido.
- [ ] Asignación versionada ya existente se conserva como base.
- [ ] Comparar versión asignada vs. nueva versión.
- [ ] Cliente acepta/activa programa según contrato.
- [ ] Rotación continua, frecuencia/calendario y series efectivas siguen usando motores existentes.
- [ ] No romper programas personales si termina la relación Coach.
- [ ] Deload/ajustes documentados y reversibles.

## 2.4 Seguimiento y comunicación

- [ ] Check-ins configurables por entrenador dentro de límites seguros.
- [ ] Bandeja “requiere revisión” basada en reglas transparentes.
- [ ] Comentarios con autor, timestamp y append-only donde corresponda.
- [ ] Tareas recurrentes y adherencia.
- [ ] Recordatorios opt-in del cliente.
- [ ] Sin chat clínico ni claims médicos.
- [ ] Diseñar notificaciones sin exponer datos sensibles en lock screen por defecto.

## 2.5 Gestión de cartera y plan

- [ ] Mostrar uso del plan: clientes activos / límite.
- [ ] No contar relaciones revocadas contra el límite.
- [ ] Definir qué ocurre al bajar de tier con exceso de clientes: no borrar; congelar nuevas altas y permitir elegir cartera activa.
- [ ] Trial y expiración sin pérdida de datos.
- [ ] UI para estado de suscripción separada de permisos de clientes.
- [ ] El cliente nunca necesita pagar Coach Pro para aceptar a su entrenador.

**Gate B:** un entrenador con entitlement válido puede administrar varios clientes autorizados; sin entitlement no puede ejecutar acciones premium, y jamás puede acceder a un cliente no vinculado.

---

# 3. Coach Inteligente — motor personal de recomendaciones

## 3.1 Alcance inicial

No empezar con un LLM tomando decisiones. Crear primero un motor determinista y explicable sobre señales que STK Haven ya posee:

- `ProgressionEngine`.
- `PlateauDetector`.
- Exercise Memory.
- comparación de sesiones.
- RIR.
- series efectivas.
- volumen por músculo.
- frecuencia.
- rotación/programa.
- adherencia.
- recovery/check-ins cuando existan datos válidos.

- [ ] Crear `SmartCoachEngine` puro en core.
- [ ] Crear modelo `SmartCoachInsight`: tipo, prioridad, evidencia, explicación, acción sugerida, confianza y timestamp.
- [ ] Tipos iniciales: progresión, mantener carga, estancamiento, adherencia, volumen, recuperación y consistencia.
- [ ] Umbrales centralizados/versionados.
- [ ] No producir recomendación cuando la evidencia sea insuficiente.
- [ ] Distinguir “dato faltante” de “problema”.
- [ ] Tests deterministas con fixtures conocidos.
- [ ] Sin red/IA externa para la decisión base.

## 3.2 Recomendaciones de entrenamiento

- [ ] “Subir carga” solo reutiliza/fortalece las reglas seguras de `ProgressionEngine`.
- [ ] Mantener carga cuando falta confirmación, RIR o contexto comparable.
- [ ] Detectar plateau con historial suficiente.
- [ ] Detectar adherencia baja sin lenguaje culpabilizante.
- [ ] Comparar volumen planificado vs. realizado.
- [ ] Alertar sobre cambios bruscos de volumen con umbrales conservadores.
- [ ] Respetar unilateralidad, calentamiento/aproximación vs. series efectivas y ejercicios en rutinas distintas.
- [ ] No confundir cambio de rango de repeticiones con progreso/retroceso directo.
- [ ] Mostrar siempre “por qué te lo sugiero”.

## 3.3 Recuperación

- [ ] Usar check-ins/estado de recuperación solo si el usuario los registra.
- [ ] No inferir lesión/enfermedad.
- [ ] Si hay señal de cautela, sugerir ajuste conservador o revisión, no diagnóstico.
- [ ] Permitir ignorar/descartar insight.
- [ ] Registrar aceptación/rechazo para UX, no para manipular reglas silenciosamente.

## 3.4 Aplicación de cambios

Tres niveles:

1. **Informar**: insight sin acción.
2. **Proponer**: mostrar cambio concreto y diff.
3. **Aplicar**: solo tras confirmación explícita del usuario/entrenador.

- [ ] Nunca autoeditar programa por defecto.
- [ ] Preview “antes/después”.
- [ ] Undo cuando sea técnicamente posible.
- [ ] Registrar origen: usuario / entrenador / Smart Coach.
- [ ] No pisar una prescripción activa del entrenador sin advertir conflicto.

**Gate C:** el mismo historial produce la misma recomendación explicable; ningún cambio estructural se aplica sin consentimiento.

---

# 4. Coach Inteligente + Coach Pro

El Smart Coach debe servir también como copiloto del entrenador, sin reemplazar su criterio.

- [ ] Generar insights por cliente solo sobre datos que el entrenador tiene permiso de ver.
- [ ] Cola “revisar” agregada server-side sin filtrar datos prohibidos.
- [ ] Entrenador puede aceptar, editar o descartar una sugerencia.
- [ ] Nunca enviar automáticamente una modificación al cliente.
- [ ] Guardar quién tomó la decisión final.
- [ ] Si se revoca permiso, desaparecer inmediatamente los insights derivados de esos datos para el entrenador.
- [ ] No entrenar modelos externos con datos del usuario por defecto.
- [ ] Diseñar redacción separando claramente “STK sugiere” de “Tu entrenador indicó”.

**Gate D:** Smart Coach aumenta la capacidad operativa del entrenador sin ampliar sus permisos ni actuar en su nombre.

---

# 5. Seguridad, privacidad y auditoría

- [x] Threat model específico Coach Pro: `docs/roadmap/ROADMAP_4_COACH_PRO_THREAT_MODEL.md`.
- [ ] Tests IDOR entre coach A/coach B/clientes.
- [ ] RLS por relación activa + permiso.
- [ ] Entitlement server-side además del permiso para acciones premium.
- [ ] Revocación inmediata.
- [ ] No borrar historial del cliente al revocar coach.
- [ ] Logs/auditoría sin contenido sensible innecesario.
- [ ] Rate limits para invitaciones/RPC sensibles.
- [ ] Códigos de invitación hash + expiración + single-use.
- [ ] Evitar enumeración de cuentas.
- [ ] Validar payloads y límites de tamaño.
- [ ] Exportaciones respetan permisos actuales al momento de generarse.
- [ ] Backup/restore no puede fabricar entitlements.
- [ ] Tests anon/permanent-account.
- [ ] Documentar retención/borrado de datos de relación.

**Gate E:** pasar suite pgTAP adversarial y pruebas de contrato antes de cualquier deploy remoto.

---

# 6. UX profesional

## Athlete

- [ ] “Coach Inteligente” claramente separado de “Mi entrenador”.
- [ ] Centro de permisos del entrenador.
- [ ] Historial de programas/tareas recibidas.
- [ ] Indicador inequívoco de qué acción proviene del entrenador y cuál de STK.
- [ ] Revocar acceso sencillo.

## Coach Pro

- [ ] Home profesional orientado a cartera, no al entrenamiento personal.
- [ ] Cambio rápido entre “Mi entrenamiento” y “Coach Pro” si la cuenta también es athlete.
- [ ] Desktop aprovecha ancho con tabla/panel; móvil usa cards.
- [ ] Acciones frecuentes a <= 2–3 interacciones desde dashboard.
- [ ] Loading/skeleton/error/offline states.
- [ ] Accesibilidad, text scaling y targets táctiles.
- [ ] Reduce Motion respetado.

---

# 7. Observabilidad y calidad

- [ ] Métricas técnicas: latencia, errores RPC, fallos de sincronización.
- [ ] Métricas de producto sin contenido privado: invitación→aceptación, clientes activos, adopción de tareas/programas, insights vistos/aceptados/descartados.
- [ ] No registrar notas, comentarios, alimentos o detalles sensibles en analytics.
- [ ] Crash reporting con redacción de PII.
- [ ] Feature flags server-authoritative para rollout gradual.
- [ ] Compatibilidad backward con Roadmap 3.
- [ ] Migraciones forward-only y rollback operativo documentado.

---

# 8. Estrategia de pruebas

## Unitarias/core

- [ ] SmartCoachEngine.
- [x] Entitlement policy.
- [x] límites de plan.
- [ ] conflictos entrenador vs Smart Coach.
- [ ] progresión/plateau/volumen/recovery.
- [ ] serialización y compatibilidad.

## Database/RLS

- [x] coach sin plan.
- [x] coach con plan.
- [x] plan expirado.
- [ ] cliente no vinculado.
- [ ] permiso parcial.
- [ ] relación revocada.
- [ ] dos coaches del mismo cliente.
- [ ] dos clientes del mismo coach.
- [ ] downgrade por límite.
- [x] intento de entitlement falsificado.
- [ ] anon rechazado.

## UI

- [ ] dashboard 0/1/10/50+ clientes.
- [ ] responsive mobile/web.
- [ ] permisos parciales.
- [ ] estados expired/grace/offline.
- [ ] Smart Coach sin datos / datos insuficientes / insight accionable.
- [ ] diff + confirmación + undo.

## CI

- [x] Analyze + Core — CI #87.
- [x] Mobile tests — CI #87.
- [x] Web tests + dart2js + WASM — CI #87.
- [x] Android artifacts — CI #87.
- [x] iOS release/profile — CI #87.
- [x] Supabase DB + RLS en instancia efímera — upgrade incremental + rebuild limpio en CI #87.
- [x] Edge Functions static check — CI #87 (sin nuevas Edge Functions en Fase 1).
- [x] 7/7 obligatorio antes de preview — CI #87, run `36808744828`.

## Smoke físico final

- [ ] Android.
- [ ] iPhone/iOS.
- [ ] Safari PWA.
- [ ] Web móvil.
- [ ] Web escritorio.
- [ ] Offline/reconexión.
- [ ] notificaciones donde aplique.

---

# 9. Orden de implementación

## Fase 1 — Contratos y seguridad comercial
Entitlements, roles, límites, políticas y threat model. Sin proveedor de pago real todavía.

## Fase 2 — Coach Pro foundation
Dashboard multi-cliente, queries agregadas, ficha profesional y permisos.

## Fase 3 — Coach Pro workflow
Plantillas/programas, tareas, check-ins, seguimiento y cartera.

## Fase 4 — Smart Coach deterministic core
Insights explicables sobre progresión, plateau, adherencia, volumen y recovery.

## Fase 5 — Smart Coach UX
Feed de insights, evidencia, diff, confirmación y undo.

## Fase 6 — Copiloto Coach Pro
Insights por cliente con permisos, revisión humana y trazabilidad.

## Fase 7 — Billing adapter
Integración del proveedor comercial elegido, webhooks, restore/reconcile, trial/grace/downgrade.

## Fase 8 — Hardening
RLS adversarial, escala, observabilidad, accesibilidad, performance y smoke multiplataforma.

## Fase 9 — Deploy controlado
Solo con autorización explícita: backup/ledger remoto, dry-run, migraciones, Edge Functions, secretos, smoke y rollback plan.

---

# 10. Definition of Done

Coach Pro se considera listo cuando:

- entitlement pagado no es falsificable desde cliente;
- cartera multi-cliente funciona a escala razonable;
- toda lectura/acción respeta relación + permiso + entitlement cuando corresponda;
- revocación corta acceso inmediatamente;
- downgrade no destruye datos;
- flujo completo entrenador→cliente está probado en dispositivo real;
- billing puede reconciliarse sin duplicar estados.

Coach Inteligente se considera listo cuando:

- usa datos reales y reglas versionadas;
- explica cada recomendación;
- maneja evidencia insuficiente;
- no diagnostica;
- no cambia planes silenciosamente;
- respeta prescripciones del entrenador;
- tiene pruebas deterministas y smoke UI;
- el usuario puede ignorar/confirmar cambios.

Roadmap 4 se considera cerrable solo con CI 7/7, pgTAP adversarial, smoke Android/iOS/Web/PWA y auditoría final de seguridad/privacidad.
