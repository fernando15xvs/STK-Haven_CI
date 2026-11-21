# STK Haven — Barra inferior sin tarjeta (21/11/2026)

**Solicitud visual aprobada:** quitar por completo la tarjeta rectangular/redondeada alrededor de las pestañas; bajar un poco los iconos sin invadir la zona segura del iPhone.

## Cambio implementado

- `HomeScreen` ya no usa `_BottomBarSurface`. Se eliminan **fondo propio, borde, radio y sombra** del contenedor que envolvía Inicio, Entrenar, «+», Progreso y Perfil.
- Los cinco accesos aparecen directamente sobre el fondo actual de la pantalla. La barra **no introduce otra tarjeta**, y conserva selección azul y contraste definido por `AppColors`.
- Se bajan los iconos/etiquetas reduciendo el padding inferior de cada pestaña de **10 dp a 2 dp**; el botón circular «+» permanece centrado y separado de los accesos.
- Se mantiene `SafeArea(top: false)` del sistema, que respeta el indicador de inicio de iPhone y las barras de navegación de Android.
- Se conserva `MotivationHomeMiniPlayer` con espacio real sobre la fila y el menú «+» con todas las opciones/condiciones originales.
- No se modifican pantallas Inicio/Entrenar/Progreso/Perfil, navegación `IndexedStack`, audio, estado del programa, datos Hive ni Supabase.

## Comprobaciones

- [x] Contrato estático `home_flat_bottom_navigation_contract_test.dart`: confirma ausencia de `_BottomBarSurface`, `BoxDecoration`, sombra y borde en la zona de pestañas; `SafeArea`, cuatro rutas y «+» intactos.
- [ ] Último **CI 7/7** en el espejo tras el cambio.
- [ ] Capturas físicas en iPhone y Android, modo claro/oscuro/OLED y ancho ~320/390/430 dp; contraste y etiqueta de pestaña activa.
- [ ] Comprobar con fuente al 160/200% que «Progreso» no se recorta y que los botones siguen siendo pulsables.
- [ ] Probar menú «+», cambio de tabs, mini reproductor, cronómetro y navegación de retorno con sesión activa.
- [ ] Verificar especialmente espacio bajo las etiquetas hasta el indicador blanco del iPhone; no modificar el safe area para bajar los iconos más allá de lo seguro.

**Nota:** compilaciones iOS de CI sin firma no equivalen a pruebas físicas ni preservan automáticamente una instalación existente sin firma compatible.
