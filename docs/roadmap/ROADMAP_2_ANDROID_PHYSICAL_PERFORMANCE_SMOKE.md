# Roadmap 2.0 — Android physical performance smoke

Fecha: 2026-09-12

Rama: `feat/roadmap-2-complete`

## Contexto

Después del hardening móvil y de la separación de entrypoints/bootstrap Android-iOS, se generó e instaló un APK release Android en un dispositivo físico.

Cambios relevantes incluidos en esta etapa:
- pestañas principales con construcción lazy;
- eliminación de blur/compositing costoso en superficies móviles frecuentes;
- scroll nativo por plataforma;
- trabajo no crítico diferido fuera del primer frame;
- apertura concurrente de cajas Hive independientes;
- menor acoplamiento de Riverpod en la raíz;
- `main_android.dart` y servicios Android aislados de iOS;
- build Android explícito con `--target lib/main_android.dart`.

## Resultado manual informado

El usuario reporta que, después de instalar la nueva versión en el teléfono físico, la aplicación **se siente fluida y ya no se siente pesada**.

Este resultado valida como smoke manual la mejora perceptible de fluidez sobre el dispositivo probado.

## Alcance de esta evidencia

Se considera:
- [x] Fluidez percibida en uso físico post-hardening: OK.
- [x] La versión Android separada arranca y es utilizable en dispositivo físico.

Todavía no se considera validado formalmente:
- [ ] frame timing / jank con DevTools o profile build;
- [ ] memoria pico y sostenida;
- [ ] cold-start medido;
- [ ] comportamiento en gama baja/media adicional;
- [ ] regresión completa de todas las funciones J–T sobre el nuevo runtime;
- [ ] matriz automática completa post-split.

Por tanto, esta evidencia complementa pero no reemplaza `scripts/validate_roadmap2_local.ps1` ni el profiling físico pendiente.
