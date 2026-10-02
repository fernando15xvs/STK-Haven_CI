# STK Haven — Roadmap 3.0
## Personalización, Fe opcional, Hábitos/Estudio y Modo Entrenador

> Rama de implementación: `feat/roadmap-3-foundation`
>
> Base de origen preservada: `feat/roadmap-2-complete` en `84b64ce0bb6b09275d59f3551d6b46731e6edb18`.
>
> Este documento es el checklist de implementación para las funciones posteriores a Roadmap 2.0.
> Roadmap 2.0 conserva sus pruebas manuales pendientes; no se consideran cerradas ni reemplazadas por este roadmap.

---

## Convención de estado

- `[ ]` pendiente.
- `[x]` implementado **y** validado.
- `[~]` en progreso (usar solo mientras exista trabajo activo).
- No marcar `[x]` por haber escrito código: debe existir test/análisis/smoke acorde al punto.
- Android, iOS y Web se validan por separado cuando el comportamiento o integración de plataforma difiera.

## Política de pruebas durante Roadmap 3.0

- Las pruebas locales/manuales del usuario se concentran **al final**.
- Durante implementación, usar primero GitHub Actions/mirror público y tests automatizados.
- No pedir al usuario repetir analyze/tests/builds que CI pueda ejecutar.
- La lista mínima de pruebas locales finales vive en:
  `docs/roadmap/ROADMAP_3_FINAL_LOCAL_TEST_AUDIT.md`.
- Un punto puede quedar implementado en `[~]` hasta que CI o la validación final aporte evidencia suficiente.

## Evidencia automática Fase A — 2026-09-24

- Fuente privada validada: `323c672198f33ba5cea95a2f7605bcf701327b28`.
- Snapshot público equivalente: `14c8362e3502a0d435eac1783e9b2347e12ebc38`.
- GitHub Actions: `STK Haven Public CI` run #3, ID `35956941186`.
- Resultado global: `success`.
- Verdes: Analyze + Core tests, Mobile tests, Android debug/profile/release/AAB/split ABI, Web tests + dart2js + WASM, iOS release/profile sin codesign.
- Los smoke manuales de dispositivo/PWA siguen diferidos a `ROADMAP_3_FINAL_LOCAL_TEST_AUDIT.md`.

## Evidencia automática Fase B + fundación C — 2026-09-24

- Fuente privada validada: `bfb420f30dc2c162174d0356dbcf3d8b2c850f16`.
- Snapshot público equivalente: `406fa4314d59c272473ba75c5b3638f29b9b0db2`.
- GitHub Actions: `STK Haven Public CI` run #5, ID `35958325688`.
- Resultado global: `success`.
- Verdes: Analyze + Core tests, Mobile tests, Android debug/profile/release/AAB/split ABI, Web tests + dart2js + WASM, iOS release/profile sin codesign.
- Este run valida automáticamente el código de Study & Habits, backup schema v10 y compatibilidad del harness legacy.
- La migración `20260924052000_stk_user_profiles_and_capabilities.sql` forma parte del snapshot y pasó revisión estática/compilación del repositorio, pero **no se considera aplicada ni validada dinámicamente contra Supabase**.
- UX física, PWA y comportamiento real de notificaciones/background siguen diferidos a `ROADMAP_3_FINAL_LOCAL_TEST_AUDIT.md`.

## Evidencia automática Fase C — identidad/RLS aislado — 2026-09-24

- Fuente privada validada: `f0176f62cb7cdb55e76a750682bbe649cd88d8d0`.
- Snapshot público equivalente: `1a599b4514ba0021f1be8521b9120166e6a24b35`.
- GitHub Actions: `STK Haven Public CI` run #7, ID `35961842261`.
- Resultado global: `success`.
- Verdes: Supabase DB + RLS tests, Analyze + Core tests, Mobile tests, Android debug/profile/release/AAB/split ABI, Web tests + dart2js + WASM, iOS release/profile sin codesign.
- La migración de identidad se aplicó y probó en un **Supabase efímero aislado de CI**, incluyendo pgTAP de RLS, aislamiento entre usuarios, rechazo de sesión anónima y dominio `athlete/coach`.
- **No se aplicó ninguna migración al Supabase remoto**; el despliegue real sigue reservado para una autorización explícita futura.


## Evidencia automática Fase D — Coach/Client MVP — 2026-09-24

- Fuente privada validada: `f273acbe4b973088af36340f95ca4fc04aa97c8a`.
- Snapshot público equivalente: `43a00cee3a33b46b040f2b1c7c20d3abb5c74f44`.
- GitHub Actions: `STK Haven Public CI` run #13, ID `35976942306`.
- Resultado global: `success`.
- Verdes: Supabase DB + RLS tests, Analyze + Core tests, Mobile tests, Android debug/profile/release/AAB/split ABI, Web tests + dart2js + WASM, iOS release/profile sin codesign.
- Se validaron invitaciones con consentimiento, relación coach↔cliente, permisos, revocación, asignación versionada de programas y progreso compartido con permisos separados `view_progress` / `view_workouts`.
- pgTAP confirmó aislamiento multiusuario, rechazo de entrenador no vinculado y pérdida inmediata de acceso del entrenador tras revocación, sin borrar el historial propio del cliente.
- **No se aplicó ninguna migración Roadmap 3 al Supabase remoto.**


## Evidencia automática Fase E — Tareas del entrenador — 2026-09-24

