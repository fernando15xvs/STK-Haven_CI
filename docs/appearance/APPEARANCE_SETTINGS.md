# Aspecto de STK Haven

Perfil > Aspecto (Android/iOS) o Personalizar aspecto (web).

- Claro, oscuro o automático según el dispositivo. Conserva oscuro para instalaciones antiguas.
- Ocho acentos: Zafiro, Amatista, Esmeralda, Océano, Rosa, Ámbar, Coral y Pizarra.
- Negro puro OLED solo en modo oscuro.
- Relieve sutil o tarjetas planas.
- Acceso a reducir animaciones (respeta también sistema y modo ahorro).
- Vista previa y guardado al seleccionar. Restablecer afecta colores/acabado, no datos de entrenamiento.

AppearanceSettings forma parte de SettingsState: persistencia Hive y backups existentes.
La paleta compartida AppColors es una ThemeExtension consultada con BuildContext.
No hay una paleta global mutable ni se recrea el navegador al cambiar preferencias.
Pantallas, diálogos, hojas, gráficos y botones consultan el tema actual. Los colores
fijos que representan discos de pesas y el arte del logotipo conservan su identidad.

Cada acento adapta su luminosidad para contraste >=4.5:1 en los tres fondos.
El texto de botones usa onPrimary (negro/blanco según contraste).
Tarjetas de ambas plataformas comparten relieve discreto, sin desenfoques costosos.

La pantalla nativa de arranque anterior a Flutter y el icono del sistema conservan
sus recursos de marca; las preferencias se aplican dentro de la app.

Validación: pruebas de contraste de los ocho acentos en ambos modos, serialización,
compatibilidad de backups antiguos, OLED, relieve, cambio de brillo del sistema sin
perder texto introducido y configuración en pantalla compacta. CI incluye web
(dart2js/WASM), Android e iOS. La revisión en dispositivo físico es posterior.
