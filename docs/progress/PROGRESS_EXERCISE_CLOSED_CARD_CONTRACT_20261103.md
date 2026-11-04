# Progreso 2.0 — Contrato de tarjeta cerrada de ejercicio (UX-03)

**Fecha:** 2026-11-03 · **Alcance:** `Progreso > Ejercicios`.

## Información suficiente sin desplegar

La tarjeta cerrada de un ejercicio con evidencia debe mostrar:

- **Nombre** del ejercicio identificado por `exerciseId`, incluidos ejercicios
  personalizados. La tipografía deriva de `Theme.textTheme` para heredar
  Outfit y preferencias de escala.
- **Fecha** de la última sesión efectiva **en el filtro visible**, antes
  del nombre de la rutina. Puede ocupar dos líneas al 160 % sin eliminar la
  fecha para mostrar el nombre.
- **Último e1RM**, expresado en kg/lb según preferencias, o
  «Última sesión sin e1RM» si no existe una estimación válida.
- **Variación** «Vs. anterior: +X kg/lb» / «-X kg/lb» solo cuando existen
  dos observaciones de e1RM positivas en el **mismo filtro visible**.
  En caso contrario, «Sin comparación». Un mejor histórico fuera del filtro
  no se usa artificialmente como última sesión previa.

No se infiere progreso solo por la fecha o por un único levantamiento.
El récord de toda la vida, si es distinto del último e1RM, continúa visible
**solo al desplegar** la tarjeta como dato separado (DATA-04 / PR #44).

## Accesibilidad y datos

La información usa tres textos en una columna, sin depender de color,
símbolos ni widgets que solo aparezcan al tocar. El nombre y los datos
pueden ocupar más de una línea, pero no se duplican las tarjetas PR/e1RM
de la ficha técnica. Se conserva la navegación a ficha, historial y
gráfica del ejercicio exacto.

La lista de sesiones, historial Hive, algoritmo de e1RM, recompensas,
rutinas, Coach y Motivation **no se alteran**.

## Regresión

`apps/app_mobile/test/progress_unified_exercises_test.dart`:
- Una sesión: fecha + e1RM + `Sin comparación` visibles sin expandir.
- Dos sesiones en el período: variación presente y no se muestra
  `Sin comparación`; la tarjeta desplegada separa mejor histórico.
- Pico antiguo fuera de 1M: historial máximo visible en desplegada pero
  `Sin comparación` en resumen del período.
- Ejercicio personalizado con nombre extenso, pantalla 320 px, texto 160 %:
  fecha, e1RM y estado sin desbordamiento.

CI del espejo público 7/7 y blobs SHA idénticos son obligatorios antes de
fusionar. VoiceOver/TalkBack y pruebas físicas siguen abiertas en QA.