- Fuente privada validada: `f863af0cd9547cabdf4dcdb477e0c7d53882674c`.
- Snapshot público equivalente: `c85a37000b68b3dfb8c378323d54218e6dfeca55`.
- GitHub Actions: `STK Haven Public CI` run #15, ID `36093926256`.
- Resultado global: `success`.
- Verdes: Supabase DB + RLS tests, Analyze + Core tests, Mobile tests, Android debug/profile/release/AAB/split ABI, Web tests + dart2js + WASM, iOS release/profile sin codesign.
- Se validaron asignación consentida de tareas, estados `completed/skipped` inmutables por ocurrencia, recurrencia, adherencia, comentarios append-only, conservación del historial del cliente y corte de acceso del entrenador tras revocación.
- Las tareas cloud se materializan como `HabitTaskSource.coach` sin permitir que el mirror local salte la autoridad del backend.
- Los recordatorios son opt-in local del cliente; su compilación está validada, pero la aparición real de la notificación queda para el smoke físico final.
- **No se aplicó ninguna migración Roadmap 3 al Supabase remoto.**


## Evidencia automática de cierre Roadmap 3 — CI #32 — 2026-09-26

- Snapshot público: `5b50fe989967a539d7cbce5f2f25d071b01b336a`.
- GitHub Actions run: #32, ID `36267338027`.
- Resultado global: **success, 7/7 jobs verdes**.
- Verdes: Analyze + Core tests, Mobile tests, Web dart2js/WASM, Edge Functions, Supabase DB + RLS, Android artifacts e iOS release/profile.
- Supabase validó dos caminos:
  1. baseline Roadmap 2 → `supabase migration up --local` con las 9 migraciones Roadmap 3 → pgTAP;
  2. rebuild limpio con toda la cadena → pgTAP.
- Android: debug/profile/release APK, AAB y split ABI.
- iOS: release/profile sin codesign.
- iOS personal-test: artefacto `stk-haven-ios-unsigned` generado y subido correctamente.
- Web Push, gesto Back y audio compilan; su comportamiento real queda en L08.
- No hubo merge ni deploy remoto.


---

# 0. Gate previo — preservar Roadmap 2.0

- [x] Mantener pendientes las pruebas manuales restantes de Roadmap 2.0.
- [x] No hacer merge a `main` por iniciar Roadmap 3.0.
- [ ] No romper Exercise Memory, Unilateral Pro, Programas 2.0, Progreso 2.0 ni backups.
- [x] Candidato Roadmap 2.0 post-hardening/post-split validado por CI público antes de abrir la rama Roadmap 3.0.
- [ ] Mantener iOS pendiente hasta disponer de macOS/iPhone para validación real.

---

# 1. Arquitectura objetivo de Roadmap 3.0

## 1.1 Principios

- [x] Mantener una sola lógica compartida en `packages/core`.
- [x] Mantener UI específica donde aporte valor: móvil y web presentan onboarding propio sobre contratos/reglas compartidas.
- [x] Mantener entrypoints Android/iOS separados.
- [x] Introducir una capa compartida de **perfil/preferencias de producto**.
- [x] Separar preferencias de entrenamiento, fe, hábitos y rol/capacidades.
- [ ] No cargar proveedores/repositorios pesados de módulos desactivados.
- [x] Diseñar migraciones backward-compatible para usuarios existentes.

## 1.2 Perfil de producto

Crear un modelo compartido, por ejemplo:

`UserExperienceProfile`

Campos propuestos:

- tipo/capacidades de cuenta;
- objetivo de entrenamiento;
- experiencia;
- días por semana;
- duración aproximada por sesión;
- lugar/equipamiento;
- unidad de peso;
- preferencias de recordatorios;
- contenido de fe habilitado;
- hábitos/estudio habilitados;
- onboardingVersion.

- [x] Definir contrato del modelo.
- [x] Persistencia local Hive.
- [x] Serialización/backups.
- [x] Migración segura desde `SettingsState` actual.
- [x] Tests de defaults para instalaciones existentes.
- [x] Tests de restore de backups antiguos.

---

# 2. Onboarding 2.0 — Mobile + Web

## 2.1 Objetivo

El onboarding deja de preguntar únicamente objetivo/experiencia/días. Debe personalizar módulos, programa inicial y experiencia sin convertir el inicio en un cuestionario largo.

## 2.2 Preguntas propuestas

### Bloque A — Entrenamiento

- [x] Objetivo principal:
  - ganar masa muscular;
  - ganar fuerza;
  - mantenerme activo;
  - mejorar condición física;
  - crear mis propias rutinas sin recomendación automática.

- [x] Experiencia:
  - principiante;
  - intermedio;
  - avanzado.

- [x] Días disponibles por semana:
  - 2–6;
  - permitir “todavía no lo sé”.

- [x] Duración habitual disponible:
  - 30 min;
  - 45 min;
  - 60 min;
  - 75+ min;
  - variable.

- [x] Lugar/equipamiento:
  - gimnasio completo;
  - casa con pesas;
  - casa/equipamiento mínimo;
  - mixto.

- [x] Preferencia de planificación:
  - quiero una recomendación;
  - quiero crear mis propias rutinas;
  - decidir después.

### Bloque B — Personalización de experiencia

- [x] Unidad de peso: kg/lb.
- [x] ¿Quieres recordatorios de entrenamiento?
- [x] Si responde sí, solicitar hora después del onboarding, no pedir permisos del sistema antes de necesitarlo.
- [x] Reduce Motion / rendimiento se configura desde Ajustes y no sobrecarga onboarding inicial.

### Bloque C — Fe cristiana opcional

