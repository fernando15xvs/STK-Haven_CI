# STK Haven — Progreso 2.0: ejercicios unificados y balance muscular

> Documento vivo y checklist de ejecución. Actualizar casillas con commits **verificados**, nunca con promesas. Fecha de inicio: 2026-10-17.
>
> Fuente de verdad: **fernando15xvs/STK-Haven** (sin workflows/actions). Validaciones y artefactos: **fernando15xvs/STK-Haven_CI**, espejo. No modificar el esquema de Supabase en esta fase.

## Objetivo y reparto de responsabilidades

- **Progreso > Resumen:** consistencia, resultados globales y futuras observaciones basadas en datos.
- **Progreso > Ejercicios:** único explorador de rendimiento por ejercicio, e1RM, PR, progreso, comparaciones, RIR, unilateral e historial; filtro temporal y búsqueda.
- **Progreso > Músculos:** carga muscular por grupo, frecuencia semanal, cobertura, distribución y planificación; nunca duplicar récords por ejercicio.
- **Progreso > Medidas:** perímetros y mediciones corporales con recordatorios; evitar inferir masa muscular solo por aumento de perímetro.
- **Biblioteca de ejercicios:** técnica/configuración y enlace a la ficha de rendimiento, sin tener dos tableros paralelos.
- **Inteligencia:** retirar entradas redundantes; análisis explicable en la superficie correcta.

## Fase 0 — Auditoría y planificación

- [x] Inventariar `ProgressPage`, `ProgressIntelligencePage`, `ExerciseDetailPage` y `MuscleHeatmapGrid`.
- [x] Confirmar datos repetidos del mismo `ExerciseProgressCalculator` y ausencia de IA generativa en Inteligencia.
- [x] Definir superficies, no duplicación, migración segura y criterios de aceptación.
- [x] Crear este roadmap sincronizado en ambos repositorios.

## Fase 1 — Una única pantalla de análisis por ejercicio

- [x] Exponer un widget reutilizable sin Scaffold para `Progreso > Ejercicios` desde el análisis avanzado existente.
- [x] Añadir búsqueda por nombre y filtros 30/90 días/todo; estado vacío claro y navegación a detalle/técnica.
- [x] Conservar e1RM, PR, anterior vs actual, series/reps/RIR, historial y comparación unilateral sin perder datos.
- [x] Eliminar la tarjeta duplicada previa de Ejercicios, y el acceso independiente a Inteligencia del menú móvil.
- [x] Retirar el resumen de volumen muscular de la ficha de ejercicios; Músculos tendrá esa responsabilidad.
- [x] Mantener `ProgressIntelligencePage` como redirección/compatibilidad interna para enlaces previos.
- [x] Pruebas del filtrado y del panel de Ejercicios en Flutter, más análisis estático.

## Fase 2 — Modelo de distribución muscular confiable

- [x] Calcular por grupo la frecuencia (días distintos), últimas fechas de trabajo y series efectivas directas.
- [x] Incluir grupos conocidos con cero actividad y semanas completas comparables.
- [x] Separar secundarios **estimados**, sin atribuirles series completas como si fueran directas; permitir omitirlos.
- [x] Comparar planificación vs. ejecución sin contar series de calentamiento/aproximación, con límites explícitos.
- [x] Mejorar `Progreso > Músculos` con resumen interpretable y detalle contextual de cada músculo, sin PR duplicados.
- [x] Añadir pruebas de ejercicios mixtos, unilaterales, incompletos, período vacío y frecuencia por día.

## Fase 3 — Observaciones inteligentes explicables

- [x] Generar observaciones deterministas de constancia, progreso y reparto muscular a partir de datos verificables.
- [x] Mostrar período y justificación del cálculo; evitar diagnósticos, prescripción automática o juicios corporales.
- [x] Evitar duplicaciones entre Resumen, Ejercicios, Músculos y Medidas; permitir descartar avisos.
- [x] Pruebas con historial insuficiente, señales contradictorias, cambios de período y datos incompletos.

## Fase 4 — Calidad, seguridad de datos y publicación móvil

- [ ] Confirmar formato de pesos kg/lb, históricos, ejercicios personalizados, sesiones y backups sin migración destructiva.
- [ ] Confirmar rendimiento en historiales largos, modo ahorro, accesibilidad, texto grande y pantallas de 320 px.
- [x] Ejecutar Flutter analyze + pruebas Core/móvil en **STK-Haven_CI solamente**.
- [x] Compilar iOS release/profile sin firma y Android debug/profile/release/AAB en el espejo.
- [x] Verificar paridad de árboles originales y CI (solo workflow/metadatos exclusivos del espejo).
- [x] Integrar en `main` original sin ejecutar Actions y después sincronizar `main` espejo; registrar SHA/CI.
- [ ] Pruebas manuales en iPhone y Android tras instalar; **no prometer** validación física previa.

