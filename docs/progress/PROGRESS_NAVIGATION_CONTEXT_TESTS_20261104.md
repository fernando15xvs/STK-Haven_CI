# Progreso 2.0 — navegación contextual y nombres personalizados (UX-13/14)

**Fecha:** 2026-11-04. **Rama canónica:** `test/progress-navigation-context-320-390-20261104`.

## Contrato

La Biblioteca muestra ejercicios individuales por ID y abre su ficha técnica.
Desde ella se puede abrir **Rendimiento** (panel unificado filtrado al
`exerciseId` original), y luego **Historial completo**. En Rendimiento
iniciado desde Técnica no aparece un botón «Técnica» que regrese al mismo
punto y cause navegación circular. El retroceso retorna una pantalla cada
vez: Historial → Rendimiento → Ficha → Biblioteca.

En `Progreso > Ejercicios`, el panel unificado ofrece rutas contextuales
separadas a **Técnica** y **Historial**, con retorno al mismo panel.
La ficha técnica nunca reproduce gráficos e1RM ni las cinco sesiones
recientes: ofrece solo enlaces a sus propietarios.

El historial filtra por `exerciseId` y no por nombre, por lo que los datos
de un ejercicio distinto no aparecen. Se conserva el significado de
`!completed` = pendiente, sin clasificarlo automáticamente como fallido.
También se corrige la gramática del contador de sesión singular.

Los textos de nombres, músculos secundarios y equipamiento personalizados
no pueden forzar una etiqueta técnica fuera de un dispositivo de 320 px.
Los chips aplican un límite máximo de ancho, `Flexible` y hasta dos/tres
líneas con el mismo estilo `AppTypography`. La tarjeta de Biblioteca usa
`AppTypography.headlineSmall` en lugar de un `fontSize` local de 16 px.

## Regresión automática

`apps/app_mobile/test/features/progress/progress_context_navigation_test.dart`
recorre rutas completas 320 y 390 px, claro/oscuro OLED, texto al 160 %,
nombres y equipamiento largos, lectura independiente de series completas y
pendientes, botón de volver en cada nivel, sin pérdida ni mezcla de ID.
También recorre entrada desde `Progreso > Ejercicios` a Ficha y a Historial.

Las pruebas no alteran entrenamientos, bases Hive, Supabase, programas,
cálculos e1RM ni gamificación. Debe aprobarse CI en espejo 7/7 con
blob-SHA idénticos antes del merge. El test no equivale a prueba física
iPhone/Android ni a auditoría VoiceOver/TalkBack y no autoriza cerrar esos QA.
