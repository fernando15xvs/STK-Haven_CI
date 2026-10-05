# Roadmap 4 — Auditoría de continuidad Mobile / Coach Pro

Fecha: 2026-10-04 (America/Lima)  
Rama fuente: `feat/roadmap-3-foundation`  
HEAD observado al crear esta auditoría: `c3c11f1a4d0022e5e3eb2aaaa394fb68c464c568`

## Objetivo

Congelar por escrito el estado actual y el orden de trabajo pendiente después de:

- validar el snapshot público con Public CI #126 en 7/7;
- instalar STK Haven físicamente en iPhone mediante sideload personal;
- desplegar el backend Supabase remoto de STK Haven;
- decidir que la experiencia principal continuará enfocada en la app móvil y que la UI Web deja de ser una prioridad de producto.

Esta auditoría no marca como completadas pruebas físicas que todavía no se hayan ejecutado.

## Estado remoto confirmado

Proyecto Supabase:

- proyecto: `STK-Haven`
- ref: `yolyhmpnmkaclevqjjeo`
- estado observado tras el despliegue: `ACTIVE_HEALTHY`
- 28 migraciones alineadas con el ledger del repositorio, desde `20260821101400` hasta `20261005025500`
- Edge Functions activas con JWT obligatorio:
  - `haven-faith-ai`
  - `food-vision-ai`
  - `web-push-test`

La app móvil usa la misma URL y publishable key del proyecto remoto.

Pendiente de validación funcional remota:

- secretos requeridos por `food-vision-ai` y `web-push-test`;
- smoke autenticado real de las funciones dependientes de esos secretos;
- flujo Coach↔Cliente completo con dos identidades reales;
- pruebas físicas continuadas en iPhone.

## Hallazgos físicos en iPhone

### Contador de pasos

La UI muestra `0 pasos` y al sincronizar aparece:

> No se concedió acceso al contador de movimiento del dispositivo.

Implementación actual:

- Flutter usa `DailyStepsBridge`;
- iOS expone `stk_haven/daily_steps` desde `AppDelegate.swift`;
- el origen es `CMPedometer`;
- `Info.plist` contiene `NSMotionUsageDescription`.

La función `requestPermission` considera permiso concedido solo cuando la consulta del podómetro devuelve datos. Por ello el mismo mensaje puede representar:

1. Motion & Fitness denegado;
2. Fitness Tracking desactivado globalmente;
3. CoreMotion no disponible/consulta sin datos;
4. otro error de CoreMotion que actualmente queda colapsado en un simple `false`.

Acción recomendada antes de modificar código:

- revisar en iPhone `Ajustes > Privacidad y seguridad > Movimiento y condición física`;
- confirmar `Seguimiento de condición física` activo;
- confirmar STK Haven permitido;
- volver a pulsar sincronizar.

Mejora técnica pendiente:

- devolver estados diferenciados desde Swift: `authorized`, `denied`, `restricted`, `unavailable`, `query_failed`;
- mostrar mensajes distintos en Flutter en lugar de tratar todos los casos como permiso denegado;
- agregar smoke físico iOS para pasos.

### Sonido al terminar descanso / serie

El ajuste `timerSoundEnabled` existe y por defecto está activo.

Sin embargo, al terminar el descanso el provider solo:

1. actualiza el contador;
2. limpia el estado de descanso;
3. programa una notificación local mediante `WorkoutNotificationService`.

No existe actualmente una reproducción de sonido/haptic directa en primer plano cuando el timer llega a cero.

Consecuencia:

- en foreground el usuario depende del comportamiento de la notificación local de iOS;
- si notificaciones/sonido están denegados, el teléfono está en silencio, Focus interfiere o iOS no presenta el sonido como se espera, el final del descanso puede quedar silencioso.

Mejora técnica recomendada:

- conservar la notificación local para background;
- añadir feedback de primer plano explícito al llegar a cero;
- respetar `timerSoundEnabled` y `vibrationEnabled`;
- no duplicar sonido si la notificación ya se presenta;
- agregar tests y smoke físico iPhone para foreground/background/silent mode.

