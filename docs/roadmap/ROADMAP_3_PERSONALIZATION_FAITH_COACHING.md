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
- [ ] Preguntar por Reduce Motion / modo ahorro solo desde ajustes, no sobrecargar onboarding inicial.

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
- [ ] Pausar/reanudar programa no pierde la posición.
- [x] Duplicar un programa nuevo empieza en su primera rutina, sin compartir estado mutable.
- [ ] Deload/mesociclo no altera el orden salvo una acción explícita del usuario.

## 2A.3 Integración UI

- [x] Inicio muestra claramente “Próxima sesión: Upper/Lower ...”.
- [x] Programas muestra secuencia y posición actual.
- [x] Calendario proyecta futuras sesiones respetando días disponibles y continuidad entre semanas.
- [x] Workout iniciado desde “Próxima sesión” usa la rutina esperada.
- [ ] Si el usuario abre manualmente otra rutina, la UI deja claro que no avanzará la rotación esperada.
- [x] Mobile y Web presentan la misma fuente de verdad.

## 2A.4 Validación automática obligatoria

Agregar tests con la secuencia exacta:

`UA, LA, UB, LB, UA, LA, UB, LB, UA, LA, UB...`

sobre lunes/martes/jueves/viernes/sábado durante varias semanas.

- [x] Test exacto del ejemplo de 3 semanas.
- [x] Test de semana nueva sin reset.
- [ ] Test de día omitido.
- [ ] Test de cambio de días disponibles.
- [x] Test de workout libre/off-sequence.
- [x] Test de persistencia/rehidratación.
- [ ] Test de backup/restore.
- [x] Test de proyección de calendario.
- [ ] Test mobile/web del texto “Próxima sesión”.

> Nota técnica: Roadmap 2.0 ya contiene un `ProgramRotationCoordinator` secuencial e independiente del weekday. Roadmap 3.0 debe auditar y conectar **toda la UI/calendario/lanzamiento de workout** a esa fuente de verdad, porque el comportamiento actual visible no cumple todavía el caso Upper A/Lower A/Upper B/Lower B descrito arriba.

**Gate 2A:** la secuencia continúa correctamente entre semanas, descansos y ausencias sin depender de un mapeo fijo por weekday.

---

# 3. Módulo Fe opcional — hard opt-in

## 3.1 Estado actual a corregir

Actualmente existen preferencias como `showDailyVerse`, pero el concepto de “mostrar el versículo” no debe ser equivalente a “habilitar todo el módulo Fe”.

- [x] Crear `faithEnabled` mediante `UserExperienceProfile.faithEnabled` + preferencia triestado.
- [ ] Mantener `showDailyVerse` como subpreferencia.
- [ ] Mantener notificaciones como subpreferencia independiente.
- [x] Condicionar inicialización de Biblia a `faithEnabled == true`.
- [x] Condicionar providers de versículo a módulo habilitado.
- [x] Condicionar accesos rápidos en mobile.
- [x] Condicionar navegación lateral/secciones en web.
- [ ] Deshabilitar limpiamente sin borrar notas/favoritos del usuario.
- [ ] Permitir reactivar y recuperar contenido local anterior.
- [ ] Tests de “Fe OFF” sin inicialización de DB.
- [ ] Tests de “Fe ON” con carga bajo demanda.
- [ ] Verificar que Fe OFF mejore startup y no haga requests innecesarios.

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

- [ ] Definir modelo.
- [ ] Repositorio local.
- [ ] Provider.
- [ ] Backup/restore.
- [ ] Tests de recurrencia.
- [ ] Tests de zona horaria/cambio de día.
- [ ] No castigar al usuario por perder una racha: mostrar progreso, no culpa.

## 4.2 “Estudiar la Biblia 10 minutos”

Si `faithEnabled == true`:

