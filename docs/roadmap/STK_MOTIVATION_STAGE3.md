# STK Motivation — Etapa 3: biblioteca avanzada (iOS/Android)

## Entregado en la rama de desarrollo

- **Favoritos** por archivo, persistidos junto al metadato local. La lectura de archivos creados en la etapa 1 mantiene `favorite=false` por defecto; la pestaña **Favoritos** filtra sin duplicar ni mover archivos físicos.
- **Reordenamiento manual** de canciones en cada playlist, mediante arrastrar el asa; persiste el orden de IDs. Se aplica en la siguiente apertura/reproducción de esa lista (una cola ya iniciada no se reemplaza a mitad del entrenamiento).
- **Temporizador de apagado** de STK Motivation con opciones 5/10/15/30/45/60 minutos, cancelable y de una sola ejecución. Al llegar la hora se detiene **solo** el motor `MotivationPlayback`; nunca toca timers de serie/descanso o el entrenamiento. Reutiliza la misma instancia del reproductor de las etapas 1 y 2.
- **Volumen (0-100%) y velocidad (0,75×-1,5×)** aplicados a `just_audio` y guardados en preferencias de dispositivo. Restauración a audio normal.
- Se conserva la posibilidad de MP3 y audio de MP4 con teléfono bloqueado y los ocho colores de acento/modo oscuro/claro.

## Límites y pruebas

- El apagado utiliza un temporizador del proceso mientras el audio está en reproducción; Android/iOS pueden suspender el proceso y retrasar la operación. Al volver la app al primer plano se verifica el vencimiento. **No promete precisión de segundo plano sin ensayos en teléfonos físicos.**
- No hay subida a Supabase, sincronización cloud ni biblioteca pública; una futura sincronización privada será opt-in y requerirá diseño explícito de cifrado, cuotas, permisos y derechos de autor. No se deben copiar archivos personales al servidor sin consentimiento.
- Los ajustes de audio no modifican el volumen del sistema operativo ni el de otras apps; no se activa automáticamente audio motivacional por serie.
- QA: validar persistencia de favoritos y velocidad al reiniciar; reordenar arriba/abajo, eliminar ítems; probar cambio MP3→MP4, modo oscuro, ocho acentos; temporizador con pantalla apagada, auriculares, llamada entrante, app en segundo plano, y fin de entrenamiento en iOS/Android.
