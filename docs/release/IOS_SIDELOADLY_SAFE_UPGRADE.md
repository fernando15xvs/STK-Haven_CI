# STK Haven · instalación segura con Sideloadly (iPhone)

## IPA verificado / prerequisitos

CI público `STK-Haven_CI` genera `STK-Haven-unsigned.ipa` y su SHA-256 en el artifact `stk-haven-ios-unsigned`. La compilación iOS es sin firma y Sideloadly debe firmar **la aplicación y la extensión** con una cuenta Apple autorizada.

Bundle ID nativo original: `com.FernandoSac.gymTracker`.
Extensión del widget: `com.FernandoSac.gymTracker.StkVerseWidget`.
App Group exigido por ambas: `group.com.FernandoSac.gymTracker`.
iOS base: 15+; widget de bloqueo: iOS 16+.

El pipeline valida que el paquete ZIP IPA contiene `Payload/Runner.app`, el `PlugIns/StkVerseWidget.appex` y ambos `Info.plist`, además de comprobar sus Bundle IDs y número de build.

**IMPORTANTE:** Un build sin firma NO demuestra que Sideloadly pueda provisionar App Groups, ni que la extensión funcione en el dispositivo. Si el proveedor de firma elimina/reescribe el App Group, el widget no leerá el versículo. No marcar como validado hasta instalar y comprobar el widget en un iPhone real con firma adecuada. Los App Groups para la aplicación y la extensión deben existir en Apple Developer.

## Proteger datos existentes

La aplicación almacena en Hive datos en el contenedor local del iPhone. Para conservarlos es necesario instalar **encima** de la app anterior sin borrarla, con el **mismo Apple ID de Sideloadly** y el **mismo Bundle ID efectivo** usado en la instalación antigua. Sideloadly puede modificar/manglear el ID al firmar: verificar el ID efectivo antes de sobrescribir. Si es distinto, puede aparecer una segunda app vacía; NO desinstalar la antigua.

Antes de actualizar, abrir la app antigua y entrar a **Perfil → Datos y sincronización → Copias locales → Crear copia local**, guardar el archivo JSON en Archivos/iCloud Drive o equipo externo y verificar que existe y no está vacío. Si se usa sincronización en la nube, subir manualmente y confirmar la fecha de la copia. La restauración desde nube o JSON reemplaza datos, no es una mezcla automática.

**Alcance del backup JSON actual:** configuración de `metadata`, ejercicios, rutinas, sesiones históricas, récords personales, mediciones, versículos favoritos, gamificación, hidratación, recuperación, tareas de hábitos. **No cubre** todos los boxes: en particular NO contiene el borrador del entrenamiento activo, programas de entrenamiento, mensajes personales de recordatorio, datos de análisis derivados, ni todos los datos de SharedPreferences/SQLite y reflexiones. Los mensajes personales se almacenan solo en el dispositivo y no se exportan por diseño. Copiar manualmente su contenido antes de cualquier instalación riesgosa.

Considerar además una copia **cifrada** del iPhone mediante Finder/Apple Devices/iTunes. No desinstalar para resolver una incompatibilidad de firma antes de asegurar una recuperación real de los datos.

## Comprobación de firma y usuario

1. Mantener la app instalada. Si ya estaba instalada mediante Sideloadly, reutilizar **la misma cuenta Apple** y **el mismo identificador efectivo**, sin activar una opción que agregue sufijos diferentes. No alterar automáticamente los Bundle IDs sin comprobar.
2. Descargar el artifact ZIP del workflow público más reciente y extraer `STK-Haven-unsigned.ipa` (no subir el ZIP completo a Sideloadly). El artifact caduca según la retención configurada.
3. Conectar el iPhone, confiar en el ordenador, abrir Sideloadly y seleccionar ese IPA. Mantener la extensión `StkVerseWidget.appex` (no usar la opción para eliminar extensiones).
4. Si el usuario es de cuenta gratuita, las apps caducan a los 7 días; actualizar de nuevo encima sin borrar. El uso de capacidades avanzadas y App Groups puede requerir una cuenta/forma de firma distinta.
5. Si Sideloadly falla por `application-identifier`, `App Groups`, `provisioning` o el `Bundle ID`, **detener la instalación**; no borrar la app anterior como primer arreglo.
6. Confirmar después de actualizar que se conservan ejercicios, rutinas, historial, ajustes y recordatorios, y que el widget aparece en Personalizar pantalla de bloqueo → Añadir widgets → STK Haven (iOS 16+).
7. CI compila y verifica empaquetado sin firma; Apple Developer/Sideloadly y la preservación de datos **requieren validación manual en el iPhone real**.