- [ ] Plantilla “Leer la Biblia — 10 min”.
- [ ] Timer simple.
- [ ] Elegir libro/capítulo antes o durante la sesión.
- [ ] Marcar sesión completada.
- [ ] Añadir nota/reflexión.
- [ ] Guardar pasaje de referencia sin duplicar grandes textos.
- [ ] Estadística semanal de minutos de lectura.
- [ ] Historial de estudio.
- [ ] Recordatorio opcional.

## 4.3 Planes de estudio bíblico

Ideas:

- Evangelio de Juan en N días.
- Salmos seleccionados.
- Proverbios por capítulos.
- Lectura cronológica (solo si se define y valida el plan).
- Temas: gratitud, disciplina, sabiduría, perseverancia.

- [ ] Motor de planes independiente del texto bíblico.
- [ ] Plan define referencias, no copia masiva de texto.
- [ ] Progreso por día/sesión.
- [ ] Pausar/reanudar.
- [ ] Cambiar de plan sin perder historial.
- [ ] Offline cuando el contenido esté disponible localmente.

## 4.4 Libros y material adicional

Opciones seguras de producto:

- notas propias del usuario;
- artículos escritos específicamente para STK Haven;
- obras de dominio público;
- contenido con licencia explícita;
- enlaces externos a contenido del autor/editor.

- [ ] Crear catálogo con metadatos de licencia.
- [ ] Nunca distribuir libros con copyright sin permiso.
- [ ] No incluir PDFs/ebooks de terceros solo porque estén disponibles en internet.
- [ ] Registrar fuente/licencia de cada obra.
- [ ] Soporte de marcadores/notas.
- [ ] Búsqueda por título/autor/tema.

---

# 5. Riesgo crítico — contenido bíblico y licencias

La implementación actual descarga una Biblia desde un repositorio/CDN externo. Antes de ampliar Fe:

- [ ] Auditar la licencia de la traducción usada actualmente.
- [ ] Auditar la licencia del dataset concreto descargado.
- [ ] No asumir que una Biblia es de dominio público por estar alojada en GitHub/CDN.
- [ ] Definir traducción legalmente distribuible/offline.
- [ ] Definir fallback cuando el proveedor/CDN no esté disponible.
- [ ] Evitar que una URL de terceros sea infraestructura crítica.
- [ ] Documentar atribución/licencia en la app cuando corresponda.
- [ ] Revisar licencias de cualquier libro/devocional adicional.

Riesgo: **alto** si se distribuye contenido protegido sin permiso.

---

# 6. Cuentas y capacidades — Usuario / Entrenador

## 6.1 Decisión de diseño

No crear dos aplicaciones ni dos tablas de usuario incompatibles.

Un usuario puede tener capacidades:

- `athlete` — usa STK Haven para sí mismo;
- `coach` — administra asesorados;
- opcionalmente ambas.

- [ ] Crear `user_profiles` ligado a Supabase Auth.
- [ ] Crear capacidades/roles.
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

- [ ] El entrenador crea tarea.
- [ ] Cliente la recibe.
- [ ] Estado pendiente/completada/omitida.
- [ ] Fecha límite opcional.
- [ ] Repetición.
- [ ] Comentario cliente.
- [ ] Comentario entrenador.
- [ ] Notificaciones opcionales.
- [ ] El cliente puede diferenciar tarea propia vs asignada.
- [ ] Historial no editable retroactivamente sin trazabilidad.

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
- [ ] Biblia no se inicializa con Fe OFF.
- [ ] Paginación de clientes/historial.
- [ ] Queries agregadas para dashboards.
- [ ] No descargar todo el historial de todos los clientes.
- [ ] Cache acotada.
- [ ] Evitar blur/compositing costoso móvil.
- [ ] Benchmarks con 1k/5k sesiones se mantienen.
- [ ] Dataset de prueba con 25/100 clientes para dashboard web.
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
- [~] B1 Modelo `HabitTask`.
- [~] B2 CRUD.
- [~] B3 Timer de estudio.
- [~] B4 Recurrencia.
- [~] B5 Historial/racha.
- [~] B6 Plantilla Biblia 10 min.
- [~] B7 Planes de estudio.
- [~] B8 Backup/restore.
- [~] B9 Mobile/Web.

