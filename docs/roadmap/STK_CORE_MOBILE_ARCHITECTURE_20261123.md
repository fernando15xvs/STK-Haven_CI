# STK Haven — Roadmap de arquitectura estricta Core ↔ Mobile
**Fecha:** 23/11/2026  
**Alcance aprobado:** Core = lógica/datos; Mobile = presentación e integración de plataforma; Web = pausada.  
**Entrega:** PR canónica #57 (DRAFT), espejo `STK-Haven_CI/main` exclusivamente para GitHub Actions.  
**Estado:** planificación. Ninguna migración de código forma parte de este commit.

## Objetivo innegociable
- `packages/core` **no importa interfaz**: no puede contener pantallas, widgets, `BuildContext`, `ThemeData`, `MaterialApp`, estilos/recursos de UI ni dependencias directas o transitivas de presentación. Meta final: paquete independiente del SDK Flutter y de plugins específicos de plataforma, con código Dart de dominio/aplicación/datos y puertos abstractos para integraciones.
- `apps/app_mobile` contiene **toda la UI iOS/Android**: páginas, navegación, widgets, diseño, tipografías, estilos, adaptadores nativos y composición/DI de la aplicación.
- `apps/app_mobile` **nunca importa nada de `apps/app_web`** (archivos, recursos ni paquetes propios de Web); `packages/core` tampoco importa Mobile ni Web. El grafo permitido es **Mobile → Core**, jamás Core → Mobile/Web ni Mobile → Web.
- `apps/app_web` está **congelada**: no nuevos cambios ni obligación de adaptar/compilar Web en este roadmap. Registrar su último estado funcional antes de mover API públicas, porque el Web pausado podría dejar de compilar si todavía consume UI de Core.
- No modificar lógica de entrenamiento, nutrición o datos para justificar un cambio visual. Conservar IDs, rutinas, sesiones, historial, backups, preferencias, datos demográficos consentidos y estado de onboarding. Sin migraciones destructivas ni merge automático.

## Diagnóstico de partida (árbol GitHub de la rama de la PR, 23/11/2026)
- `packages/core/lib` tiene **341 archivos Dart de producción**; **60** ubicados en carpetas `presentation/`, de los cuales **36** son rutas `pages/` o `widgets/`. Esos conteos orientan la auditoría, **no prueban que todos sean UI**: los providers de estado no visuales pueden seguir en Core tras eliminar dependencias UI.
- Existen pantallas dentro de Core, p. ej. `features/profile/presentation/pages/appearance_settings_page.dart`, `personal_profile_page.dart`, `features/coach/presentation/pages/coach_hub_page.dart`, `features/workout/presentation/widgets/quick_set_entry_dialog.dart` y varias pantallas de nutrición, hábitos, Fe, programas, progreso, sync y Coach Pro.
- Core también aloja `core/theme/appearance_theme.dart` (devuelve `ThemeData`) y `core/theme/app_palette.dart` (`ThemeExtension`/colores Flutter): **ambos deben salir de Core**.
- `packages/core/pubspec.yaml` declara `flutter`, `flutter_riverpod`, `hive_flutter` y plugins como `image_picker`, `share_plus`, `flutter_local_notifications`, `supabase_flutter`. Hay que clasificar sus usos y mover integraciones de dispositivo a adaptadores Mobile; **no quitar dependencias a ciegas**.
- Mobile ya tiene `core/theme/app_colors.dart` con `AppTypography`, `AppSpacing`, `AppRadius` y otros tokens; varias pantallas aún importan directamente páginas desde Core. El sistema de diseño debe estar centralizado **solo en Mobile**.
- `domain/models/appearance_settings.dart` ya serializa preferencias como datos Dart puros: puede ampliarse para guardar `fontFamily`, `fontSize` y `uiStyle` sin almacenar tipos Flutter ni introducir una dependencia visual.
- El workflow de espejo existente ejecuta Core y Mobile, y **excluye expresamente `apps/app_web`**. Hay que añadir reglas de arquitectura y mantener esa exclusión.

## Arquitectura objetivo

