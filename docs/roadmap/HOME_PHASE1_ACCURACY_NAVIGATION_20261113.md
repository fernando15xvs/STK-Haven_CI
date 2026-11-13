# STK Haven · Inicio — Fase 1: exactitud y navegación

**13-11-2026. Fuente de verdad:** `STK-Haven/main`; cambios en
`fix/home-phase1-data-navigation-20261113`, una sola PR canónica privada.
Espejo `STK-Haven_CI/main` únicamente para Actions y artefactos,
sin PR en el espejo. Esta fase no rediseña Inicio ni cambia la persistencia.

## Contratos

1. **Sesión completada hoy:** usar fecha **local de finalización** y
   conjunto no vacío de series efectivas todas completadas. Excluir filas
   importadas con finalización futura. Si comienza antes de medianoche y acaba
   hoy, es "Finalizado hoy". Entre varias, usar la última finalizada.
2. **Actividad del calendario y de Inicio:** una sesión parcial con trabajo
   efectivo registrado sí genera día activo. Sesión vacía, pendiente o
   futura no genera día activo. Calendario, volumen diario y actividad semanal
   utilizan fecha **local de finalización**. No convertir parcial en completa.
3. **Progreso del programa legado:** contar sesiones por ID único, rutinas
   propias y fechas desde su activación, con series efectivas completamente
   finalizadas y sin filas futuras. No contar sesiones parcialmente terminadas
   como completadas. Porcentaje de barra = semana transcurrida, **no** volumen
   de trabajo realizado; mantener esa distinción.
4. **Inicio sin doble presentación:** cuando el mismo ID aparece en
   "Finalizado hoy", ocultar su duplicado en "Último entrenamiento".
   Un PR sigue siendo un evento diferente, pero su detalle pertenece
   a Progreso > Ejercicios.
5. **Navegación:** "Ver análisis en Progreso" abre explícitamente
   la subpestaña **Resumen**, incluso si el usuario visitó "Medidas".
   Mantener vivas las pestañas y el período compartido; no crear una segunda
   instancia de Progreso dentro del flujo principal.
6. **Acciones:** "Finalizado hoy" ofrece un único botón explícito de
   detalle más "Editar nota", sin un segundo tap global idéntico.
   "Último entrenamiento" abre la sesión exacta; PR enlaza por `exerciseId`
   a la ficha correcta cuando el catálogo aún conserva ese ejercicio.

## Checklist de entrega

- [x] Política pura para contador del programa y exclusión del duplicado.
- [x] Usar finalización local en estado de hoy / actividad semanal / calendario.
- [x] Evitar sesiones vacías y futuras en actividad semanal.
- [x] Corregir el salto Inicio → Progreso → Resumen sin resetear filtros.
- [x] Simplificar acciones de la tarjeta completada y enlazar resultados recientes.
- [x] Añadir pruebas de sesión parcial, sin trabajo, cruce de medianoche,
      fecha futura, programa, IDs repetidos y tarjeta semanal a 320 dp.
- [x] Fase 1: CI espejo 7/7 verde, corrida
      [#43449105484](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/43449105484).
- [x] Fase 1: paridad de contenido Git 12/12 archivos del snapshot canónico.
- [ ] QA en iPhone/Android físico y lector de pantalla: pendiente hasta evidencia.
- [ ] Fusionar exclusivamente la PR canónica tras fases 2 y 3, CI y revisión.

**No se tocó:** esquemas/credenciales Supabase, Hive, notas históricas,
recompensas, progresión de rutinas, gráficos, Coach, Motivation, Fe o assets.
Las fases 2 (interfaz) y 3 (rendimiento/QA ampliado) siguen separadas.
