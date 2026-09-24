# STK Haven — Auditoría para mirror público de CI

## Objetivo

Usar un repositorio público separado y sin historial privado para ejecutar GitHub Actions con runners estándar, manteniendo fernando15xvs/STK-Haven como fuente privada de verdad.

Repositorio público activo: fernando15xvs/STK-Haven_CI

## Fuente auditada

- Rama: feat/roadmap-2-complete
- Snapshot observado antes de preparar el mirror: 341e948aa152aadda1cec7a8384b13e7f62b3863
- El script vuelve a resolver y auditar el SHA remoto en cada sincronización.

## Resultado de la revisión inicial

### Archivos de alto riesgo

El árbol del snapshot fue revisado por nombres de archivo. No se observaron archivos rastreados que coincidan con:

- .env y variantes;
- android/key.properties;
- .jks, .keystore, .p12, .pem o claves privadas;
- local.properties;
- google-services.json;
- GoogleService-Info.plist;
- backups locales de datos en formatos comunes.

La .gitignore existente también excluye los principales materiales de firma y entorno.

### Supabase

packages/core/lib/core/config/supabase_config.dart contiene:

- URL del proyecto;
- una sb_publishable_....

Ambos son configuración pública de cliente y no equivalen a una service_role ni a una clave secreta.

### Haven Faith / Gemini

La Edge Function lee GEMINI_API_KEY mediante Deno.env.get(...); el valor de la clave no está embebido en el archivo revisado.

## Guardas de publicación

scripts/sync_public_ci.ps1 aplica fail-closed antes de publicar:

1. trabaja desde origin/feat/roadmap-2-complete, no desde archivos locales sin commit;
2. rechaza nombres de archivos sensibles;
3. busca formatos de secretos de alta confianza;
4. bloquea JWT literales para revisión manual;
5. crea un ZIP del snapshot, no un clone con historial;
6. elimina los workflows privados del snapshot;
7. instala únicamente ci/public/flutter_ci.yml;
8. crea un repositorio Git nuevo con un solo commit;
9. hace push del snapshot sanitizado a STK-Haven_CI/main.

## Workflow público

El workflow público:

- no hace deploy;
- no requiere secretos del repositorio;
- usa permisos contents: read;
- fija Flutter 3.38.9;
- ejecuta analyze y tests core;
- ejecuta tests mobile;
- construye Android debug/profile/release/AAB/split ABI usando main_android.dart;
- ejecuta tests web y builds dart2js/WASM;
- construye iOS release/profile sin codesign usando main_ios.dart.

## Regla de fuente de verdad

El mirror público no es un repositorio de desarrollo primario.

No implementar cambios directamente en STK-Haven_CI. Toda corrección debe:

1. hacerse primero en STK-Haven;
2. validarse;
3. sincronizarse como nuevo snapshot público.

## Riesgo residual

Publicar un snapshot hace visible el código fuente contenido en ese snapshot. El hecho de no copiar el historial reduce el riesgo de exponer archivos borrados en commits anteriores, pero no vuelve privado el código actual.

La auditoría automatizada reduce riesgos, pero no debe considerarse una garantía absoluta de ausencia total de secretos. Antes de un cambio sustancial en configuración/credenciales, repetir revisión manual.


## Primer snapshot publicado y CI verde — 2026-09-23

- Fuente privada: `f382134decdee0690176d886538e6b462f60c5cc`.
- Commit raíz del snapshot público: `cc4029927da8f03657c04703ffc97a28e611e5ce`.
- Workflow: `STK Haven Public CI`.
- Run: `35887125248` (#1).
- Resultado global: `success`.

Jobs confirmados verdes:

- Analyze + Core tests.
- Mobile tests.
- Android artifacts: debug/profile/release APK, AAB y split ABI.
- Web tests + dart2js + WASM.
- iOS release + profile en macOS, sin codesign.

El mirror quedó operativo como infraestructura de validación. La fuente de verdad sigue siendo el repositorio privado. Cualquier corrección futura debe hacerse primero en `STK-Haven` y luego publicarse como un nuevo snapshot sanitizado.