## Historial inmutable de revisiones — estado actual

Backend ya implementado y validado:

- baseline inmutable para asignaciones existentes/nuevas;
- snapshots normalizados de programa/rutinas/ejercicios;
- historial paginado de solo lectura;
- creación de revisiones Coach Pro encadenadas mediante `previous_revision_id`;
- token optimista de concurrencia para impedir forks/stale writes;
- una propuesta nueva no cambia `assignment.version`, aceptación ni programa local;
- aislamiento por coach, relación, permiso y entitlement;
- CI/pgTAP verde antes del despliegue remoto.

## Orden pendiente para cerrar revisiones de programas

1. **Lectura Flutter del historial**
   - modelos;
   - service;
   - provider;
   - listar revisiones;
   - abrir revisión concreta;
   - paginar rutinas y ejercicios.

2. **UI móvil del historial**
   - versión/revisión actual;
   - revisiones anteriores;
   - autor;
   - fecha;
   - estados loading/empty/error/retry;
   - comparación básica sin inventar datos históricos.

3. **Aceptación explícita por el cliente**
   - aceptar una revisión concreta;
   - nunca sustituir automáticamente el programa actual solo porque el coach publicó una revisión.

4. **Instalación segura de la revisión aceptada**
   - corregir el contrato local actual `coach_program_imports_v1`, que identifica únicamente por `assignmentId`;
   - introducir identidad de revisión aceptada/instalada;
   - garantizar idempotencia.

5. **Protección contra sobrescritura silenciosa**
   - detectar personalización local;
   - mostrar diff claro;
   - exigir confirmación;
   - conservar una vía segura de cancelación.

6. **Recuperación ante fallos**
   - separar aceptación backend de instalación local;
   - permitir reintento si instalación falla;
   - no duplicar;
   - no corromper el programa personal;
   - conservar estado suficiente para recuperar después de reinicio.

7. **Pruebas E2E**
   - propuesta → aceptación → instalación;
   - revisión obsoleta;
   - doble aceptación;
   - reinstalación;
   - fallo local tras aceptación;
   - revocación de permiso;
   - relación pausada/revocada;
   - downgrade/expiración Coach Pro;
   - multi-coach isolation.

8. **Resto de huecos Coach Pro Fase 2**
   - adherencia real;
   - tendencias y comparativas;
   - PRs;
   - exportación profesional autorizada y acotada;
   - mejoras de nutrición;
   - comunicación/inbox;
   - smokes físicos y de escala.

9. **Smart Coach**
   - continúa después de cerrar los contratos anteriores;
   - no mezclar Smart Coach con el cierre del historial/aceptación/instalación.

## Decisión de producto: Mobile-first, Web de-priorizada

A partir de esta auditoría:

- iPhone/Android son las superficies prioritarias;
- no se requiere paridad de nueva UI con Web;
- no desarrollar nuevas pantallas Web de Coach Pro salvo solicitud explícita futura;
- no borrar la app Web ni romper sus builds existentes;
- mantener Web en CI por ahora como control de regresión del workspace, pero sin obligación de feature parity;
- cualquier trabajo futuro debe preferir `apps/app_mobile` y `packages/core` cuando el contrato pueda compartirse.

La razón práctica es que la app ya puede ejecutarse físicamente en iPhone mediante sideload personal, por lo que la Web deja de ser necesaria como sustituto temporal de iOS.

## Próximo bloque recomendado

Antes de retomar historial de revisiones:

1. resolver/diagnosticar correctamente el permiso CoreMotion de pasos en iPhone;
2. implementar feedback audible/haptic fiable al finalizar descanso;
3. ejecutar smoke físico de ambos cambios.

Después, retomar el punto 1 del historial de revisiones en Flutter móvil.

## No hacer sin nueva autorización

- no mergear la rama privada a `main`;
- no eliminar la app Web;
- no borrar datos remotos;
- no introducir cambios silenciosos sobre programas personales del cliente;
- no avanzar Smart Coach antes de cerrar aceptación/instalación y sus pruebas E2E.
