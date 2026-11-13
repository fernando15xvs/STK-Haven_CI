# STK Haven · Perfil — implementación en PR #57

**Fecha:** 13 noviembre 2026 · **Rama existente:** `fix/home-phase1-data-navigation-20261113`.
**Estado:** bloques A/B implementados y CI espejo 7/7 confirmado (`43502798220`). Pruebas específicas Perfil móvil y web ejecutadas con éxito en `43519421812`; pendiente validar compilación web release y QA en dispositivos reales.
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
- [x] **A-GATE:** CI espejo 7/7 confirmado en la captura `43502798220` que contiene el bloque A.

## Bloque B — diseño, navegación y formularios

- [x] B1. Reorganizar Perfil como identidad + «Preferencias», «Servicios y privacidad», «Reconocimientos» y «App»; eliminar encabezados vacíos.
- [x] B2. Quitar sección STK MOTIVATION de Perfil; el acceso en + se conserva sin borrar ningún audio, playlist o dato.
- [x] B3. Reducir resumen de identidad; no calcular métricas que pertenecen a Progreso.
- [x] B4. Reusar superficies `ProfileSectionCard` de Core con radio20 y tokens; ajustar personalización, entrenamiento, avisos, sincronización y App/dispositivo.
- [x] B5. «Editar perfil» es identidad (nombre/avatar/reflexión); objetivo y experiencia se configuran una vez en «Tu experiencia».
- [x] B6. Proteger salir de ambos editores con cambios pendientes; ofrecer «Seguir editando» o «Descartar».
- [x] B7. Cambiar medallas de cuadrícula fija a lista adaptable, usando colores semánticos y texto escalable.
- [x] B8. Retirar control visual inerte «Continuar» de la vista previa de Aspecto; ajustar textos de versículos y eliminar versión hardcodeada.
- [x] **B-GATE:** mobile widget tests, core tests, análisis y CI 7/7 en `43502798220`; suite explícita Perfil móvil/web superada en la ejecución ampliada `43519421812`.

## Bloque C — regresión y QA

- [x] C1. Tests nuevos de selector unilateral custom, estados de navegación, contratos de los formularios, superficies y logros a 320/390/430dp y texto 100/160/200 %. **Se ejecutan explícitamente** los tests de `apps/app_mobile/test/features/profile` y `apps/app_web/test/features/profile` en CI espejo desde `43519421812`, ambos verdes.
- [ ] C2. Contraste de los 8 acentos y claro/oscuro/OLED en todos los subflujos de Perfil, teclado y escalas; incluir rotación admitida.
- [ ] C3. Verificación manual VoiceOver y TalkBack de identidad, logros, menús, chips, cambios de preferencias, cierres de editor.
- [ ] C4. Restaurar datos locales/nube con y sin sesión; validar historial, notas, avatar, programas y permisos sin perder datos.
- [ ] C5. Verificar uso sin cuenta, con cuenta y con módulo Fe desactivado, Coach permisos y datos privados.
- [ ] C6. Revisión de tarjetas y títulos en Perfil contra Inicio/Entrenar/Progreso bajo temas, OLED y reducir movimiento.
- [ ] C7. QA físico iPhone/Android, reportar versiones y capturas. **CI verde no equivale a esta prueba.**
- [x] C8a. Paridad de **41/41 blobs** relacionados con Perfil/restore en PR principal y espejo, verificada para HEAD `22ba891fc9e9b5684ee26c701e9eef3eacdea5e7`.
- [ ] C8b. **7/7 final** después de añadir compilación web release explícita al espejo.
- [x] C9. PR #57 verificada **abierta, draft, sin fusionar**. Mantener así hasta la autorización explícita.

## Criterios de aceptación

- [x] Perfil no ofrece acciones de gestión de programas legacy ni en móvil ni en web (tests de contrato + CI); queda pendiente la interacción física/navegador.
- [x] Botón + mantiene Motivation; Perfil no repite ese enlace (suite Perfil en CI).
- [x] El editor «Tu experiencia» no vuelve a guardar kg/lb (test de contrato aprobado); falta verificar el recorrido manual entre pantallas.
- [x] Guardas en la ruta cloud (UI y servicio, incluso tras la descarga) y en restauración local; **pendiente prueba real de importación/restauración**.
- [ ] Tarjetas, tipografía y colores siguen Outfit/AppColors/PremiumCard en todas las pantallas de Perfil.
- [ ] No hay overflow a 320dp/200% y los botones son accesibles.
- [ ] CI final 7/7 en espejo y QA físico documentado, sin merge.

**Límites:** no crear otra PR, no instalar una versión nueva ni generar IPA sin solicitud, no modificar Supabase ni eliminar rutinas, sesiones, cuentas, audio o medallas al simplificar navegación.

## Evidencia y límites de la validación

- [CI verde original, 7/7](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/43502798220).
- [CI ampliado de Perfil móvil y web](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/43519421812): suites específicas completadas con éxito, compendio general de builds según la ejecución.
- [ ] Compilación release real de `apps/app_web` en Actions (añadida al espejo como gate; su resultado debe verificarse).
- [ ] Capturas y prueba de **navegador** en móvil/escritorio: configuración, permisos, navegación de programas, restauración y desconexión.
- [ ] **iPhone físico firmado**: el IPA de Actions es *unsigned* y no puede instalarse sin firma/provisión adecuada. El artefacto no es prueba física.
- [ ] **Android físico**: instalar el APK debug de Actions, probar permisos, backups y navegación; registrar dispositivo y versión.
- Las pruebas de widget no son un sustituto de VoiceOver, TalkBack, teclado real ni pruebas de 200% en cada subpantalla. Estas casillas C2–C7 siguen abiertas.
