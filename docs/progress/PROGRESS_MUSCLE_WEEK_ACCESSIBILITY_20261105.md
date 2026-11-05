# Progreso 2.0 — rango semanal de Balance muscular (DES parcial)

Fecha: 2026-11-05 · Rama: `fix/progress-muscle-week-label-accessibility-20261105`.

## Defecto comprobado en código

La fila `muscle_week_comparison` coloca a la derecha un `Text` de
`dd/MM → dd/MM` sin `Flexible`, al lado de un `Expanded`. Un
texto grande o ancho compacto puede generar un RenderFlex overflow.
Además, VoiceOver/TalkBack no recibe años ni el significado de cada
fecha («semana anterior» y «semana reciente»).

## Corrección acotada

- El rango visible conserva `dd/MM → dd/MM` y tipografía
  `AppTypography.labelMedium` Outfit.
- El texto va en `Flexible`, con `softWrap: true` y alineación final:
  puede ocupar varias líneas sin recortarse ni esconder el rango.
- La semántica pronuncia ambas fechas completas con año y diferencia
  la semana anterior de la semana reciente, sin duplicar el contenido
  decorativo.
- El color se obtiene de `AppColors.of(context).textSecondary`,
  incluyendo OLED y acentos.
- El cálculo de semanas completas y grupos musculares, los conteos de
  series, las fechas reales, Hive, Supabase, backups, Coach, Motivation,
  workout reanudable y XP quedan intactos.

## Pruebas

`apps/app_mobile/test/muscle_balance_panel_test.dart` contiene el
caso integrado de balance con sesiones históricas parciales y la matriz:
anchos 320, 375, 390, 430 dp × escalas 1.0, 1.3, 1.6 × tema claro,
oscuro OLED; las 24 combinaciones comprueban el texto completo
accesible, Outfit, colores y ausencia de overflow.

**Gate de fusión:** 7/7 jobs obligatorios SUCCESS en
`STK-Haven_CI/main` y blobs de todos los archivos modificados con SHA
idéntico al PR del repositorio canónico. Un solo PR canónico; espejo
solo para Actions, sin PR adicional.

**Pendientes no reclamados como terminados:** auditorías DES-01/03/04/
05/06/07/08/09, DATA-09, GAM-01 y QA de dispositivos iOS/Android. No
confundir CI verde con pruebas físicas de lectores de pantalla.
