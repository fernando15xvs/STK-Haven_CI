# Roadmap 3.0 — Auditoría final de pruebas locales necesarias

## Objetivo

Concentrar **todas las pruebas locales/manuales en una sola etapa final**.

Durante la implementación de Roadmap 3.0 no se pedirá al usuario ejecutar repetidamente `flutter analyze`, `flutter test`, builds o matrices locales si esas comprobaciones pueden realizarse mediante GitHub Actions u otra validación automatizada disponible.

La fuente de verdad de implementación sigue siendo el repositorio privado. El mirror público de CI se utilizará para validaciones automáticas continuas.

---

# 1. Qué NO se deja para pruebas locales del usuario

Estas comprobaciones deben realizarlas CI/automatización durante el desarrollo:

- `flutter pub get`;
- `flutter analyze --no-fatal-infos`;
- tests unitarios de `packages/core`;
- tests de `apps/app_mobile`;
- tests de `apps/app_web`;
- tests de migraciones y backward compatibility;
- tests de backup/restore con Hive temporal;
- tests de rotación de programas;
- tests de recurrencia/timers que puedan simularse;
- tests de RLS/aislamiento multiusuario cuando se implemente Coach;
- Android debug/profile/release APK;
- Android AAB;
- Android split ABI;
- Web dart2js;
- Web WASM;
- iOS release/profile `--no-codesign` en runner macOS;
- análisis estático de secretos/configuración pública;
- tests responsive automatizables;
- tests con datasets grandes/benchmarks automatizables.

Si cualquiera falla, se corrige primero en el repositorio privado y después se vuelve a sincronizar el snapshot público.

---

# 2. Pruebas locales finales realmente necesarias

Estas son las pruebas que sí requieren interacción humana, comportamiento real del sistema operativo o validación visual/funcional end-to-end.

## L01 — Upgrade real sin pérdida de datos

**Plataforma mínima:** Android físico.

Objetivo:

- instalar el APK release final sobre una instalación existente;
- conservar rutinas, historial, programas, ajustes, favoritos, progreso y workout activo cuando corresponda;
- confirmar que las migraciones de Roadmap 3.0 no fuerzan onboarding completo a usuarios existentes;
- confirmar que el nuevo perfil de experiencia se crea sin borrar preferencias anteriores.

Criterio de aprobación:

- [ ] aplicación abre;
- [ ] datos Roadmap 2.0 siguen presentes;
- [ ] no aparece pérdida/corrupción de historial;
- [ ] no se obliga a rehacer onboarding antiguo sin motivo.

---

## L02 — Onboarding 2.0 completo

**Plataforma mínima:** Android/emulador o instalación limpia.

Probar únicamente tres recorridos de Fe:

1. Fe = Sí.
2. Fe = No.
3. Fe = Decidir después.

Además comprobar:

- objetivo;
- experiencia;
- días por semana;
- duración;
- lugar/equipamiento;
- recomendación vs autogestión;
- kg/lb;
- recordatorios;
- resumen final;
- edición posterior desde Perfil.

Criterio:

- [ ] cada respuesta persiste después de cerrar/reabrir;
- [ ] no se muestran preguntas redundantes;
- [ ] volver atrás conserva respuestas;
- [ ] usuario existente no recibe onboarding completo por una actualización.

---

## L03 — Fe ON/OFF visible y realmente opcional

Probar dos estados:

### Fe OFF

- [ ] no aparece versículo diario;
- [ ] no aparece Biblia;
- [ ] no aparece Haven Faith;
- [ ] no aparecen tareas/estudio bíblico;
- [ ] no aparecen notificaciones religiosas.

### Fe ON

- [ ] aparecen los accesos;
- [ ] Biblia abre;
- [ ] favorito/nota anterior reaparece si existía;
- [ ] desactivar y reactivar Fe no borra datos del usuario.

La ausencia de inicialización/request de Biblia con Fe OFF se valida principalmente de forma automatizada; localmente solo se verifica comportamiento observable.

---

## L04 — Study & Habits

Probar:

- crear tarea propia;
- tarea recurrente;
- “Leer la Biblia 10 min” cuando Fe esté habilitada;
- iniciar/pausar/finalizar timer;
- background/resume;
- cerrar/reabrir;
- historial;
- nota/reflexión;
- recordatorio real si está habilitado.

Criterio:

- [ ] no pierde progreso;
- [ ] no duplica tareas recurrentes;
- [ ] cambiar de día/zona horaria no crea duplicados evidentes;
- [ ] Fe OFF oculta tareas específicas de Fe.

---

## L05 — Rotación continua de programa

Programa de prueba:

`Upper A → Lower A → Upper B → Lower B → repetir`

Días de entrenamiento:

`lunes, martes, jueves, viernes, sábado`

Secuencia esperada:

### Semana 1
- lunes → Upper A
- martes → Lower A
- jueves → Upper B
- viernes → Lower B
- sábado → Upper A

### Semana 2
- lunes → Lower A
- martes → Upper B
- jueves → Lower B
- viernes → Upper A
- sábado → Lower A

### Semana 3
- lunes → Upper B
- martes → Lower B
- jueves → Upper A
- viernes → Lower A
- sábado → Upper B

