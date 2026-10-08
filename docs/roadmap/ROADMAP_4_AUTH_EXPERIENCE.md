# STK Haven — experiencia de acceso y registro (Android, iOS, Web)

## Interfaz

- Sustituye el diálogo de la página **Datos y sincronización** por una pantalla con dos modos explícitos: **Iniciar sesión** y **Registrarme**.
- Usa una distribución responsiva: historia de marca + tarjeta de formulario en pantallas anchas y columna desplazable en teléfonos, con colores del tema para modo claro/oscuro.
- Campos etiquetados, teclado de correo, autocompletado nativo, confirmación de contraseña, botón mostrar/ocultar, mensajes de error o éxito accesibles y estado de carga durante la operación.
- Permite **Continuar sin cuenta**. Iniciar sesión/registrarse nunca provoca una carga automática de la copia local a la nube.

## Validación

- Normalización de correo: quitar espacios exteriores y convertir a minúsculas; longitud, formato de dominio, espacios, dobles puntos y longitud máxima de etiqueta local.
- Inicio de sesión: contraseña no vacía **sin imponer las restricciones nuevas** a cuentas ya existentes.
- Registro nuevo: 10–72 caracteres, al menos una letra minúscula, una mayúscula y un número, sin espacios, y confirmación idéntica. Un símbolo refuerza el indicador visual.
- No se recortan ni registran las contraseñas; errores de Supabase traducidos a mensajes comprensibles. Mensajes de confirmación no garantizan que un correo que ya exista haya creado una cuenta.
- Se respeta la confirmación de correo configurada en Supabase: cuando no hay sesión activa, se muestra la instrucción de consultar el correo antes de entrar.
- El enlace **¿Olvidaste tu contraseña?** solicita el mensaje de recuperación mediante la API de Supabase sin revelar si el correo existe. La experiencia final del enlace depende de que el equipo configure el `SITE_URL`/redirect y la página de cambio de contraseña en Supabase; debe probarse con un correo real antes del lanzamiento.

## QA

- Unit tests: variantes de correo válido/inválido, caracteres de contraseña, confirmación, compatibilidad con contraseñas antiguas.
- CI: Analyze + Core, Mobile tests, Android APK/AAB, iOS sin firma, DB/RLS y Edge Functions sobre el espejo público `STK-Haven_CI`.
- Pendiente smoke manual con cuentas nuevas y existentes, confirmación por correo, recuperación real, autofill/password managers, teclado y lector de pantalla en dispositivos Android/iOS y navegador.

## Límites

No se han cambiado políticas remotas de Supabase, configuración SMTP o URLs de redirección. No se ha solicitado ni activado un despliegue de la aplicación a tiendas.
