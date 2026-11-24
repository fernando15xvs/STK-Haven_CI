# Fase D · sistema visual en Mobile (24 de noviembre de 2026)

La fuente original de Outfit se conserva y permanece predeterminada.
Se añaden Inter, Manrope y Plus Jakarta Sans desde google/fonts (SIL Open Font License 1.1), cada una con su licencia junto al archivo.

## Configuración compatible con datos anteriores
Core conserva solo selecciones Dart en `AppearanceSettings`: `AppUiStyle` (classic/minimalist/compact), `AppFontFamily`, `AppTextSize` (small/medium/large/custom) y escala personalizada 0.85–1.6.
`fromJson` acepta respaldos previos sin nuevas claves y los valores desconocidos regresan a clásico/Outfit/mediano.
La app no reinicia onboarding ni cambia rutina, RIR, peso o historial al cambiar de estilo.

## UI y coherencia
`AppUiTokens` traduce el estilo escogido a geometría, con un ThemeExtension común para Card, Input, Button y `PremiumCard`. Los nuevos tokens de tipografía, espacio y radios viven exclusivamente en Mobile, con re-exports para los componentes existentes.
Las fuentes alternativas están empaquetadas en `apps/app_mobile/assets/fonts` y NO se descargan en runtime. La escala del usuario multiplica el nivel base de accesibilidad del sistema y nunca fuerza un factor absoluto.
El preview de Aspecto muestra datos de ejemplo, sin consultar nutrición, entrenamientos ni datos privados.

## Aceptación
- [x] Core Dart tests de lectura de datos previos/invalidación de escala y round trip.
- [x] Mobile tests de 4 familias, 3 estilos, escalas, fondos/OLED y tap targets.
- [x] 7/7 CI de D/E y gate de pureza: #45490897221 (e687bfba). Nuevo gate F por separado.
- [ ] QA física iOS/Android, sobre todo tamaño grande y VoiceOver/TalkBack.
