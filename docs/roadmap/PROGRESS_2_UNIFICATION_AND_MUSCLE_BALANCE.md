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

- [ ] Calcular por grupo la frecuencia (días distintos), últimas fechas de trabajo y series efectivas directas.
- [ ] Incluir grupos conocidos con cero actividad y semanas completas comparables.
- [ ] Separar secundarios **estimados**, sin atribuirles series completas como si fueran directas; permitir omitirlos.
- [ ] Comparar planificación vs. ejecución sin contar series de calentamiento/aproximación, con límites explícitos.
- [ ] Mejorar `Progreso > Músculos` con resumen interpretable y detalle contextual de cada músculo, sin PR duplicados.
- [ ] Añadir pruebas de ejercicios mixtos, unilaterales, incompletos, período vacío y frecuencia por día.

## Fase 3 — Observaciones inteligentes explicables

- [ ] Generar observaciones deterministas de constancia, progreso y reparto muscular a partir de datos verificables.
- [ ] Mostrar período y justificación del cálculo; evitar diagnósticos, prescripción automática o juicios corporales.
- [ ] Evitar duplicaciones entre Resumen, Ejercicios, Músculos y Medidas; permitir descartar avisos.
- [ ] Pruebas con historial insuficiente, señales contradictorias, cambios de período y datos incompletos.

## Fase 4 — Calidad, seguridad de datos y publicación móvil

- [ ] Confirmar formato de pesos kg/lb, históricos, ejercicios personalizados, sesiones y backups sin migración destructiva.
- [ ] Confirmar rendimiento en historiales largos, modo ahorro, accesibilidad, texto grande y pantallas de 320 px.
- [x] Ejecutar Flutter analyze + pruebas Core/móvil en **STK-Haven_CI solamente**.
- [x] Compilar iOS release/profile sin firma y Android debug/profile/release/AAB en el espejo.
- [x] Verificar paridad de árboles originales y CI (solo workflow/metadatos exclusivos del espejo).
- [ ] Integrar en `main` original sin ejecutar Actions y después sincronizar `main` espejo; registrar SHA/CI.
- [ ] Pruebas manuales en iPhone y Android tras instalar; **no prometer** validación física previa.

## Reglas de producto

- Las estadísticas de series, volumen, e1RM, PR y frecuencia se basan en sesiones registradas, no garantizan hipertrofia o recuperación.
- Una serie **efectiva** completada es `WorkoutSetType.working`; no contar calentamiento, aproximación, movilidad ni estiramiento como series efectivas.
- El músculo primario proviene de la instantánea histórica; secundarios de catálogo son inferencia etiquetada, jamás alterar registros anteriores.
- No introducir cambios de sincronización, privacidad o Supabase sin análisis y permiso específico.
- Marcar un checklist solo tras confirmar la modificación o validación correspondiente.

## Bitácora de implementación

- **2026-10-17 · Fase 1, código preparado:** panel único de Ejercicios con filtro temporal 30/90/todo, búsqueda, métricas avanzadas, análisis unilateral y acceso a técnica; eliminado el duplicado móvil de Inteligencia y los agregados musculares de Ejercicios. Prueba de widget de 320 px y búsqueda **aprobada**, junto con el análisis estático y las pruebas Core/móviles. **Integración a main aún pendiente.**

- **2026-10-17 · CI validado:** ejecución [#39056630059](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39056630059) — **6/6 jobs aprobados**: móvil, Core/análisis, iOS profile/release, Android debug/profile/release/AAB/split, Supabase/RLS y Edge. Paridad de árboles confirmada salvo workflows/metadatos exclusivos del espejo. La validación física en teléfonos sigue pendiente.