Usar redacción neutral:

> “¿Quieres incluir contenido de fe cristiana en STK Haven?”

Opciones:

- Sí, quiero incluirlo.
- No, prefiero mantenerlo oculto.
- Decidir después.

- [x] Guardar `faithEnabled` separado de `showDailyVerse`.
- [ ] Si es Sí:
  - habilitar versículo diario;
  - habilitar Biblia;
  - habilitar Haven Faith;
  - mostrar acceso a Estudio/Hábitos de fe;
  - ofrecer notificaciones como paso opcional posterior.
- [ ] Si es No:
  - ocultar versículo diario;
  - ocultar Biblia;
  - ocultar Haven Faith;
  - ocultar tareas/estudio de fe;
  - no inicializar la base bíblica;
  - no programar notificaciones de versículos;
  - no descargar contenido bíblico en segundo plano.
- [ ] Si es “Decidir después”:
  - no forzar descargas;
  - mostrar activación opcional desde Perfil/Ajustes.

## 2.3 UX

- [x] Máximo 5–6 pantallas cortas.
- [x] Permitir volver atrás sin perder respuestas.
- [x] Barra de progreso clara.
- [x] Resumen final de preferencias.
- [x] Permitir editar todas las respuestas después.
- [x] No volver a mostrar onboarding completo por una actualización.
- [x] Versionar onboarding para futuras preguntas.
- [x] Mobile: UI compacta.
- [x] Web: onboarding responsive antes del `WebLayout`.
- [ ] Tests de navegación/estado.
- [ ] Tests responsive web.
- [ ] Smoke Android.
- [ ] Smoke iOS.
- [ ] Smoke Web/PWA.

---

# 2A. Programas 3.0 — Rotación continua por sesión

## 2A.1 Problema que debe resolver

La planificación semanal no debe fijar una rutina concreta a cada día de la semana.

Ejemplo de secuencia del usuario:

`Upper A → Lower A → Upper B → Lower B → repetir`

Días disponibles:

`lunes, martes, jueves, viernes, sábado`

El calendario solo decide **cuándo existe una oportunidad de entrenar**. La rutina que toca viene siempre de la siguiente posición de la secuencia pendiente.

### Resultado esperado

Semana 1:

- lunes → Upper A;
- martes → Lower A;
- miércoles → descanso;
- jueves → Upper B;
- viernes → Lower B;
- sábado → Upper A.

Semana 2:

- lunes → Lower A;
- martes → Upper B;
- miércoles → descanso;
- jueves → Lower B;
- viernes → Upper A;
- sábado → Lower A.

Semana 3:

- lunes → Upper B;
- martes → Lower B;
- miércoles → descanso;
- jueves → Upper A;
- viernes → Lower A;
- sábado → Upper B.

La secuencia **no se reinicia al comenzar una semana nueva**.

## 2A.2 Reglas funcionales

- [x] El orden de `TrainingProgram.routineIds` es la fuente de verdad de la secuencia.
- [x] Los días semanales solo indican disponibilidad/calendario, no mapeo fijo rutina↔día.
- [x] El siguiente día de entrenamiento muestra `nextRoutineId`.
- [x] Completar la rutina esperada avanza exactamente una posición.
- [x] Un día de descanso no avanza ni reinicia la secuencia.
- [x] Cambiar de semana no reinicia la secuencia.
- [x] Si el usuario falta un día, la rutina pendiente se conserva para el próximo día disponible.
- [x] Un workout libre no avanza la secuencia del programa.
- [x] Una rutina del programa completada fuera de secuencia no avanza silenciosamente el índice.
- [x] Cerrar/reabrir mantiene la posición exacta.
- [x] Backup/restore conserva la posición exacta.
- [x] Cambiar los días disponibles no cambia el orden de las rutinas.
- [x] Pausar/reanudar programa conserva posición e historial; cubierto por contrato/tests automáticos.
- [x] Duplicar un programa nuevo empieza en su primera rutina, sin compartir estado mutable.
- [x] Deload no altera orden/posición; cubierto por test de invariante.

## 2A.3 Integración UI

- [x] Inicio muestra claramente “Próxima sesión: Upper/Lower ...”.
- [x] Programas muestra secuencia y posición actual.
- [x] Calendario proyecta futuras sesiones respetando días disponibles y continuidad entre semanas.
- [x] Workout iniciado desde “Próxima sesión” usa la rutina esperada.
- [x] Mobile/Web advierten explícitamente que una rutina fuera de secuencia no avanzará la rotación.
- [x] Mobile y Web presentan la misma fuente de verdad.

## 2A.4 Validación automática obligatoria

Agregar tests con la secuencia exacta:

`UA, LA, UB, LB, UA, LA, UB, LB, UA, LA, UB...`

sobre lunes/martes/jueves/viernes/sábado durante varias semanas.

- [x] Test exacto del ejemplo de 3 semanas.
- [x] Test de semana nueva sin reset.
- [x] Test de día omitido.
- [x] Test de cambio de días disponibles.
- [x] Test de workout libre/off-sequence.
- [x] Test de persistencia/rehidratación.
- [x] Test de backup/restore preservando posición exacta.
- [x] Test de proyección de calendario.
- [ ] Test mobile/web del texto “Próxima sesión”.

> Nota técnica: Roadmap 2.0 ya contiene un `ProgramRotationCoordinator` secuencial e independiente del weekday. Roadmap 3.0 debe auditar y conectar **toda la UI/calendario/lanzamiento de workout** a esa fuente de verdad, porque el comportamiento actual visible no cumple todavía el caso Upper A/Lower A/Upper B/Lower B descrito arriba.

