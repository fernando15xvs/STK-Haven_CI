# Roadmap 3.0 — Procedimiento de verificación adulta para Nutrición Inteligente

## Objetivo

Evitar que una cuenta cliente pueda autohabilitar objetivos calóricos/macros numéricos.

## Fuente de verdad

La única fuente de autorización es:

`public.stk_nutrition_adult_verifications`

El frontend solo puede consultar:

`public.stk_has_adult_nutrition_access()`

y obtiene un booleano.

## Regla de concesión

La verificación solo puede concederse desde un proceso administrativo/backend confiable.

RPC administrativo:

`stk_set_adult_nutrition_verification(user_id, verified, method)`

Permisos:

- `service_role` / backend: permitido;
- `authenticated`: denegado;
- `anon`: denegado;
- cliente Flutter/Web: no debe conocer ni portar credenciales privilegiadas.

## Flujo de grant

1. Resolver la identidad permanente del usuario.
2. Completar el mecanismo de comprobación de edad aprobado para producción.
3. Registrar el resultado desde backend administrativo.
4. Guardar un identificador de método no sensible en `verification_method`.
5. Refrescar la sesión/app y consultar `stk_has_adult_nutrition_access()`.
6. Verificar que Food Vision solo entrega resultados numéricos cuando el backend devuelve acceso.

## Revocación

Usar el mismo RPC con `verified=false`.

La revocación debe surtir efecto sin depender de claims JWT antiguos porque Food Vision consulta la tabla privada en cada petición.

## Prohibiciones

- no añadir un botón “soy mayor de 18” que conceda acceso;
- no confiar en `user_metadata`;
- no aceptar una fecha de nacimiento modificable por el propio cliente como autorización suficiente;
- no exponer `service_role`/secret key;
- no guardar documentos o imágenes de identidad dentro de STK Haven salvo que exista un diseño legal/seguro específico aprobado para ello.

## Estado

- backend fail-closed implementado;
- RLS/privilegios cubiertos por pgTAP;
- cliente Mobile/Web usa RPC booleana;
- concesión/revocación administrativa documentada;
- mecanismo externo concreto de comprobación de edad queda como decisión de operación/release y no puede sustituirse por autodeclaración cliente.
