# Perfil · STK Haven — checklist de pruebas en dispositivos

Este documento **no certifica pruebas físicas**. Las casillas se completarán con capturas de un iPhone y un Android reales. PR #57 permanece abierta y en borrador.

## Integridad y comportamiento

- [ ] Desde Perfil no es posible cambiar programas antiguos ni borrar rutinas automáticamente; Entrenar contiene el gestor de programas vigente.
- [ ] STK MOTIVATION ya no aparece en Perfil; botón + > Motivation abre archivos existentes y playlists.
- [ ] Editar avatar/nombre y regresar sin guardar presenta diálogo de descarte; cancelar conserva el borrador.
- [ ] Cambiar objetivo, experiencia, Fe y frecuencia recomendada; guardar o descartar, sin alterar la agenda de Entrenar.
- [ ] Cambiar kg→lb→kg en Entrenamiento y unidades; visitar Tu experiencia y guardar; la unidad se mantiene.
- [ ] Restaurar copia nube con workout activo: acción deshabilitada y servicio rechaza; con sesión finalizada permite confirmar.
- [ ] Restaurar copia local con workout activo bloquea; con sesión finalizada muestra contenido y confirmación.
- [ ] Notificaciones con permiso concedido/denegado y web: UI diferencia lo configurado de lo efectivo.
- [ ] Descanso unilateral importado de 35/200s abre selector sin crash ni cambio silencioso.
- [ ] Coach: vínculo y revocación requieren permisos explícitos y no comparten avatar privado.
- [ ] Módulo Fe apagado: no aparecen preferencias de Fortaleza ni favoritos; encendido: accesos correctos.
- [ ] Nivel y logros conserva XP y medallas; no duplica métricas detalladas de Progreso.

- [ ] Versión web: Perfil no ofrece reemplazar ni eliminar rutinas a través de programas legacy; el acceso moderno desde navegación web sigue funcionando.

## Responsive y diseño global

- [ ] 320dp × texto 100%, 160% y 200%: Perfil, Aspecto, Tu experiencia, Entrenamiento, Notificaciones, Copias, App y dispositivo, Logros, Editar perfil, Coach.
- [ ] 390dp × texto 100%, 160% y 200%: mismos flujos sin `RenderFlex overflow`.
- [ ] 430dp × texto 100%, 160% y 200%: mismos flujos sin cortes de campos, CTA o tarjetas.
- [ ] Claro, oscuro y OLED: tarjetas radio 20, semántica de borde, elevación opcional, textos contrastados, sin colores fijos discordantes.
- [ ] Ocho acentos: zafiro, amatista, esmeralda, océano, rosa, ámbar, coral y pizarra.
- [ ] Teclado al cambiar nombre, diálogos y botones guardado/descarte, desplazamiento seguro y sin pérdida de cambios.
- [ ] Reducir movimiento activo en dispositivo: no hay transiciones innecesarias.
- [ ] VoiceOver: nombres de acciones, título de página, chips y switches; foco y orden intuitivos.
- [ ] TalkBack: lectura de botones, horarios, elementos de logros, opciones de backup/privacidad; sin requerir color ni gestos ocultos.
- [ ] Comprobar orientación horizontal cuando esté soportada.

## QA y despliegue

- [ ] `flutter analyze`, Core tests, mobile tests, Supabase, Edge Functions, iOS y Android 7/7 desde espejo.
- [ ] Los SHA de blobs de Profile en `STK-Haven` (PR #57) y `STK-Haven_CI/main` coinciden.
- [ ] iPhone físico: modelo, iOS, fecha, capturas y fallos documentados.
- [ ] Android físico: modelo, Android, fecha, capturas y fallos documentados.
- [ ] PR #57 se mantiene en borrador hasta aprobación expresa.

## Preparación de una prueba reproducible

1. Abrir la última ejecución aprobada de [Actions del espejo](https://github.com/fernando15xvs/STK-Haven_CI/actions) (flujo `STK Haven Public CI`). Descargar desde **Artifacts** la compilación para el commit exacto de la PR. No usar un APK/IPA de otra versión; los artefactos caducan a los 7 días.
2. Para Android, descargar `stk-haven-android-debug-qa`, descomprimir `app-debug.apk`, verificar `app-debug.apk.sha256`, instalar en un **dispositivo de prueba**; se deben otorgar permisos únicamente si el caso lo requiere.
3. Para iPhone, `stk-haven-ios-unsigned` trae un IPA **sin firmar**. Su presencia certifica empaquetado, **no instalación ni una sesión real**. Hacen falta firma/provisionamiento válidos y un iPhone físico para la prueba.
4. Antes de cualquier prueba de restauración, **exportar una copia local y conservarla fuera del dispositivo**; usar datos ficticios o un entorno de prueba. La restauración reemplaza datos locales. No realizarla con datos valiosos sin copia validada.
5. Registrar por caso: modelo, sistema operativo y versión, commit SHA de código, build/versión, tema y acento, escala de texto, resultado, captura, pasos reproducibles. Si falla una prueba, mantener la casilla sin marcar.

## Evidencia automática (distinta del QA físico)

- [x] CI espejo 7/7 para el código de Perfil: [ejecución 43502798220](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/43502798220).
- [x] Perfil móvil (tests widget/responsive/contratos) y Perfil web (test de contrato): ambos pasos ejecutados y aprobados en la [ejecución ampliada 43519421812](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/43519421812).
- [x] Paridad de 41/41 archivos relacionados con Perfil comprobada entre HEAD canónico `22ba891fc9e9b5684ee26c701e9eef3eacdea5e7` y su espejo previo.
- [ ] Build web release completo en Actions con nueva puerta de regresión.
- [ ] Revisión humana de VoiceOver, TalkBack y navegador real (no se puede deducir del CI).