**Gate 2A:** la secuencia continúa correctamente entre semanas, descansos y ausencias sin depender de un mapeo fijo por weekday.

---

# 3. Módulo Fe opcional — hard opt-in

## 3.1 Estado actual a corregir

Actualmente existen preferencias como `showDailyVerse`, pero el concepto de “mostrar el versículo” no debe ser equivalente a “habilitar todo el módulo Fe”.

- [x] Crear `faithEnabled` mediante `UserExperienceProfile.faithEnabled` + preferencia triestado.
- [x] `showDailyVerse` se mantiene como subpreferencia independiente del opt-in global.
- [x] Notificaciones de versículo se mantienen como subpreferencia independiente y se cancelan al desactivar Fe.
- [x] Condicionar inicialización de Biblia a `faithEnabled == true`.
- [x] Condicionar providers de versículo a módulo habilitado.
- [x] Condicionar accesos rápidos en mobile.
- [x] Condicionar navegación lateral/secciones en web.
- [x] Desactivar Fe solo cambia preferencia/cancela notificaciones; no borra repositorios de notas/favoritos.
- [x] Reactivar Fe reutiliza datos locales previos; desactivar no elimina contenido.
- [x] Test de Fe OFF demuestra 0 llamadas al inicializador bíblico.
- [x] Test de Fe ON demuestra carga bajo demanda.
- [x] Gate inyectable probado: Fe OFF no ejecuta inicialización/request bíblico.

---

# 4. Estudio / Hábitos — “Study & Habits”

Crear un motor de tareas genérico que no sea exclusivo de la Biblia. Así más adelante sirve para hábitos de entrenamiento, movilidad, lectura o aprendizaje.

## 4.1 Modelo

Entidad propuesta: `HabitTask`

Tipos iniciales:

- lectura con temporizador;
- tarea de checklist;
- sesión de estudio;
- reflexión/nota;
- plan con días consecutivos;
- tarea recurrente.

Campos:

- id;
- título;
- categoría;
- duración objetivo;
- recurrencia;
- fecha/hora opcional;
- estado;
- progreso;
- racha opcional;
- notas;
- origen (usuario / plan / entrenador);
- visibilidad privada/compartible.

- [x] Definir modelo.
- [x] Repositorio local.
- [x] Provider.
- [x] Backup/restore mediante schema v10, compatible con v9.
- [x] Tests de recurrencia.
- [~] Tests de calendario local/cambio de día cubiertos; cambio real de zona horaria queda para el gate final.
- [x] No castigar al usuario por perder una racha: mostrar progreso, no culpa.

## 4.2 “Estudiar la Biblia 10 minutos”

Si `faithEnabled == true`:

- [x] Plantilla “Leer la Biblia — 10 min”.
- [x] Timer persistente basado en timestamps, resistente a background/reapertura.
- [x] Elegir/corregir referencia libro/capítulo durante una sesión libre.
- [x] Marcar sesión completada.
- [x] Añadir nota/reflexión.
- [x] Guardar pasaje de referencia sin duplicar grandes textos en planes.
- [x] Estadística semanal de minutos de lectura.
- [x] Historial de estudio.
- [~] Recordatorio opcional implementado; smoke físico diferido al gate local.

## 4.3 Planes de estudio bíblico

Ideas:

- Evangelio de Juan en N días.
- Salmos seleccionados.
- Proverbios por capítulos.
- Lectura cronológica (solo si se define y valida el plan).
- Temas: gratitud, disciplina, sabiduría, perseverancia.

- [x] Motor de planes independiente del texto bíblico.
- [x] Plan define referencias, no copia masiva de texto.
- [x] Progreso por día/sesión.
- [x] Pausar/reanudar.
- [x] Múltiples inscripciones conservan el progreso ya guardado; no se borra historial al iniciar otro plan.
- [x] Mobile persiste RV1909 en SQLite; Web/PWA conserva libros descargados en caché runtime versionada.

## 4.4 Libros y material adicional

Opciones seguras de producto:

- notas propias del usuario;
- artículos escritos específicamente para STK Haven;
- obras de dominio público;
- contenido con licencia explícita;
- enlaces externos a contenido del autor/editor.

- [x] Catálogo de recursos con metadatos de fuente/licencia.
- [x] El catálogo solo incluye contenido propio/usuario o recurso con licencia documentada; no se incorporan libros de terceros sin permiso.
- [x] No se incluyen PDFs/ebooks de terceros por disponibilidad en internet.
- [x] Fuente/licencia obligatoria en cada recurso del catálogo.
- [~] Marcadores locales implementados; notas propias ya existen como recurso/historial de estudio.
- [x] Búsqueda por título/autor/tema/fuente/licencia.

---

# 5. Riesgo crítico — contenido bíblico y licencias

La implementación actual descarga una Biblia desde un repositorio/CDN externo. Antes de ampliar Fe:

- [x] Traducción cambiada a Reina-Valera 1909 con snapshot/versionado y licencia documentada.
- [x] Dataset BibleAquifer/RV1909 auditado y fijado a un tag versionado.
- [x] La decisión se basa en metadata/licencia explícita, no en el alojamiento.
- [x] Reina-Valera 1909 definida como fuente distribuible/offline del producto.
- [x] RV1909 usa fuente primaria + CDN alternativo versionado; además reutiliza almacenamiento local/caché tras la primera carga.
- [~] Ya no existe un único endpoint crítico: hay dos fuentes pinned + caché local. La primera carga completa sigue requiriendo conectividad externa.
- [x] Atribución/licencia visible desde Ajustes.
- [x] Catálogo adicional exige metadata de fuente/licencia y no incorpora contenido de terceros sin permiso.