`packages/core/lib/` (Dart puro, libre de UI)
- `domain/`: entidades, enums de negocio, validaciones, decisiones y preferencias serializables (sin `Color`, `TextStyle`, `ThemeData` ni `Widget`).
- `application/` y `features/*/application/`: casos de uso, políticas de entrenamiento/calorías/descansos, estado de aplicación independiente de widgets, coordinación.
- `data/` + `features/*/data/`: contratos y repositorios; implementaciones sin dependencias visuales; persistencia local/remota si es independiente del dispositivo.
- `ports/` (o interfaces por feature): abstracciones para foto, archivos, notificaciones, audio, preferencias nativas, base de datos y servicios que hoy usan plugins. Core define el contrato; Mobile inyecta implementaciones de plataforma.
- Proveedores de estado puramente lógicos pueden vivir en Core; reemplazar `flutter_riverpod` por `riverpod` puro (o un equivalente Dart) cuando corresponda, conservando APIs y tests.

`apps/app_mobile/lib/`
- `design_system/`: `app_typography.dart`, `app_colors.dart`, `app_spacing.dart`, `app_radius.dart`, `app_ui_styles.dart`, `app_theme.dart`, `components/`. **Cada token/componente canónico en un solo lugar; evitar duplicados por pantalla**.
- `features/*/presentation/`: TODAS las páginas, widgets, formularios, gráficos, diálogos y flujos visuales, incluidos los que ahora están dentro de Core.
- `platform/` o `infrastructure/`: adaptadores concretos iOS/Android para foto, audio, archivos, Hive inicialización, Supabase inicialización, notificaciones, widgets de sistema y permisos; separar lógica de políticas en Core.
- `shared/app/`: `MaterialApp`, `ThemeData`, rutas, ciclo de vida Flutter, composición e inyección de providers/adaptadores.

### Dependencias admitidas / prohibidas
| Origen | Puede importar | Nunca puede importar |
|---|---|---|
| Core | Dart, modelos, lógica y repositorios Core, librerías Dart no visuales | `package:flutter/material.dart`, `widgets.dart`, `cupertino.dart`, `flutter_riverpod`, `apps/app_mobile`, `apps/app_web`, componentes/temas de UI |
| Mobile | Core, widgets Flutter, diseño Mobile, adaptadores del dispositivo | `apps/app_web`, paquetes o recursos internos exclusivos de Web |
| Web pausada | Sin trabajo nuevo | No es puerta de aprobación de CI de esta entrega |

**Meta adicional:** eliminar del `pubspec` de Core la dependencia de `flutter` y los plugins de UI/plataforma cuando se hayan movido todos sus consumidores. Que no existan imports prohibidos **ni indirectos** a través de `export` o `part`. El motor debe poder analizarse/testearse independientemente de Mobile; no reubicar lógica de negocio en widgets por comodidad.