## Reglas de producto

- Las estadísticas de series, volumen, e1RM, PR y frecuencia se basan en sesiones registradas, no garantizan hipertrofia o recuperación.
- Una serie **efectiva** completada es `WorkoutSetType.working`; no contar calentamiento, aproximación, movilidad ni estiramiento como series efectivas.
- El músculo primario proviene de la instantánea histórica; secundarios de catálogo son inferencia etiquetada, jamás alterar registros anteriores.
- No introducir cambios de sincronización, privacidad o Supabase sin análisis y permiso específico.
- Marcar un checklist solo tras confirmar la modificación o validación correspondiente.

## Bitácora de implementación

- **2026-10-17 · Fase 1, código preparado:** panel único de Ejercicios con filtro temporal 30/90/todo, búsqueda, métricas avanzadas, análisis unilateral y acceso a técnica; eliminado el duplicado móvil de Inteligencia y los agregados musculares de Ejercicios. Prueba de widget de 320 px y búsqueda **aprobada**, junto con el análisis estático y las pruebas Core/móviles. **Integración a main completada.**

- **2026-10-17 · CI validado:** ejecución [#39056630059](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39056630059) — **6/6 jobs aprobados**: móvil, Core/análisis, iOS profile/release, Android debug/profile/release/AAB/split, Supabase/RLS y Edge. Paridad de árboles confirmada salvo workflows/metadatos exclusivos del espejo. La validación física en teléfonos sigue pendiente.

- **2026-10-17 · Fase 1 fusionada:** `STK-Haven/main` = [7bf4619](https://github.com/fernando15xvs/STK-Haven/commit/7bf4619f9b8bc49eca22290b3df7de1c189e9059); `STK-Haven_CI/main` = [967a087](https://github.com/fernando15xvs/STK-Haven_CI/commit/967a08773d2110b9c210e873ced0ad68ecbecf4c). PR [#28](https://github.com/fernando15xvs/STK-Haven_CI/pull/28) fusionado. Sigue pendiente la fase 2 de balance muscular y la validación manual en teléfonos.

- **2026-10-17 · Fase 2 validada y fusionada:** PR [#29](https://github.com/fernando15xvs/STK-Haven_CI/pull/29). CI [#39058649590](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39058649590) **6/6 verde**: pruebas móviles (incluye 320 px), Core de reparto muscular, analyze, Supabase/RLS, iOS y Android. `STK-Haven/main`: [40f2989](https://github.com/fernando15xvs/STK-Haven/commit/40f29894c508cb5d13ee9c4773ef30f183eb8f65); `STK-Haven_CI/main`: [d74b426](https://github.com/fernando15xvs/STK-Haven_CI/commit/d74b4269a37129d4b8e02f2b079d8fc5ebe06e57). Se guardó **código**, sin cambios de Supabase ni de historial. Comparativa de rutinas existentes = referencia al plan actual en sesiones ya ejecutadas; secundarios = estimación opcional y separada; dos semanas completas independientes del filtro de días. Fase 3 (observaciones inteligentes) y pruebas manuales en teléfonos siguen pendientes.

- **2026-10-17 · Fase 3 validada e integrada:** reglas de consistencia semanal, evolución de e1RM y distribución muscular en el **Resumen** (sin nueva pestaña), con evidencias explícitas y umbrales de suficiencia. Avisos descartables/restaurables persistidos localmente; no se sincronizan, ni diagnostican, ni prescriben cargas. Pruebas de meses/filtros, semanas incompletas, datos insuficientes y contradictorios, contenido explicable y interfaz de 320 px. PR [#30](https://github.com/fernando15xvs/STK-Haven_CI/pull/30) fusionado; [CI #39060386652](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39060386652) **6/6 verde**. Código inicial `STK-Haven/main`: [98a7805](https://github.com/fernando15xvs/STK-Haven/commit/98a7805322d317957082c28aab4b44f241c81030); espejo `STK-Haven_CI/main`: [fb116d2](https://github.com/fernando15xvs/STK-Haven_CI/commit/fb116d2550e7a8dd3e9aa02d1d35095e3487d06e). Las pruebas físicas iPhone/Android y restantes auditorías de fase 4 siguen pendientes.
