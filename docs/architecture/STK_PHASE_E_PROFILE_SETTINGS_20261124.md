# Fase E · Perfil directo y Ajustes centralizados

## Entrega integrada
- `ProfilePage`: nombre, foto local grande con fallback emoji, acción secundaria «Editar perfil» y hechos guardados del usuario visibles sin entrar a edición.
- Hechos de entrenamiento (objetivo, experiencia, frecuencia, ambiente, duración y unidad) provienen del perfil guardado y `SettingsState`, con «Sin definir» cuando no exista respuesta. No se muestran DOB, sexo de ecuación ni otros datos demográficos sin su consentimiento expreso.
- Nivel y medallas usan `gamificationProvider` como fuente única; no recalcula PR, volumen ni sesiones ya mostrados en Progreso.
- `ProfileSettingsPage` centraliza todas las secciones preexistentes PREFERENCIAS, SERVICIOS Y PRIVACIDAD, FE, APP; no se pierde acceso a contactos Coach, exportación, copias, privacidad ni favoritos.
- Claro/oscuro rápido mediante iconos de sol/luna en Ajustes. Automático continúa en Aspecto, igual que OLED, 8 acentos y nuevas familias/estilos de D.
- No cambia ninguna clave de Hive/SharedPreferences, estructura de tablas, onboarding, perfiles, records o autorización.

## Aceptación
- [ ] Test de UI que verifica foto grande, datos reales, navegación con engranaje y cambio del tema sin borrar onboarding.
- [ ] Matriz 320/390/430dp × escala 1,1.6,2 en claro/oscuro/OLED.
- [ ] 7/7 del último CI canónico sincronizado al espejo.
- [ ] QA física de foto, gestos y VoiceOver/TalkBack.