Riesgo: **alto** si se distribuye contenido protegido sin permiso.

---

## Nota de reconciliación de secciones 6–15

Las secciones 6–15 conservan el diseño original y varias casillas históricas. La evidencia de cierre actual para Identidad, Coach/Client, Tareas, Nutrición y Coach 2.0 está en las **Fases C–G** y sus runs CI/pgTAP posteriores. No deben reimplementarse funcionalidades únicamente porque una casilla histórica de esta parte siga en `[ ]`; se auditan contra los gates de fase y el código real.

# 6. Cuentas y capacidades — Usuario / Entrenador

## 6.1 Decisión de diseño

No crear dos aplicaciones ni dos tablas de usuario incompatibles.

Un usuario puede tener capacidades:

- `athlete` — usa STK Haven para sí mismo;
- `coach` — administra asesorados;
- opcionalmente ambas.

- [~] Migración preparada para `stk_user_profiles` ligada a Supabase Auth; pendiente aplicación/validación dinámica.
- [~] Migración preparada para capacidades `athlete`/`coach`; pendiente aplicación/validación dinámica.
- [ ] Migrar el login actual de Cloud Sync hacia identidad de aplicación reutilizable.
- [ ] Mantener modo local sin cuenta para usuario normal cuando no use funciones cloud.
- [ ] Requerir cuenta permanente para funciones entrenador/cliente.
- [ ] No utilizar sesión anónima como identidad de entrenador.

---

# 7. Relación Entrenador ↔ Cliente

## 7.1 Modelo de relación

Entidad propuesta: `coach_client_relationships`

Campos:

- coach_user_id;
- client_user_id;
- status: invited / active / paused / revoked;
- permissions;
- created_at;
- accepted_at;
- revoked_at.

- [ ] Invitación por código/enlace/correo.
- [ ] El cliente debe aceptar explícitamente.
- [ ] El cliente puede revocar acceso.
- [ ] El entrenador puede retirar al cliente de su lista.
- [ ] Ningún entrenador puede consultar usuarios no vinculados.
- [ ] RLS por relación activa.
- [ ] Tests pgTAP/RLS de aislamiento.
- [ ] Log de eventos sensibles.
- [ ] El cliente conserva propiedad de su historial.

## 7.2 Permisos configurables

Permisos posibles:

- ver entrenamientos;
- ver progreso;
- ver medidas corporales;
- asignar programas;
- editar programa asignado;
- ver check-ins;
- ver plan alimenticio;
- comentar/notas.

- [ ] Modelo de permisos mínimo.
- [ ] Default conservador.
- [ ] UI para cliente: “Qué puede ver mi entrenador”.
- [ ] UI para revocar permisos.
- [ ] Auditoría de cambios de permiso.

---

# 8. Dashboard Entrenador

Web será la experiencia principal para administración densa; mobile tendrá versión adaptada.

## 8.1 Lista de asesorados

- [ ] Clientes activos.
- [ ] Pendientes de invitación.
- [ ] Búsqueda/filtro.
- [ ] Indicador de última actividad.
- [ ] Adherencia de entrenamientos.
- [ ] Próxima sesión.
- [ ] Alertas no médicas: varios entrenamientos omitidos, plan sin actualizar, check-in pendiente.

## 8.2 Perfil de cliente

- [ ] Resumen.
- [ ] Programa/rutinas asignadas.
- [ ] Historial de entrenamientos.
- [ ] Progreso peso/reps/e1RM/volumen.
- [ ] Unilateral I/D.
- [ ] PRs.
- [ ] Check-ins/recovery compartidos.
- [ ] Notas del entrenador.
- [ ] Tareas asignadas.
- [ ] Plan alimenticio/orientación alimentaria.
- [ ] Timeline de cambios de plan.

## 8.3 Asignar entrenamiento

- [ ] Crear programa desde cero.
- [ ] Usar plantilla.
- [ ] Duplicar programa para un cliente.
- [ ] Asignar fecha de inicio.
- [ ] Cambiar rutina futura sin reescribir historial pasado.
- [ ] Cliente puede ver qué fue asignado por entrenador.
- [ ] Registrar versión del plan.
- [ ] Comparar planificado vs realizado.

---

# 9. Plan alimenticio / orientación alimentaria

## 9.1 Alcance recomendado inicial

Para reducir riesgo legal y de salud, comenzar con **planificación alimentaria no clínica**, no con diagnóstico ni tratamiento.

V1:

- comidas del día;
- ejemplos de alimentos;
- porciones/notas escritas por el profesional/entrenador;
- hidratación;
- preferencias;
- alergias declaradas por el cliente como advertencia visible;
- checklist de adherencia opcional.

- [ ] Definir nombre y alcance del módulo.
- [ ] Aviso claro de que STK Haven no diagnostica ni reemplaza atención médica/nutricional.
- [ ] No generar automáticamente dietas terapéuticas.
- [ ] No permitir que la app presente recomendaciones clínicas como hechos.
- [ ] Diseñar futura capacidad `nutritionist` si se necesita diferenciar profesionales.
- [ ] El cliente puede ocultar/revocar compartir datos sensibles.
- [ ] Historial/versionado de planes.
- [ ] Exportación legible.
- [ ] Mobile cliente.
- [ ] Mobile entrenador.
- [ ] Web entrenador.

