# Widget de versículo · STK Haven

## Alcance real

- iPhone iOS 16 o posterior: **WidgetKit** con familia `accessoryRectangular` para la pantalla de bloqueo, `accessoryInline` como alternativa compacta, y `systemSmall` para inicio.
- Android API 23 o posterior: `AppWidgetProvider` nativo en inicio; la colocación en **pantalla de bloqueo depende del sistema/fabricante**. Algunos Pixel/tabletas con versiones recientes la admiten; Android no garantiza soporte general.
- Muestra el **último versículo seleccionado por Reflexión diaria**, con referencia. Su selección sigue el estado de ánimo definido dentro de la app.
- El widget no abre SQLite/Hive ni realiza red desde el sistema bloqueado. Flutter publica texto y referencia al host nativo después de resolver `dailyVerseProvider` y cuando el usuario cambia la reflexión. Al volver a primer plano, se invalida el proveedor para comprobar el cambio de día.
- En Android, `Workmanager` puede actualizar el caché existente: el widget lo vuelve a leer en su refresco periódico sujeto al sistema. En iOS, la app pide recargar la timeline al guardar un verso; la actualización automática diaria del contenido **no está garantizada** cuando la app permanece cerrada.
- El contenido visible en el bloqueo es exclusivamente el texto bíblico y su referencia. Si se desactiva el módulo de Fe, la app ordena borrar ese snapshot al detectar el cambio. No se sincronizan notas personales.

## Activación para usuarios

- iPhone: abrir Reflexión diaria al menos una vez; mantener pulsada la pantalla de bloqueo → Personalizar → Widgets → STK Haven → seleccionar widget rectangular.
- Android: mantener pulsada la pantalla de inicio → Widgets → STK Haven / Versículo → añadir. En sistemas compatibles, activar widgets de bloqueo en Ajustes y añadirlo allí.
- Si el sistema no ofrece widgets en el bloqueo, el widget puede seguir usándose en inicio. **No** se simula con notificación permanente.

## Configuración de iOS imprescindible antes de firmar en producción

El proyecto Xcode contiene el target `StkVerseWidget`, la extensión `WidgetKit` y **App Groups** compartidos:

`group.com.FernandoSac.gymTracker`

Habilitar exactamente este App Group en Apple Developer para los App IDs de `com.FernandoSac.gymTracker` y `com.FernandoSac.gymTracker.StkVerseWidget`, regenerar los provisioning profiles y verificar ambos entitlements. Un build sin firma en CI **no prueba permisos reales del App Group**. Instalar una compilación firmada en un iPhone iOS 16+.

## QA manual pendiente

1. iPhone: widget rectangular e inline en bloqueo, pequeño en inicio, apariencia de iOS 16 y 17+, reinicio de app, cambio de ánimo/reflexión, App Group firmado.
2. Android: widget en inicio, resize, reinicio, modo ahorro de batería, actualizar tras abrir app, Pixel con lock-screen widgets, Android sin esa función.
3. Módulo Fe desactivado: no debe aparecer un versículo previo. Confirmar que no se publica perfil, historial, notas o reflexiones personales.
4. Fecha/zona horaria: cambio de día depende del refresco del proveedor (iOS al abrir app, Android sujeto a segundo plano).
5. El widget no requiere permisos de notificación. Pulsarlo abre la app mediante la interacción normal protegida del sistema.
