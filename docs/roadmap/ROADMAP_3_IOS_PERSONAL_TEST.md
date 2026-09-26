# Roadmap 3.0 — Prueba iPhone sin Mac propia

## Qué genera GitHub

El workflow de CI compila iOS en un runner macOS y publica:

- `STK-Haven-unsigned.ipa`
- `STK-Haven-unsigned.ipa.sha256`

Artefacto de Actions:

`stk-haven-ios-unsigned`

Retención configurada: 7 días.

## Importante

El IPA generado por GitHub está **sin firmar**.

No puede instalarse directamente en un iPhone hasta que se firme con:

- un certificado/provisioning profile válidos de Apple; o
- una herramienta de sideload/firma temporal compatible con una cuenta Apple gratuita.

GitHub puede compilar la app sin que el usuario tenga una Mac física, pero no puede inventar por sí solo una identidad de firma Personal Team.

## Flujo para prueba temporal

1. Esperar un candidato CI verde.
2. Abrir el run de GitHub Actions.
3. Descargar el artefacto `stk-haven-ios-unsigned`.
4. Verificar opcionalmente el SHA-256.
5. Firmar el IPA desde Windows con una herramienta de firma/sideload compatible con una cuenta Apple gratuita.
6. Instalarlo en el iPhone.
7. Con una cuenta gratuita, la firma temporal debe renovarse cuando expire el provisioning de desarrollo.

## Qué se prueba con este IPA

- onboarding;
- navegación;
- workouts;
- timers/background;
- notificaciones;
- Fe/Hábitos;
- Coach/Cliente;
- SafeArea;
- teclado;
- Dynamic Type;
- gesto/UX nativo iOS.

## Qué NO hace este flujo

- no publica en App Store;
- no crea TestFlight;
- no elimina las restricciones de una cuenta Apple gratuita;
- no sustituye una firma de distribución;
- no requiere merge a `main`.

## Camino futuro

Cuando exista Apple Developer Program:

1. configurar certificados/profiles de distribución;
2. automatizar firma en GitHub Actions;
3. generar IPA firmado;
4. opcionalmente subir a TestFlight;
5. validar L10 con build distribuible.