## 9.2 Riesgos

Riesgo: **alto** si se permiten prescripciones médicas/nutricionales automatizadas o si se mezclan datos de salud sin permisos claros.

Mitigación:

- alcance explícito;
- permisos;
- auditoría;
- versionado;
- RLS;
- disclaimers;
- no inferir diagnósticos;
- soporte futuro para credenciales profesionales si el producto lo requiere.

---

# 10. Tareas del Entrenador

Reutilizar el motor `HabitTask`.

Ejemplos:

- completar rutina;
- registrar peso/medidas;
- hacer check-in;
- movilidad 10 min;
- caminata;
- leer material;
- completar cuestionario;
- revisar plan.

- [x] El entrenador crea tarea con consentimiento `assign_tasks`.
- [x] Cliente la recibe desde backend y como mirror `HabitTaskSource.coach` en Study & Habits.
- [x] Estado pendiente/completada/omitida.
- [x] Fecha límite opcional.
- [x] Repetición diaria/semanal.
- [x] Comentario cliente.
- [x] Comentario entrenador sujeto a permiso `comment`.
- [~] Notificaciones opcionales implementadas como opt-in local; prueba física final pendiente.
- [x] El cliente puede diferenciar tarea propia vs asignada.
- [x] Historial no editable retroactivamente: ocurrencia final inmutable y comentarios append-only.

---

# 11. Sincronización y estrategia de datos

## 11.1 Usuario normal

- [ ] Continuar soportando local-first.
- [ ] Cuenta cloud opcional para backup/sync.
- [ ] Fe/hábitos locales disponibles sin cuenta cuando sea posible.

## 11.2 Entrenador/cliente

Las funciones colaborativas requieren backend autoritativo.

- [ ] Supabase como fuente compartida para relaciones/asignaciones.
- [ ] RLS estricta.
- [ ] No usar el backup JSON actual como sistema colaborativo.
- [ ] Diseñar tablas normalizadas para datos compartidos.
- [ ] Definir qué permanece local y qué sincroniza.
- [ ] Cola offline para escrituras del cliente si se implementa offline.
- [ ] Estrategia de conflicto.
- [ ] Idempotencia.
- [ ] Timestamps de servidor.
- [ ] Migraciones versionadas.
- [ ] Tests de multiusuario.

---

# 12. Privacidad y seguridad

Los datos de entrenamiento, medidas, recovery, alimentación y notas pueden ser sensibles.

- [ ] Principio de mínimo acceso.
- [ ] RLS para todas las tablas colaborativas.
- [ ] Prohibir acceso coach→cliente sin relación activa.
- [ ] Prohibir cliente→otros clientes.
- [ ] No exponer service_role en Flutter.
- [ ] Audit log para acceso/cambios críticos.
- [ ] Exportar mis datos.
- [ ] Eliminar cuenta/datos según política definida.
- [ ] Revocar entrenador.
- [ ] Desvinculación no borra historial propio.
- [ ] Backups no deben contener datos de otros clientes salvo que el diseño lo autorice explícitamente.
- [ ] Threat model antes del release entrenador.
- [ ] Revisión de secretos antes de merge.

Riesgo: **muy alto** si se implementa modo entrenador sin RLS/consentimiento.

---

# 13. Web

## 13.1 Usuario normal

- [ ] Onboarding 2.0 web.
- [ ] Fe opcional.
- [ ] Study & Habits.
- [ ] Programas/progreso existentes conservados.
- [ ] Responsive mobile-web.

## 13.2 Entrenador

- [ ] Selector “Mi entrenamiento / Mis clientes”.
- [ ] Dashboard de clientes.
- [ ] Cliente detalle en layout de escritorio.
- [ ] Editor de programas.
- [ ] Editor de orientación alimentaria.
- [ ] Tareas/check-ins.
- [ ] Gráficos de progreso.
- [ ] Responsive tablet.
- [ ] Accesibilidad teclado.
- [ ] PWA/offline donde tenga sentido.

---

# 14. Mobile Android/iOS

## 14.1 Usuario normal

- [ ] Onboarding 2.0.
- [ ] Fe opcional y lazy.
- [ ] Estudio/hábitos.
- [ ] Mantener rendimiento post-hardening.

## 14.2 Entrenador

- [ ] Vista de clientes compacta.
- [ ] Cliente detalle.
- [ ] Revisar progreso.
- [ ] Asignar plantilla/rutina.
- [ ] Crear tarea.
- [ ] Editar orientación alimentaria básica.
- [ ] Notificaciones.
- [ ] Deep links de invitación.

## 14.3 Plataforma

- [ ] Android: validar background/notificaciones.
- [ ] iOS: validar permisos/background/Deep Links.
- [ ] No importar implementaciones Android en iOS ni viceversa.
- [ ] Medir startup después de añadir módulos.

---

# 15. Riesgo de complejidad / rendimiento

Agregar entrenador, hábitos y contenido puede volver a hacer pesada la app.

Mitigaciones obligatorias:

- [ ] Features lazy.
- [ ] Providers de coach no se crean en usuario normal.
- [x] Biblia no se inicializa con Fe OFF; test de 0 llamadas.
- [ ] Paginación de clientes/historial.
- [ ] Queries agregadas para dashboards.
- [ ] No descargar todo el historial de todos los clientes.
- [~] Historial Food Vision está acotado a 100 entradas; caché bíblica PWA queda versionada por traducción/snapshot.
- [ ] Evitar blur/compositing costoso móvil.
- [x] Benchmark/regresión automático para 1k/5k sesiones.
- [x] Test de escala para 25/100 clientes con payload reciente acotado.
- [ ] Profiling Android release/profile.
- [ ] Profiling iOS release/profile.

