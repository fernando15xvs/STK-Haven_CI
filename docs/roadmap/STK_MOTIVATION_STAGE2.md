# STK Motivation — Etapa 2: Entrenar (iOS/Android)

- Un acceso compacto **STK Motivation** aparece en **Mis rutinas** y **Entrenamiento activo** cuando no hay audio. Al tocarlo abre la biblioteca de Etapa 1.
- Con un archivo seleccionado, el acceso muestra título, modo, anterior, reproducir/pausar, siguiente y progreso. Se usa un único motor `MotivationPlayback.instance` entre pantallas: navegar no reinicia la pista ni crea otro reproductor.
- Dentro del entrenamiento activo se coloca **después del indicador de descanso y antes de la lista de ejercicios**, nunca sobrepuesto al contador ni al botón «Finalizar». En Mis rutinas se ubica al pie de la lista, encima de navegación.
- El audio del MP4 sigue disponible; el video se ve desde la biblioteca al abrirla, sin segundo decodificador en Entrenar.
- No se inicia ni detiene el audio al iniciar, finalizar, descartar o cambiar ejercicios. Las series, descansos, cronómetros y recordatorios conservan sus providers originales, sin vincular audio a esos eventos.
- Compatible con modo claro, oscuro y los 8 acentos desde `AppColors.of(context)`. Sin cambios a la web.

QA: analizar Flutter; probar oculto y acceso compacto; reproducir una pista, navegar de biblioteca a rutinas a sesión, usar temporizador/descanso/modo enfoque, regresar a biblioteca, cambiar tema, bloquear pantalla, finalizar sesión, y confirmar que no se reinicia el audio ni se ocultan controles esenciales. Probar físicamente iOS y Android.
