# STK Motivation — Etapa 1 (solo iOS y Android)

Biblioteca **local y privada**, sin subida a Supabase ni web. Importa MP3/M4A/AAC/WAV/MP4 (máx. 512 MB por archivo) desde Files, copia archivos al Application Support de STK Haven y mantiene metadatos en SharedPreferences; no borra originales. Tres modos: Disciplina, Gym Sad, Hype. Playlists personales con membresía editable. Reproducir, pausa, anterior/siguiente, repetir uno, siguiente hasta fin, repetir lista, detener al finalizar y aleatorio. Audio de MP4 en segundo plano mediante just_audio/just_audio_background con controles de sistema. MP4 visual en pantalla mediante video_player silenciado sincronizado aproximadamente al audio, detenido al ir a segundo plano. Códecs deben ser compatibles con el decodificador iOS/Android, con error visible si no se soportan. No se ofrece contenido con copyright; el usuario importa solo archivos que puede usar legítimamente.

Entrada desde Perfil y acceso rápido + (sin modificar navegación principal ni web). Integración automática al temporizador de entrenamiento, sincronización cloud, descarga y biblioteca pública quedan FUERA de esta etapa.

QA: probar iPhone/Android físico, auriculares, llamada entrante, pantalla bloqueada, audio MP4, borrado, importación interrumpida, 8 acentos claro/oscuro, reinicio y memoria. No dar por listo hasta CI verde y pruebas físicas.
