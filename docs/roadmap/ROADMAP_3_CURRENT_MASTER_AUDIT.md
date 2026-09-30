# STK Haven — Auditoría maestra del estado actual

**Corte:** 2026-09-30  
**Alcance:** cambios posteriores al cierre automatizado de Roadmap 3, desde el
preview aislado hasta la corrección del teclado de Safari. No repite la auditoría
histórica completa de Roadmap 3.

## 1. Estado verificado

| Elemento | Estado |
| --- | --- |
| Fuente de verdad | `fernando15xvs/STK-Haven` |
| Rama de trabajo | `feat/roadmap-3-foundation` |
| Candidato funcional auditado | `54316a63e3b3e67c9a9a756311349dfdfb385cfc` |
| Mirror público de validación | `fernando15xvs/STK-Haven_CI` · `main` |
| Snapshot validado | `ef61c33cbbf818d23c385a69d4acee9a0e4e83d4` |
| Publicación Pages | `d69ddb297695d5c9e7af881a897e7d2f4350825c` |
| Preview validado | `https://fernando15xvs.github.io/STK-Haven_CI/?v=ef61c33c` |
| `main` de la fuente | Sin modificar y sin merge |
| Supabase remoto | Sin migraciones ni despliegues en esta entrega |

## 2. Trabajo completado

### A. Preview web/PWA aislado

- Se creó un workflow que publica únicamente después de que el CI público queda
  verde.
- El preview usa `STK_STORAGE_NAMESPACE=roadmap3_preview`; separa
  SharedPreferences, cajas Hive/IndexedDB y datos locales de la aplicación
  estable.
- Los caches del service worker, manifiesto, nombre e identidad PWA también son
  independientes.
- La rama `gh-pages` se genera limpia, sin código fuente, enlaces simbólicos ni
  archivos temporales de Flutter.
- La PWA estable de STK Haven no fue modificada.

### B. Navegación y rendimiento web móvil

- Se bloqueó el Back del navegador y el `edge-swipe` de Safari como navegación
  de Flutter; la navegación válida permanece en las flechas internas.
- Al volver desde pantallas como Notificaciones se conserva la pestaña de origen
  en vez de regresar siempre a Inicio.
- Se eliminó la recarga completa y el splash provocados por el historial del
  navegador.
- En pantallas compactas sólo se renderiza la pestaña raíz activa; escritorio
  conserva las pestañas visitadas mediante carga diferida.

### C. Inicio, hidratación y pasos

- Se simplificó Inicio y se retiraron accesos repetidos del bloque de fe.
- Hidratación permite una meta personal, registro de consumo y recordatorio
  local configurable y opcional.
- Se añadió conteo diario de pasos: sensor nativo en Android, CoreMotion en iOS
  y registro manual en Web.
- Se rediseñaron las tarjetas de bienestar para móvil y web.

### D. Planes de entrenamiento

- El plan recomendado se personaliza con los días de entrenamiento elegidos por
  el usuario y migra planes heredados sin perder datos.
- Se separó la frecuencia objetivo de los días del calendario.
- Se implementaron tres modos: rotación continua, semana fija y flexible.
- La siguiente sesión y el volumen se proyectan según el modo; una semana puede
  alternar correctamente 3 torso/2 pierna y luego 2 torso/3 pierna.
- Se añadió frecuencia muscular real, diferenciando participación total y grupo
  principal.
- La pantalla muestra información accionable del plan y permite reordenar
  rutinas arrastrándolas.
- La reconciliación es idempotente: una sesión ya procesada no avanza dos veces
  la rotación.

### E. Rutinas y entrenamiento activo

- “Series de trabajo” pasó a mostrarse como **Series efectivas**.
- La memoria de rendimiento se conserva por posición de serie; no mezcla datos
  entre series del mismo ejercicio.
- Una rutina puede incluir, de forma opcional, ejercicios de movilidad al inicio
  y estiramiento al final. Los datos antiguos sin fase se interpretan como
  ejercicio principal.
- Movilidad y estiramiento tienen tipos propios y no cuentan como series
  efectivas obligatorias.
- Al intentar finalizar con series efectivas pendientes se pide confirmación.
- Si se guarda un entrenamiento incompleto, conserva el mismo ID, progreso y
  tiempo; puede reabrirse desde el aviso y completarse después.
- Al completar una sesión reanudada se reemplaza el registro parcial, se elimina
  el borrador y la rotación avanza exactamente una vez.
- Sólo las sesiones completas cuentan para progreso, rotación y benchmarks.
- Al finalizar se cancela el aviso de descanso con manejo tolerante a fallos,
  evitando que un error de notificación bloquee el guardado.

### F. Teclado, guardado y Safari

