# STK Haven — F: auditoría final y puerta de dispositivo (24/11/2026)

## Base validada
- PR privada #57 DRAFT; HEAD d968717a67a60ffc71db2631600d2d29e0695145, espejo e687bfba98d7583a09dfd2f380bfd102e79f7300.
- [CI #45490897221](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/45490897221): siete jobs success; auditoría 3D histórica manual skipped (fuera del gate).
- Core purity, inventario, guardia incremental, Analyze Core/Mobile y Dart tests aprobados. El inventario es léxico, no una demostración de ausencia de toda dependencia semántica.
- Artefactos previos: [iOS unsigned](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/45490897221/artifacts/14966881972), [Android debug QA](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/45490897221/artifacts/14966817498). iOS sin firma NO es instalable por sí solo; no desinstalar la app existente. Estos artefactos no son del nuevo commit F.

## Gate automatizado F
- [ ] Nueva guardia de manifest Core y fronteras en tests/producción, cero violaciones; mantener baseline histórico sin excepciones activas.
- [ ] Test de SettingsNotifier + Hive persistente + reinicio + backup/restore con perfil existente, historial y ajustes de entrenamiento.
- [ ] Matriz Perfil/Ajustes 27 combinaciones: anchos 320/390/430 y texto 100/160/200%, claro/oscuro/OLED.
- [ ] CI 7/7 del último SHA y paridad exacta de todos los archivos modificados; no copiar configuración QA privada al espejo.
- [ ] Obtener artefactos finales de ese mismo SHA. No confundir compilación y firma.

## Dispositivos físicos — todos pendientes, no simulados por CI
Registrar modelo, OS, versión de app, SHA, resultado y evidencia sin datos personales.
| Caso | Criterio |
| --- | --- |
| Actualización iOS y Android | Misma identidad de aplicación y firma compatible, sin desinstalar; respaldo previo y sin repetir onboarding |
| Arranque offline | Perfil, foto local, rutinas, historial, medidas y preferencias conservados |
| Aspecto | 4 familias, 3 estilos, 4 tamaños; claro/oscuro/automático/OLED, reinicio y contraste |
| Perfil/Ajustes | Foto, editar, logros, navegación y consentimiento; VoiceOver/TalkBack, teclado y texto ampliado |
| Workout | sesión activa, salir/volver, reanudar sin cero transitorio, series unilaterales y pausa entre lados |
| Descanso nativo | fin a cero cancela notificación; música de tercero no se detiene; bloqueo, background y permisos |
| Inicio/Entrenar/Progreso | sesión exacta, sin duplicados, gráficos y unidades reales, navegación inferior |
| Nutrición | sin nuevas capacidades por DOB, menores sin objetivos numéricos; comprobar estados legal/backend existentes |
| Fe/Coach/Hábitos | avisos, preferencias, rutas y controles de consentimiento |
| Copia/restore | respaldo previo verificable, no restaurar sobre datos únicos sin autorización; probar con copia aislada |

## Condiciones de release
- [ ] Firma y provisión iOS válida y compatible con la app instalada; no hay evidencia de credenciales disponibles.
- [ ] Android: verificar firma de actualización y no distribuir debug como release.
- [ ] Autorización explícita para merge/publicación; ninguna modificación de Supabase remoto o flags legales como parte de F.
