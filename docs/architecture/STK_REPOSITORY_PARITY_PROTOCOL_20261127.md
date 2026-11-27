# STK Haven — Contrato de paridad de código

STK-Haven/main es la fuente de verdad. STK-Haven_CI/main ejecuta CI y genera artefactos; no es una rama independiente de desarrollo. Core es Dart puro; Mobile posee la UI y los puertos nativos. Web permanece pausada.

Para cada entrega, verificar los SHA remotos, integrar la fuente privada, comparar los árboles de producto por modo/tipo/SHA, actualizar el manifiesto de paridad desde la fuente privada y publicar el espejo una sola vez. No iniciar otra entrega mientras existan diferencias de código o un CI fallido.

Los workflows, scripts y metadatos exclusivos de CI viven en el espejo. Documentación privada, borradores legales y auditorías de seguridad no se publican automáticamente; pueden existir diferencias documentales deliberadas. Nunca compartir credenciales, registros personales ni historial Git privado.

El CI público valida su árbol contra el manifiesto aprobado. No tiene acceso al repositorio privado y no sustituye la comprobación directa de ambos árboles antes y después de sincronizar. Web no se analiza ni compila.
