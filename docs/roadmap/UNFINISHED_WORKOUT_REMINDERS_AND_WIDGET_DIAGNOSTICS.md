# Entrenamientos pendientes y diagnóstico de widgets

## Recordatorios
- Se conserva el borrador Hive, incluida su identidad, sets, pesos y repeticiones. Se almacena `lastActivityAt` en el borrador; para versiones antiguas se usa `startedAt`.
- El usuario activa **Avisar si olvido finalizar** desde Perfil → Notificaciones → Entrenamiento; por defecto está desactivado y la autorización del sistema se solicita únicamente al activarlo.
- Dos avisos locales como máximo, a las **3 horas** y a las **24 horas** desde la última edición. Las nuevas ediciones reprograman los avisos; finalizar por completo o descartar cancela ambos.
- Una sesión antigua muestra **Entrenamiento pendiente** en inicio. Al finalizar tras mucho tiempo sin ediciones se pide ingresar la duración real en minutos, para no guardar varios días como duración. No se modifica el historial automáticamente.
- Una sesión incompleta es reanudable y sigue siendo un borrador. Notificaciones sujetas a permisos, restricciones de batería y SO. En web el interruptor está desactivado.

## Widget de bloqueo iOS
- La tarjeta **Versículo en pantalla de bloqueo** en Reflexión diaria consulta el paquete de app firmado para saber si `PlugIns/StkVerseWidget.appex` sigue presente y si el App Group nativo `group.com.FernandoSac.gymTracker` está disponible.
- Si falta la extensión, revisar en Sideloadly **Remove App Extensions**. Si no existe contenedor compartido, revisar perfiles y entitlements de Apple Developer para ambos App IDs.
- Una extensión presente con App Group accesible no prueba que el widget aparezca en el selector iOS; se requiere comprobar el dispositivo y sus logs.
- No desinstalar STK Haven como solución inmediata: la información de rutinas y progreso se guarda en el contenedor de la app.