Riesgo: **medio-alto** si se cargan módulos/cliente/historial de forma eager.

---

# 16. Secuencia recomendada de implementación

## Fase A — Fundación de personalización
- [x] A1 Modelo `UserExperienceProfile`.
- [x] A2 Onboarding 2.0 mobile.
- [x] A3 Onboarding 2.0 web.
- [x] A4 `faithEnabled` + migración.
- [x] A5 Lazy Bible init.
- [x] A6 Tests/backups.
- [x] A7 Rotación continua Upper/Lower independiente de semana/weekday.

**Gate A:** usuario nuevo puede completar onboarding en Mobile/Web; Fe OFF no carga recursos de Fe; la programación usa una secuencia continua de sesiones y no un mapeo fijo rutina↔weekday.

## Fase B — Study & Habits
- [x] B1 Modelo `HabitTask`.
- [x] B2 CRUD local/persistencia.
- [x] B3 Timer de estudio persistente.
- [x] B4 Recurrencia.
- [x] B5 Historial/racha.
- [x] B6 Plantilla Biblia 10 min.
- [x] B7 Planes de estudio por referencias.
- [x] B8 Backup/restore schema v10 + compatibilidad v9.
- [~] B9 Mobile/Web implementado y compilado; smoke UX final diferido.

**Gate B:** tareas sobreviven cierre/reapertura y backup; Fe tasks no aparecen con Fe OFF.

## Fase C — Identidad y roles
- [x] C1 Perfil cloud: esquema/RPC validado en Supabase efímero; despliegue remoto diferido.
- [x] C2 Capacidades athlete/coach: contrato local + persistencia cloud/RLS validados en Supabase efímero.
- [x] C3 Sesión permanente separada de la sesión anónima de Haven Faith.
- [x] C4 Cloud Sync migrado para consumir la identidad compartida.
- [x] C5 RLS base validada dinámicamente en Supabase aislado.
- [x] C6 Tests pgTAP de aislamiento y rechazo de sesión anónima.

**Gate C:** VERDE automático en entorno Supabase aislado. Esto valida implementación y seguridad base; no significa que las migraciones estén desplegadas en producción.

## Fase D — Coach/Client MVP
- [x] D1 Relaciones/invitaciones con código hasheado y expiración.
- [x] D2 Consentimiento + permisos configurables.
- [x] D3 Lista de relaciones/clientes vinculados mediante RPC restringido.
- [x] D4 Cliente detalle.
- [x] D5 Asignar programa versionado sin copiar historial del entrenador.
- [x] D6 Cliente recibe, revisa e instala programa sin reescribir historial pasado.
- [x] D7 Progreso compartido con contrato mínimo y permisos separados.
- [x] D8 Revocar acceso con corte inmediato de RLS y limpieza de caché visible.
- [x] D9 Auditoría RLS/pgTAP de aislamiento multiusuario.

**Gate D:** VERDE automático en run #13. Entrenador A no puede leer Cliente B no vinculado; revocar la relación corta el acceso sin borrar el historial propio del cliente. El smoke UX humano permanece diferido al gate local final.

## Fase E — Tareas del entrenador
- [x] E1 Asignar tarea con permiso explícito `assign_tasks`, fecha/recurrencia y backend normalizado.
- [x] E2 Cliente completa u omite ocurrencias; un resultado final no se reescribe retroactivamente.
- [x] E3 Adherencia separa completadas/omitidas/pendientes y conserva historial tras archivar.
- [x] E4 Comentarios bilaterales append-only; el entrenador necesita permiso `comment`.
- [~] E5 Recordatorios locales opt-in implementados/compilados; smoke de notificación física diferido al gate final.

## Fase F — Alimentación V1
- [x] F1 Contrato de plan y backend no clínico implementados y validados en CI/pgTAP.
- [x] F2 Editor entrenador conectado al detalle del cliente y compilado/validado.
- [x] F3 Vista cliente + historial de versiones implementados y validados.
- [x] F4 Versionado inmutable validado dinámicamente en Supabase efímero.
- [x] F5 Permisos/RLS + pgTAP específicos verdes.
- [x] F6 Avisos/scope no clínico implementados en UI compartida.
- [x] F7 Tests Dart + pgTAP + UI con CI verde.

## Fase F2 — Nutrición Inteligente personal / Food Vision
- [x] N1 Contrato de estimación energética por rangos para adultos.
- [x] N2 Objetivos de mantenimiento/ajuste gradual protegidos por gate adulto backend.
- [x] N3 Food Vision multimodal con foto y respuesta estructurada.
- [x] N4 Resultado por rangos, ingredientes, porciones, supuestos y confianza.
- [x] N5 Guard backend fail-closed: sin acceso adulto no se devuelven calorías/macros numéricos.
- [x] N6 Privacidad: la imagen no se persiste; historial local guarda solo resultado/contexto.
- [x] N7 Cámara/galería Mobile + selector Web implementados y compilados; smoke físico queda en gate local.
- [x] N8 Reanálisis con contexto + editor estructurado de ingredientes/porciones implementados.
- [x] N9 Historial Food Vision opt-in, local-first, borrable y sin persistir imágenes.
- [x] N10 Rate limit dedicado + métricas agregadas sin PII/contenido + dataset contractual de evaluación.
- [~] N11 Dataset/validador automático cubre simple, mixto, salsa oculta y baja confianza; falta smoke live del modelo cuando se despliegue.
- [~] N12 Cliente/Edge usan gate backend fail-closed; concesión/revocación service-role documentada. La comprobación de edad operativa concreta se define antes del release.

