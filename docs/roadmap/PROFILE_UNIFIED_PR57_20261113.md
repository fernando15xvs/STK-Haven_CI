# STK Haven · Perfil — implementación en PR #57

**Fecha:** 13 noviembre 2026 · **Rama existente:** `fix/home-phase1-data-navigation-20261113`.
**Estado:** cambios de código A/B publicados, CI de la versión B en curso; C necesita QA real.
**PR:** https://github.com/fernando15xvs/STK-Haven/pull/57
**Espejo Actions:** `fernando15xvs/STK-Haven_CI` (`main`), sin PR espejo.
**Auditoría de origen:** https://github.com/fernando15xvs/STK-Haven/pull/57#issuecomment-6863316769

## Reglas de propiedad de funciones

- **Inicio:** próxima sesión y tareas del día; no crear otra tarjeta hero en Perfil.
- **Entrenar:** programas, rutinas, plantillas, calendario y sesiones manuales; **no gestionar programas legacy en Perfil**.
- **Progreso:** sesiones, tiempo entrenando, PR, 1RM, pesos/reps/RIR por fecha, historiales y estadísticas; **no duplicar panel de Progreso en Perfil**.
- **Botón +:** Motivation; **no duplicar sección STK MOTIVATION en Perfil**.
- **Perfil:** identidad, preferencias, permisos, backups y administración del dispositivo. Los logros son reconocimientos, no gráficos de Progreso.
- **Una identidad visual:** fuente Outfit y pesos desde `AppearanceTheme`; paleta `AppColors` contextual (8 acentos), radio 20, borde y elevación coordinados, tamaños/espaciado coherentes con `PremiumCard`. No usar colores de marca inventados ni fuentes por pantalla.

## Web — coherencia de la fuente de verdad

- [x] En `apps/app_web/lib/features/profile/presentation/profile_page_web.dart` se retiró la tarjeta de «Programa de entrenamiento» y los diálogos heredados que invocaban `ProgramService.replaceProgram/removeActiveProgram` y podían borrar rutinas. La web conserva su acceso moderno `TrainingProgramsPage` desde `web_layout.dart`; no se altera el onboarding ni la persistencia.
- [x] Test contractual en `apps/app_web/test/features/profile/profile_legacy_program_removal_test.dart`.
- [ ] Validar manualmente los cambios web en navegador, incluido selector moderno; no confundir compilación mobile con QA web.

## Bloque A — integridad funcional

- [x] A1. Retirar de Perfil la tarjeta y cambios de programa heredado; conservar `TrainingProgram` en Entrenar y datos de `SettingsState.activeProgram` solo para migración compatible.
- [x] A2. Evitar restaurar la nube durante una sesión activa: guard en UI y servicio (antes y después de descarga), y no afirmar éxito tras fallo.
- [x] A3. Unidades kg/lb solo en «Entrenamiento y unidades». El editor «Tu experiencia» no revierte silenciosamente ese dato al guardar.
- [x] A4. Eliminar el switch de «Quiero recordatorios» de Tu experiencia; permisos y frecuencia efectivos solo en Notificaciones.
- [x] A5. Aclarar «Días preferidos» como recomendación, sin mutar calendario del programa activo de Entrenar.
- [x] A6. Compatibilidad de intervalos unilaterales personalizados restaurados (0–600 s), sin valor inválido en Dropdown.
- [x] A7. Pruebas de regresión para selector e integridad de navegación/servicio.
- [ ] **A-GATE:** CI 7/7 del bloque funcional (última ejecución puede quedar cancelada por un commit posterior; usar el último HEAD final).

## Bloque B — diseño, navegación y formularios

- [x] B1. Reorganizar Perfil como identidad + «Preferencias», «Servicios y privacidad», «Reconocimientos» y «App»; eliminar encabezados vacíos.
- [x] B2. Quitar sección STK MOTIVATION de Perfil; el acceso en + se conserva sin borrar ningún audio, playlist o dato.
- [x] B3. Reducir resumen de identidad; no calcular métricas que pertenecen a Progreso.
- [x] B4. Reusar superficies `ProfileSectionCard` de Core con radio20 y tokens; ajustar personalización, entrenamiento, avisos, sincronización y App/dispositivo.
- [x] B5. «Editar perfil» es identidad (nombre/avatar/reflexión); objetivo y experiencia se configuran una vez en «Tu experiencia».
- [x] B6. Proteger salir de ambos editores con cambios pendientes; ofrecer «Seguir editando» o «Descartar».
- [x] B7. Cambiar medallas de cuadrícula fija a lista adaptable, usando colores semánticos y texto escalable.
- [x] B8. Retirar control visual inerte «Continuar» de la vista previa de Aspecto; ajustar textos de versículos y eliminar versión hardcodeada.
- [ ] **B-GATE:** mobile widget tests, core tests, análisis, CI 7/7 para el HEAD del bloque B.

## Bloque C — regresión y QA

- [x] C1. Tests nuevos de selector unilateral custom, estados de navegación, contratos de los formularios, superficies y logros a 320/390/430dp y texto 100/160/200 %.
- [ ] C2. Contraste de los 8 acentos y claro/oscuro/OLED en todos los subflujos de Perfil, teclado y escalas; incluir rotación admitida.
- [ ] C3. Verificación manual VoiceOver y TalkBack de identidad, logros, menús, chips, cambios de preferencias, cierres de editor.
- [ ] C4. Restaurar datos locales/nube con y sin sesión; validar historial, notas, avatar, programas y permisos sin perder datos.
- [ ] C5. Verificar uso sin cuenta, con cuenta y con módulo Fe desactivado, Coach permisos y datos privados.
- [ ] C6. Revisión de tarjetas y títulos en Perfil contra Inicio/Entrenar/Progreso bajo temas, OLED y reducir movimiento.
- [ ] C7. QA físico iPhone/Android, reportar versiones y capturas. **CI verde no equivale a esta prueba.**
- [ ] C8. Paridad de Git blobs entre PR canónica y espejo + **7/7 final**.
- [ ] C9. Mantener PR #57 **abierta, draft, sin fusionar** hasta que el usuario ordene integrarla.

## Criterios de aceptación

- [ ] Perfil nunca muestra ni acciona un programa antiguo cuando el moderno difiere.
- [ ] Botón + mantiene Motivation; Perfil no repite ese enlace.
- [ ] Cambio kg/lb no se revierte al guardar «Tu experiencia».
- [ ] No se puede restaurar ninguna copia sobre una sesión en curso.
- [ ] Tarjetas, tipografía y colores siguen Outfit/AppColors/PremiumCard en todas las pantallas de Perfil.
- [ ] No hay overflow a 320dp/200% y los botones son accesibles.
- [ ] CI final 7/7 en espejo y QA físico documentado, sin merge.

**Límites:** no crear otra PR, no instalar una versión nueva ni generar IPA sin solicitud, no modificar Supabase ni eliminar rutinas, sesiones, cuentas, audio o medallas al simplificar navegación.