- Las entradas de peso, repeticiones y RIR agrupan cambios durante 350 ms y los
  confirman al pulsar “Listo” o tocar fuera; esto reduce escrituras y el tirón al
  guardar.
- Se añadió un puente web específico; las pruebas de Dart VM usan una
  implementación vacía y no importan APIs JavaScript.
- Durante la apertura/cierre del teclado se conserva la altura física de
  `<flutter-view>` y se notifican de nuevo las métricas en varios puntos de la
  animación tardía de WebKit.
- Se eliminó la reducción manual de `html/body` a
  `visualViewport.height`, causante del espacio negro.
- El fondo del documento queda opaco en `#090A0C`, evitando destellos si WebKit
  expone el documento entre frames.
- La corrección fue confirmada por el usuario en Safari físico. El resultado
  anterior que todavía fallaba correspondía al cache persistente de Safari; el
  enlace versionado cargó la compilación correcta.

## 3. Evidencia de validación

- Flutter fijado en `3.38.9`; Dart `3.10.8`.
- CI público #69, run `36738073218`: **7/7 jobs correctos**.
- Incluyó Analyze + Core tests, Mobile tests, Web tests + dart2js/WASM,
  Android APK/AAB, iOS release/profile sin firma, Edge Functions y Supabase
  efímero + RLS.
- Preview #30, run `36739631215`: **success**.
- Pages #18, run `36739835166`: **success**.
- Se verificó en la salida publicada la presencia del bloqueo de
  `<flutter-view>`, el fondo opaco y la ausencia del resize antiguo.
- La ejecución anterior falló únicamente porque un literal JavaScript del test
  no estaba marcado como cadena raw de Dart; quedó corregido antes del CI #69.

## 4. Límites y pendientes reales

- No existe un bug abierto dentro de este bloque: Safari fue probado y confirmado.
- Android e iOS compilan y pasan sus gates, pero el cierre del teclado todavía
  merece un smoke manual en dispositivos físicos; el defecto negro identificado
  era específico de Flutter Web + Safari.
- No hacer merge a `main`, no desplegar backend y no aplicar migraciones remotas
  sin una autorización nueva y explícita.
- Para el estado general de despliegue remoto sigue siendo autoritativo
  `docs/roadmap/ROADMAP_3_SUPABASE_REMOTE_DEPLOY_AUDIT.md`.

## 5. Reglas para continuar

1. Confirmar primero el HEAD remoto de `feat/roadmap-3-foundation`.
2. Implementar siempre en `STK-Haven`; el repositorio CI es sólo un mirror de
   validación/publicación.
3. Sincronizar exactamente el cambio al mirror, esperar los 7 jobs y publicar el
   preview sólo después del verde.
4. No modificar la PWA estable ni reutilizar su almacenamiento.
5. No repetir los arreglos ya cerrados; partir del estado indicado en este
   documento y del nuevo pedido del usuario.

## 6. Prompt de continuidad

```text
Continúa STK Haven desde el estado verificado del 30/09/2026.

Fuente de verdad: fernando15xvs/STK-Haven
Rama exclusiva: feat/roadmap-3-foundation
Mirror de CI/preview: fernando15xvs/STK-Haven_CI, rama main

Primero lee completo:
1. docs/roadmap/ROADMAP_3_CURRENT_MASTER_AUDIT.md
2. docs/roadmap/ROADMAP_3_FINAL_LOCAL_TEST_AUDIT.md
3. docs/roadmap/ROADMAP_3_SUPABASE_REMOTE_DEPLOY_AUDIT.md

Estado funcional auditado antes del documento:
- fuente: 54316a63e3b3e67c9a9a756311349dfdfb385cfc
- CI: ef61c33cbbf818d23c385a69d4acee9a0e4e83d4
- Pages: d69ddb297695d5c9e7af881a897e7d2f4350825c
- CI #69: 7/7; Preview #30 y Pages #18: success
- Safari físico confirmó que ya no aparece el espacio negro al cerrar el teclado.

Reglas: no tocar main, no merge, no desplegar backend, no aplicar migraciones
al Supabase remoto y no modificar la PWA estable. Implementa primero en la
fuente y después sincroniza exactamente al mirror. Antes de cambiar algo,
verifica que los HEAD remotos no hayan avanzado.

Ya están cerrados: preview aislado; navegación Back/edge-swipe; rendimiento web
móvil; hidratación y pasos; planes adaptativos con frecuencia separada del
calendario; series efectivas; movilidad/estiramiento opcionales; recuperación de
entrenamientos incompletos; memoria por serie; guardado agrupado; y corrección
del teclado Safari. No los rehagas salvo que una nueva evidencia reproduzca un
fallo.

No hay una incidencia pendiente en este bloque. Continúa únicamente con el
siguiente pedido del usuario, preservando estas restricciones y dejando pruebas,
commits y estado de CI documentados con precisión.
```