## Fase G — Coach 2.0
- [x] G1 Biblioteca explícita: guardar como plantilla y crear programa fresco desde plantilla, sin compartir rotación/historial.
- [x] G2 Métricas de adherencia implementadas en tareas y progreso compartido.
- [x] G3 Check-ins con backend/RLS/UI/comentarios y pgTAP validados en CI.
- [x] G4 Comparación 7d vs promedio semanal 30d implementada y validada.
- [x] G5 Alerta operativa por inactividad implementada sin inferencia médica y validada.
- [x] G6 Exportación segura de resumen mediante portapapeles implementada y validada.

## Fase H — Cierre
- [x] H1 CI #32 final: Analyze/Core + Mobile + Web + Edge + Supabase + Android + iOS, 7/7 verde.
- [x] H2 Upgrade incremental Roadmap 2 → Roadmap 3 validado en CI #32 antes del rebuild limpio.
- [x] H3 Suite de backward compatibility v9/v10 + auditoría R2 ejecutada en Core tests.
- [x] H4 Android debug/profile/release APK + AAB + split ABI verdes en CI #32; smoke físico permanece en L09.
- [~] H5 iOS release/profile sin codesign verdes + IPA unsigned generado en #32; validación física permanece en L10.
- [~] H6 Web dart2js/WASM verde en #32; smoke PWA real, gesto Back, Push y audio quedan en L08.
- [x] H7 RLS/pgTAP verde tras upgrade incremental R2→R3 y rebuild limpio en #32.
- [x] H8 auditoría de assets + RV1909/licencias documentadas; asset sin procedencia fue eliminado.
- [~] H9 estructura responsive/controles compilados; teclado, Dynamic Type y UX física quedan en L08/L10.
- [x] H10 benchmarks 1k/5k sesiones y 25/100 clientes ejecutados en Core tests de #32.
- [x] H11 suite de regresión R2 (Memory, Unilateral, Progreso, Programas, backups) verde en #32.
- [~] H12 política respetada: no se hizo merge; queda pendiente únicamente la autorización explícita del usuario cuando finalicen los gates manuales.

---

# 17. Decisiones que no deben tomarse accidentalmente

- [x] No forzar contenido religioso: opt-in global triestado + gates Mobile/Web.
- [x] Desactivar Fe no borra notas/favoritos/datos locales.
- [x] Fe OFF bloquea inicialización/descarga; cubierto por test.
- [x] Se mantiene una arquitectura compartida; coach es capacidad/feature, no una segunda app.
- [x] Colaboración usa tablas/RPC normalizados; backup cloud no es base multiusuario.
- [x] Acceso Coach exige relación activa + permisos + RLS.
- [x] RV1909 y catálogo usan licencia/fuente documentada; no se distribuye contenido adicional sin permiso.
- [x] Nutrición V1/Food Vision prohíben diagnóstico/tratamiento y mantienen scope no clínico.
- [x] Snapshots Coach limitan historial reciente; test de escala verifica payload acotado.
- [x] Se mantiene rama aislada; sin merge ni deploy remoto durante implementación.

---

# 18. Auditoría de producto — observaciones actuales

1. El onboarding móvil actual pregunta objetivo, experiencia y días y recomienda un preset; es una buena base, pero no existe un perfil de personalización completo.
2. Web actualmente entra directamente al layout principal; necesita onboarding propio/paridad de preferencias.
3. `SettingsState` ya posee `showDailyVerse` y notificaciones, lo que permite migrar sin perder compatibilidad, pero falta una bandera de módulo `faithEnabled`.
4. El arranque móvil ya difiere la inicialización bíblica; con Roadmap 3.0 debe omitirla por completo cuando Fe esté desactivada.
5. El arranque web inicializa Biblia tras el primer frame sin considerar todavía una preferencia global de Fe; debe cambiarse.
6. Existe autenticación permanente para Cloud Sync, pero no debe asumirse que ya existe un modelo de identidad/roles/relaciones adecuado para entrenador-cliente.
7. Las funciones entrenador requieren backend normalizado + RLS; no deben implementarse solo con Hive o backups.
8. El modo entrenador aumenta notablemente el alcance del producto y debe desarrollarse después de cerrar personalización/hábitos, no en paralelo a todo.

---

# 19. Estado inicial del Roadmap 3.0

- [x] Plan de producto/arquitectura documentado.
- [x] Riesgos principales identificados.
- [x] Orden de fases definido.
- [x] Implementación iniciada.
- [x] Gate A automático (smoke manual final diferido).
- [~] Gate B — automático verde; smoke UX/local final diferido.
- [ ] Gate C — migración base preparada, aún sin validación dinámica.
- [x] Gate D — automático verde; smoke UX final diferido.
- [~] Gate E — automático verde; solo smoke físico del recordatorio queda diferido.
- [ ] Gate F.
- [ ] Gate G.
- [ ] Gate H.

**Estado:** IMPLEMENTACIÓN AUTOMÁTICA CERRADA — CI #32 7/7 verde. Permanecen únicamente smokes físicos/PWA, verificación live de funciones que requieren despliegue remoto y la autorización futura de merge/deploy. Ninguna migración Roadmap 3 ha sido aplicada al Supabase remoto.