Validar también:

- [ ] miércoles/domingo no alteran la secuencia;
- [ ] comenzar una semana nueva no reinicia en Upper A;
- [ ] faltar un día no salta la rutina pendiente;
- [ ] completar una rutina libre/off-sequence no avanza el programa;
- [ ] cerrar/reabrir conserva qué rutina toca;
- [ ] backup/restore conserva qué rutina toca;
- [ ] cambiar días de entrenamiento no cambia el orden de la secuencia;
- [ ] completar la rutina esperada avanza exactamente una posición.

No es necesario esperar tres semanas reales: la validación final puede usar fechas simuladas/datos de prueba controlados y luego un smoke corto en UI.

---

## L06 — Backup/restore end-to-end con datos reales

Crear backup de una cuenta/local con:

- rutinas;
- programa activo;
- progreso;
- unilateral;
- preferencias Roadmap 3;
- Fe/Habits;
- datos de coach si el diseño final los incluye en el alcance permitido.

Restaurar y comprobar:

- [ ] datos equivalentes;
- [ ] rotación del programa continúa en la misma sesión esperada;
- [ ] preferencias Fe se restauran;
- [ ] no se restaura metadata no-restorable;
- [ ] no aparecen duplicados.

---

## L07 — Coach ↔ Cliente end-to-end

Usar dos identidades reales de prueba:

- navegador/web como entrenador;
- móvil o segundo navegador como cliente.

Recorrido mínimo:

1. entrenador invita;
2. cliente acepta;
3. entrenador ve únicamente ese cliente;
4. asigna programa;
5. cliente recibe programa;
6. cliente completa sesión;
7. entrenador ve progreso actualizado;
8. entrenador asigna tarea;
9. cliente completa tarea;
10. entrenador crea/edita orientación alimentaria V1;
11. cliente ve la versión correcta;
12. cliente revoca acceso.

Criterio:

- [ ] después de revocar, entrenador deja de acceder;
- [ ] cliente conserva su propio historial;
- [ ] no aparecen datos de otros clientes;
- [ ] cambios de programa no reescriben historial pasado.

El aislamiento RLS exhaustivo se valida automatizadamente; esta prueba es únicamente UX/end-to-end.

---

## L08 — Web/PWA real

En navegador compatible:

- [ ] onboarding responsive;
- [ ] navegación usuario normal;
- [ ] dashboard entrenador;
- [ ] instalar PWA;
- [ ] cerrar/reabrir PWA;
- [ ] abrir offline lo que deba estar disponible offline;
- [ ] actualizar desde una versión previa sin limpiar caché;
- [ ] no queda service worker sirviendo una versión antigua;
- [ ] teclado/foco básicos funcionan.

---

## L09 — Rendimiento físico Android final

Usar APK release final.

Revisar únicamente:

- arranque;
- Inicio;
- cambio de tabs;
- Progreso;
- workout con varias series;
- timer;
- Memoria;
- programa;
- Coach si está habilitado.

Criterio:

- [ ] no vuelve la sensación de app pesada;
- [ ] no hay bloqueos visibles;
- [ ] scroll razonablemente fluido;
- [ ] background/resume no congela la UI.

Profiling técnico adicional solo se hace si este smoke detecta una regresión.

---

## L10 — iPhone físico antes de release iOS

Solo necesario antes de publicar/distribuir iOS.

- [ ] onboarding;
- [ ] workout/timers;
- [ ] background/resume;
- [ ] notificaciones;
- [ ] Reduce Motion;
- [ ] teclado;
- [ ] SafeArea;
- [ ] Dynamic Type razonable;
- [ ] Fe/Habits;
- [ ] Coach/Client.

Los builds iOS de compilación siguen siendo responsabilidad de CI en macOS; esta prueba es comportamiento físico.

---

# 3. Pruebas que NO se deben duplicar localmente

Si CI está verde en el commit candidato final, no repetir localmente por rutina:

- analyze;
- todos los unit tests;
- todos los widget tests;
- build Android de cada variante;
- build iOS no-codesign;
- build Web WASM;
- tests RLS automatizados;
- benchmarks sintéticos.

Solo repetir localmente si existe una discrepancia específica que CI no pueda reproducir.

---

# 4. Gate final local

Roadmap 3.0 puede considerarse validado localmente cuando:

- [ ] L01–L09 estén aprobados para Android/Web;
- [ ] L10 esté aprobado antes del release iOS;
- [ ] el último snapshot público equivalente al candidato final tenga CI completamente verde;
- [ ] no exista diferencia de código entre el candidato privado auditado y el snapshot CI salvo metadata/documentación del mirror;
- [ ] la auditoría de secretos esté verde;
- [ ] el usuario autorice explícitamente cualquier merge a `main`.

---

# 5. Política durante desarrollo

Hasta llegar al gate final:

- el usuario **no necesita ejecutar pruebas locales intermedias**;
- las validaciones automáticas se ejecutan mediante el mirror público;
- los checks del roadmap solo pasan a `[x]` cuando exista evidencia automática o manual suficiente;
- una fase puede estar implementada sin considerarse cerrada hasta que su validación correspondiente exista.