## Fase A — Inventario exhaustivo y línea base (sin alterar apariencia)
**Avance A.1 (23/11/2026):** [auditoría preliminar](../architecture/STK_CORE_MOBILE_AUDIT_BASELINE_20261123.md) e [inventario de fuentes](../architecture/STK_CORE_MOBILE_SOURCE_INVENTORY_20261123.md) guardados en la misma PR. En el corte se inspeccionaron los 62 archivos Core de presentación/tema (52 visuales, 2 tema, 8 providers), declaraciones de import/export/part de los 114 archivos Mobile de producción y 17 servicios Core + 15 archivos críticos de integraciones. Se identificaron 18 consumidores Mobile→Core UI y ninguna importación directa de Mobile→Web en esos 114. **Fase A sigue EN CURSO**: inspeccionar las 279 rutas Core restantes y los tests, resolver el grafo completo y documentar contratos de puertos. No declarar arquitectura limpia todavía.
- [x] A.1: árbol de archivos reproducible, inventario de Core/Mobile/test y referencia Web congelada.
- [x] A.1: primera clasificación de Core `presentation`/tema y dependencias directas de Mobile.
- [x] A.2 instrumentada: `tools/architecture_inventory.py` recorre todas las fuentes/test con salida JSON; el espejo CI adjunta informe en modo diagnóstico (sin exigir todavía cero violaciones).
- [x] A.2 léxica: JSON automatizado sobre 890 Dart en [CI #45307024472](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/45307024472) y [resultados](../architecture/STK_ARCHITECTURE_AUTOMATED_RESULTS_20261123.md): 55 Core UI, 70 Core Flutter, 170 Core plugins, 25 Mobile→Core UI; 0 Core→Mobile/Web y 0 Mobile→Web directos.
- [ ] A.2 semántica: revisar esos consumidores, dependencias transitivas y migraciones de pruebas; el escaneo léxico no valida la pureza completa.
- [ ] A.3: resolución de dependencias indirectas, plataformas y modelos/servicios mezclados.
- [ ] A.4: validar baseline del último SHA y completar la matriz archivo-por-archivo.

- [ ] Enumerar/importar **todos** los archivos de producción y tests Core/Mobile y construir mapa real de dependencias, `export`, `part`, referencias inversas y plugins.
- [ ] Clasificar Core por archivo: lógica/modelo, provider Dart puro, widget/página, Theme/Color, servicio de dispositivo o mezcla lógica+UI (requiere extraer caso de uso).
- [ ] Identificar todas las referencias Mobile→UI de Core y cualquier Mobile→Web o Core→Mobile/Web; registrar números y rutas exactas en `docs/architecture/`.
- [ ] Registrar baseline de prueba visual (claro, oscuro, OLED), funcional y persistencia; conservar commit SHA de Web congelada para su futura reanudación.
- [ ] Establecer matriz de riesgos: entrenador activo y temporizadores, series unilaterales, nutrición +15 años, foto/consentimiento, autenticación y backup.
**Criterio de salida:** inventario revisable con rutas reales, plan de migración archivo por archivo y baseline verde previo.

## Fase B — Frontera de dependencias y CI
**Avance B.1:** guardia progresiva operativa en el espejo: se congelan **303 declaraciones import/export/part preexistentes** por huella estable (path + NUL + URI) y **2 rutas transitivas Core→UI**. Los nuevos imports Core UI/Flutter/SDK/plataforma o Core→Mobile/Web y Mobile→Web hacen **fallar** CI; eliminar los antiguos está permitido. [Clasificación semántica](../architecture/STK_ARCHITECTURE_SEMANTIC_TRIAGE_20261123.md) y [baseline congelado](../architecture/STK_CORE_LEGACY_IMPORT_BASELINE_20261123.md).
- [x] B.1: baseline inmutable de importaciones heredadas (303) y transitivas (2), documentado desde auditor de GitHub Actions.
- [x] B.1: `tools/architecture_guard.py` y siete pruebas de regresión para Core/Flutter, Mobile→Web y borrado de deuda antigua; la etapa de guardia pasó en el primer CI.
- [ ] B.2: refinar cobertura semántica (Dart analyzer), pruebas sobre exportación transitiva, plugins y dependencias indirectas, y reducir la allowlist hasta cero.
- [ ] B.3: cierre de CI 7/7 **del último HEAD** tras el piloto de importaciones puras.
- [ ] Crear test/guardia de importaciones con análisis Dart (no solo `grep`): Core no importa Material/Widgets/Cupertino, presentaciones, Mobile ni Web; Mobile no importa Web; detección también de `export`/`part` y dependencias de `pubspec`.
- [ ] Durante la transición, **allowlist explícita y decreciente** para violaciones heredadas con ruta+motivo; fallar ante cualquier violación nueva. Al finalizar migración: allowlist VACÍA y CI obligatoriamente verde.
- [ ] Añadir pruebas de interfaces/adaptadores, dependencias circulares y pureza de providers. No crear una PR nueva ni modificar los jobs del Web pausado.
- [ ] Ejecutar `Analyze Core`, `Analyze Mobile`, tests Core/Mobile y compilaciones iOS/Android desde el espejo. Sin declarar éxito hasta verificar los siete gates obligatorios en el SHA final.
**Criterio de salida:** guardia activa en CI y nuevas dependencias prohibidas imposibles de introducir inadvertidamente.

## Fase C — Extraer lógica, migrar UI de Core a Mobile
**Avance consolidado C.1.c.3 (24/11/2026):** se extrajeron juntas las implementaciones de versículos, mensajes personales, medidas y resolución nativa de zona horaria a Mobile. Los tests que interceptan canales Flutter de Fe/Medidas se trasladan a Mobile; Core mantiene sus APIs y settings de negocio mediante contratos Dart y test de puertos. Incluye toda la familia de notificaciones del descanso, hidratación, pasos, Coach, hábitos, Fe y Medidas. [Contrato y riesgos](../architecture/STK_C1C3_NATIVE_REMINDERS_CONSOLIDATION_20261124.md). **CI del nuevo SHA y QA física aún sin aprobar; C.1 (migración nativa) no es el cierre de toda C (queda UI/tema).**


**Avance C.1 (23/11/2026):** [Puerto nativo de entrenamiento y pruebas](../architecture/STK_C1_WORKOUT_NATIVE_PORT_20261123.md). Core conserva reglas de descanso y delega al adaptador Mobile los efectos de notificaciones, tono y vibración. La implementación anterior de `WorkoutNotificationService` sigue temporalmente en Core hasta migrar los demás consumidores.
- [x] C.1.a: introducir `WorkoutNativeServices` Dart puro, proveedor inyectable, implementación Mobile y override único en bootstrap Android/iOS.
- [x] C.1.a: eliminar `flutter/widgets.dart` y `flutter/services.dart` de `active_workout_provider.dart`; conservar IDs, plazos y notificaciones nativas.
- [x] C.1.a: pruebas Core del puerto y contratos Mobile de tono sin cambio de foco musical, cancelación OS y Live Activity.
- [ ] C.1.a: obtener 7/7 verde y QA física de música, avisos, timer y suspensión.
- [x] C.1.b: trasladar la implementación completa de `WorkoutNotificationService` a Mobile, conservando fachada `WorkoutNotificationBackend` Dart puro en Core e inyección desde el bootstrap; colas, permisos, IDs y Live Activities sin alterar. [Contrato y QA](../architecture/STK_C1B_MOBILE_WORKOUT_NOTIFICATIONS_20261123.md).
- [ ] C.1.b: confirmar CI 7/7 del último HEAD y QA física de audio/temporizador.
- [ ] C.1.c: migrar `LocalNotificationTimezone`, recordatorios de agua/pasos/Fe/Coach y los demás servicios Flutter de Core a adaptadores Mobile, sin cambiar el comportamiento.
**Avance C.1.c.2 (23/11/2026):** recordatorios de tareas de Coach, tareas de hábitos y Coach Pro mantienen las mismas APIs públicas pero usan puertos Dart en Core e implementaciones nativas en Mobile, instaladas en el bootstrap de Android/iOS. Se preservan IDs fijos 41810–41812, rangos estables de hash 200M/300M, canales, cadencias y notificaciones privadas. [Contrato y QA C.1.c.2](../architecture/STK_C1C2_COACH_HABITS_NATIVE_REMINDERS_20261123.md). Pendiente CI 7/7 de este SHA, QA física; los recordatorios de Fe, Medidas, motivación personal y zona horaria todavía permanecen en Core y se abordarán con sus pruebas de plugins.

**C.1.c.1 implementado (23/11/2026):** Hidratación/Pasos ahora delegan por puertos Dart a implementaciones Mobile inyectadas en bootstrap; [contrato y QA](../architecture/STK_C1C_WELLNESS_REMINDERS_20261123.md). Pendiente CI del nuevo SHA, QA física y servicios restantes antes de cerrar C.1.c.
**Piloto C.0 (compatible):** sustituir únicamente el import `hive_flutter` por `hive` Dart puro en ocho repositorios Core que reciben un `Box` y no inicializan Flutter. No hay cambios de claves, escritura, serialización, servicios de base de datos ni onboarding. Esta migración reduce ocho declaraciones prohibidas y dispone de test de contrato; requiere CI del último HEAD antes de contarse como validada.
- [x] C.0: revisión de ocho repositorios Hive sin `Hive.initFlutter()`; cambio de import puro con el mismo `Box` y mismo comportamiento.
- [x] C.0: test automatizado que impide regresar a `hive_flutter` en esos ocho archivos.
- [ ] C.0: confirmar Core tests, Mobile tests y compilaciones nativas 7/7 del commit de piloto.
- [ ] Mover `AppearanceTheme`/`AppColors` Flutter a Mobile preservando la salida visual; dejar en Core solo datos serializables de preferencias.
- [ ] Migrar pantallas/widgets de Perfil, Aspecto, Preferencias, Sync e Identidad y actualizar imports, rutas y pruebas; extraer previamente reglas de negocio embebidas.
- [ ] Migrar pantallas/widgets de Entrenar, Workout, Programas, Progreso, Nutrición, Coach/Coach Pro, Hábitos y Fe desde Core a Mobile por grupos de dependencias.
- [ ] Reubicar servicios con `BuildContext`/navegación, `flutter_riverpod` y plugins de dispositivo en Mobile/adaptadores, manteniendo en Core las políticas y puertos. Mantener interoperabilidad de IDs y la inyección de dependencias.
- [ ] Eliminar imports/exportaciones visuales de Core. Quitar dependencias Flutter/plataforma de Core `pubspec.yaml` al alcanzar cero consumidores. No duplicar implementaciones definitivas.
- [ ] Mover pruebas widget a Mobile y conservar/ampliar tests de casos de uso en Core.
**Criterio de salida:** **0 pantallas/widgets/material/BuildContext/ThemeData y 0 importaciones UI/plataforma en Core**; **0 referencias a Web en Mobile**; API de lógica Core estable y tests verdes.

**Avance C.2 (24/11/2026):** trasladadas **54 fuentes UI/tema** desde `packages/core/lib` a `apps/app_mobile/lib`, con sus imports reescritos hacia Core solo para dominio, providers y datos. **14 tests widget** que importaban UI pasan a `apps/app_mobile/test/migrated_core`; referencias en rutas, widgets, diseño y tests móviles actualizadas. [Inventario de alcance, regresiones y estado](../architecture/STK_C2_MOBILE_ONLY_PRESENTATION_20261124.md). CI del SHA nuevo **pendiente**, no fusionar ni declarar C completa. Aún es necesario retirar dependencias Flutter de providers/servicios Core y comprobar que la allowlist termina en cero. Web continúa congelada sin adaptaciones.

**C.3 — corte de dependencias preparado (24/11/2026):** 167 tests de Core convertidos a `package:test`, sin bindings/widget tests de Flutter, y `pubspec.yaml` de Core deja solo dependencias Dart. Las implementaciones SQFlite (`biblia_v4.db`), Workmanager, SharedPreferences, MethodChannel de Fe, import/export y compartición de archivos se alojan en Mobile; Core conserva contratos, lógica CSV, programación y snapshots de negocio. Se instala la misma instancia de backend al arrancar Android/iOS (y SQLite en el isolate Workmanager). Ver [invariantes de C.3](../architecture/STK_C3_PURE_DART_PLATFORM_PORTS_20261124.md). **Este bloque no es definitivo hasta pasar CI 7/7, trasladar los providers lógicos de rutas `presentation`, auditar imports transitivos y dejar el gate estricto en cero.**

**C.4 — cierre estructural preparado (24/11/2026):** los últimos ocho providers de estado de Core, sin widgets ni APIs Flutter, salen de carpetas `presentation/providers` a `application/providers`. Se actualizan las referencias Core/Mobile y las pruebas sin editar Web. Se añade `tools/core_purity_gate.py` como aceptación estricta: **0 imports prohibidos, 0 Dart UI en Core, 0 Core→Mobile/Web, 0 Mobile→Web y 0 imports no resueltos en Core/Mobile**. C se declarará cerrado únicamente cuando el último commit pase los siete jobs obligatorios del espejo y el gate de pureza; el QA físico queda registrado como tarea separada de fase F.

## Fase D — Sistema visual centralizado SOLO en Mobile
- [ ] Consolidar archivos canónicos `app_typography.dart`, `app_colors.dart`, `app_spacing.dart`, `app_radius.dart`, `app_ui_styles.dart`, `app_theme.dart` y componentes reutilizables.
- [ ] Migrar estilos locales de Inicio, Entrenar, Progreso, Nutrición, Perfil, modales, gráficos y tablas hacia tokens y componentes; añadir lint/guardias contra nueva duplicación.
- [ ] Mantener **Outfit + apariencia existente** como referencia de compatibilidad antes de añadir opciones; revisar pesos variables de fuentes, contraste y diseño responsivo.
- [ ] Crear las 3 variantes **Clásico, Minimalista y Compacto** como políticas visuales coherentes; el estilo no altera navegación, cálculos, rutas ni objetivos táctiles.
- [ ] Agregar 4 tipografías seleccionables (**Outfit, Inter, Manrope, Plus Jakarta Sans**) y tamaños **Pequeño, Mediano, Grande, Personalizado**, respetando Dynamic Type/accesibilidad y modo sin conexión.
- [ ] Core solo persiste la selección tipada (sin Flutter `TextStyle`, `Color` o `ThemeData`), con lectura backward-compatible y valores por defecto; Mobile traduce esa preferencia a estilos.
**Criterio de salida:** un cambio de fuente/escala/estilo se refleja globalmente, sin archivos de interfaz duplicados ni alteraciones no solicitadas de funcionalidad.

**Entrega D.1 — Tipografía y UI Styles (24/11/2026):** selección persistente en Core (Clásico/Minimalista/Compacto, Outfit/Inter/Manrope/Plus Jakarta Sans, Pequeño/Mediano/Grande/Personalizado), fuentes variables empaquetadas bajo licencia SIL OFL en Mobile, tema centralizado y tokens separados de tipografía, espacios, radios y estilos. Componentes Card/Input/Button/PremiumCard comparten geometría; `TextScaler` combina la preferencia con la escala del sistema. Valores predeterminados antiguos idénticos; pruebas Dart de retrocompatibilidad y widgets de fuente/estilos/contraste. [Alcance](../architecture/STK_PHASE_D_DESIGN_SYSTEM_20261124.md). **No dar D por cerrado hasta que el CI del nuevo SHA esté 7/7 y se auditen los estilos locales de las pantallas restantes.**

## Fase E — Rediseño aprobado de Perfil, Editar perfil y Ajustes
- [ ] **Perfil lectura directa**: foto grande, nombre, objetivo, experiencia y demás datos autorizados guardados, con estados «Sin definir» si corresponde; Nivel y logros continúan en Perfil.
- [ ] Mantener **Editar perfil** como acción secundaria para cambiar los datos, sin obligar a entrar para verlos; conservar foto y avatar, edición de datos opcionales y control de consentimiento.
- [ ] Engranaje superior derecho → pantalla **Ajustes**; mover allí todas las Preferencias, Servicios, Privacidad, notificaciones, entrenamiento/unidades, experiencia y Fe.
- [ ] Ajustes: interruptor rápido claro/oscuro con iconos sol/luna, conservando **Automático** como opción dentro de Aspecto y modo OLED si aplica.
- [ ] Aspecto: misma información y acentos, reorganización UX + tipografía, tamaño y tres UI Styles con vista previa consistente.
- [ ] Validar que Perfil muestre solo datos reales autorizados, sin exponer ni duplicar datos privados; guardar/editar no restablece onboarding ni datos antiguos.
**Criterio de salida:** Perfil identifica al usuario sin navegar a editar, Ajustes concentra configuración y todos los cambios se guardan/restauran.

## Fase F — Auditoría final y entrega
- [ ] Repetir auditoría completa de import/export/dependencias con **allowlist vacía**, incluyendo test automatizado que impida reintroducir UI en Core y Web en Mobile.
- [ ] Pruebas de migración/persistencia (`AppearanceSettings.fromJson` antigua+nueva, Hive, offline, perfiles existentes, rutinas, backups) y contract tests de providers/adaptadores.
- [ ] UI 320/390/430 dp × texto 100/160/200%; iOS/Android, claro/oscuro/OLED, VoiceOver/TalkBack, navegación, teclado, foto/avatar, gráficos/tablas y tarjetas.
- [ ] Probar timers, música de terceros/notificaciones, sesiones activas, unilateral, nutrición, Fe y Coach sin regresión.
- [ ] Verificar **7/7 jobs en verde** del último commit en `STK-Haven_CI`, mismo contenido funcional en ambos repositorios, PR #57 DRAFT sin merge.
- [ ] QA física real y generar IPA/APK solo desde commit validado; IPA firmada correctamente para actualizar sin pérdida de datos.
**Criterio de salida:** arquitectura estricta probada, apariencia profesional uniforme, datos intactos y evidencia de pruebas físicas pendiente de aprobación final.

## Reglas de ejecución
1. **No empezar por un rediseño visual aislado**: primero dependencias, pruebas y migración de Core; después personalización y Perfil.
2. Trabajar sobre **una sola PR #57**. Espejo solo CI, sin PR espejo ni Actions en principal.
3. Cada fase exige evidencia: archivos movidos, imports eliminados, tests, checklist actualizado, artefactos cuando correspondan. CI verde viejo no valida un nuevo commit.
4. **No tocar `apps/app_web`**. Si queda incompatible por API antigua, registrarlo como deuda de Web pausada sin bloquear la entrega Mobile; guardar SHA anterior.
5. Sin migraciones destructivas, sin eliminar historial/sesiones/configuración ni reiniciar onboarding; decisiones sobre datos se prueban antes de cambiar persistencia.
6. No declarar terminada la arquitectura hasta **0 violaciones** de los límites de dependencia, no simplemente porque Flutter compile.

## Estado
- [x] Arquitectura objetivo y alcance Web pausada acordados.
- [x] Roadmap redactado y guardado en GitHub.
- [ ] A, B, C, D, E y F: **pendientes de implementación**, sujetos a sus criterios de salida.