**Gate B:** tareas sobreviven cierre/reapertura y backup; Fe tasks no aparecen con Fe OFF.

## Fase C — Identidad y roles
- [ ] C1 Perfil cloud.
- [ ] C2 Capacidades athlete/coach.
- [ ] C3 Sesión permanente.
- [ ] C4 Migración de Cloud Sync.
- [ ] C5 RLS base.
- [ ] C6 Tests de aislamiento.

**Gate C:** un usuario sin rol coach no puede consultar endpoints/datos coach.

## Fase D — Coach/Client MVP
- [ ] D1 Relaciones/invitaciones.
- [ ] D2 Consentimiento.
- [ ] D3 Lista de clientes.
- [ ] D4 Cliente detalle.
- [ ] D5 Asignar programa.
- [ ] D6 Cliente recibe programa.
- [ ] D7 Progreso compartido.
- [ ] D8 Revocar acceso.
- [ ] D9 Auditoría.

**Gate D:** entrenador A jamás puede leer Cliente B no vinculado.

## Fase E — Tareas del entrenador
- [ ] E1 Asignar tarea.
- [ ] E2 Cliente completa.
- [ ] E3 Adherencia.
- [ ] E4 Comentarios.
- [ ] E5 Recordatorios.

## Fase F — Alimentación V1
- [ ] F1 Contrato de plan.
- [ ] F2 Editor entrenador.
- [ ] F3 Vista cliente.
- [ ] F4 Versionado.
- [ ] F5 Permisos.
- [ ] F6 Avisos/scope.
- [ ] F7 Tests.

## Fase G — Coach 2.0
- [ ] G1 Plantillas.
- [ ] G2 Métricas de adherencia.
- [ ] G3 Check-ins.
- [ ] G4 Comparaciones por periodo.
- [ ] G5 Alertas operativas no médicas.
- [ ] G6 Exportes.

## Fase H — Cierre
- [ ] H1 Analyze/tests completos.
- [ ] H2 Migraciones desde Roadmap 2.
- [ ] H3 Backups antiguos.
- [ ] H4 Android.
- [ ] H5 iOS.
- [ ] H6 Web/PWA.
- [ ] H7 Seguridad/RLS.
- [ ] H8 Licencias de contenido.
- [ ] H9 Accesibilidad.
- [ ] H10 Auditoría de rendimiento.
- [ ] H11 Regresión completa de Roadmap 2.
- [ ] H12 Merge solo con autorización explícita.

---

# 17. Decisiones que no deben tomarse accidentalmente

- [ ] No forzar contenido religioso a usuarios que no lo quieran.
- [ ] No borrar datos de Fe al desactivar el módulo.
- [ ] No inicializar/descargar Biblia con Fe desactivada.
- [ ] No crear dos aplicaciones separadas para “normal” y “entrenador”.
- [ ] No usar backup cloud como base de datos multiusuario.
- [ ] No permitir acceso del entrenador por simple conocimiento del email/id del cliente.
- [ ] No distribuir libros/Biblias sin licencia confirmada.
- [ ] No transformar “plan alimenticio” en diagnóstico o tratamiento médico automático.
- [ ] No cargar todos los clientes/historias al iniciar la app.
- [ ] No hacer merge/deploy sin cerrar gates acordados.

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
- [ ] Gate B.
- [ ] Gate C.
- [ ] Gate D.
- [ ] Gate E.
- [ ] Gate F.
- [ ] Gate G.
- [ ] Gate H.

**Estado:** EN IMPLEMENTACIÓN — Fase A cerrada automáticamente en CI. Fase B (Study & Habits) está implementándose y sus pruebas locales permanecen diferidas al gate final.
