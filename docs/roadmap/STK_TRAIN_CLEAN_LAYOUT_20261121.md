# STK Haven — Entrenar limpio y sin duplicados (21/11/2026)

**Decisión aprobada:** rediseñar Entrenar como centro de acción; sin título redundante, sin repetición inmediata de la rutina destacada y sin otra tarjeta pesada para el programa. Se conserva el diseño Outfit/temas de la app.

## Implementado
- [x] Se retira el título de contenido «Entrenar»; la pestaña ya identifica la pantalla.
- [x] La sesión activa o siguiente ocupa el ancho completo, con contenido más compacto y una sola CTA principal.
- [x] Se muestra «EN CURSO» / «PENDIENTE DE REVISAR» para sesiones existentes y «SIGUIENTE SESIÓN» para la proyección real.
- [x] La rutina destacada queda oculta del listado inmediato por ID, sin eliminarse. El listado inicial muestra hasta tres rutinas distintas; «Ver todas las rutinas» es un botón funcional que revela todas, incluida la destacada, con sus opciones de edición.
- [x] Mientras hay sesión activa, no se ofrecen CTAs para iniciar otra rutina; los menús CRUD siguen disponibles.
- [x] El programa se presenta como franja sin tarjeta extra, con nombre/semana/meta/progreso sustentados.
- [x] Planificación permanece accesible; «Gestionar» agrupa Administrar, Plantillas de rutinas, Plantillas de programas y Crear plan (cuando procede).
- [x] Se preservan WorkOutLauncher, ActiveWorkoutPage, proveedores, IDs, historial, Hive, Supabase y navegación existente.
- [x] Contrato de fuente actualizado y matriz widget de ancho completo 320/390/430 dp a 100/160/200% en claro/oscuro.

## Validación pendiente
- [x] CI de la entrega visual inicial: 7/7 success en `44955992661` (SHA `d285b9bbbdf1775c3f33aa76181fc9c5cbddc21b`).
- [ ] Confirmar CI del último SHA con `flutter test test/features/routines` agregado al trabajo Mobile Test.
- [x] Primera ejecución de la etapa nueva: 48 tests PASS, 2 contratos antiguos FALLARON. Se corrigen las expectativas: umbral adaptativo >=/<460dp para «Anterior» y desplazamiento real de los cuatro CheckboxListTile de creación de plan. Ningún cambio de comportamiento de producción.
- [x] Añadidas pruebas widget de pantalla completa: rutina destacada oculta en el listado inicial, expansión que revela todas, «Gestionar» con sus accesos, y bloqueo de otro «Iniciar» durante una sesión activa.
- [ ] QA físico iPhone/Android: sesión activa, programa flexible/pausado, restauración, scroll y fondo seguro.
- [ ] Comprobar VoiceOver/TalkBack, teclado y todas las combinaciones OLED/acentos en equipos físicos.
- [ ] Revisión visual de capturas físicas, sin confundir CI verde con una IPA firmada.

**Integración:** solo PR #57 (DRAFT) en el repositorio privado. `STK-Haven_CI/main` es un espejo técnico sin PR. No fusionar sin autorización.
