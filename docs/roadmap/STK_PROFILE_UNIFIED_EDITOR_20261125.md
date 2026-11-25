# Perfil unificado — entrega única (25/11/2026)
Base funcional CI #45710043493 7/7. PR privada #57 draft; Web congelada.
- Perfil sin título duplicado, foto centrada 108dp, nombre y editar debajo; Ajustes accesible. Datos personales consentidos separados de preferencias; formato DD/MM/AAAA; unidades solo Ajustes, reconocimientos conservados.
- Editor único con foto/avatar bajo demanda, preferencias personales, entrenamiento, modo de uso, Fe/reflexiones y privacidad. Antiguo acceso Tu experiencia eliminado; follow-up legacy abre el mismo editor. Clase antigua solo redirección compatible.
- Core ProfileEditPolicy fusiona campos editables, protege elegibilidad, ajustes y cambios concurrentes; consentimiento explícito y eliminación voluntaria, guarda perfil una vez, sincroniza visibilidad y avisos de Fe. No se modifica programa activo ni datos reales.
- Pruebas de merge/consentimiento, edición conjunta, geometría, navegación, responsive y contratos de seguridad actualizados. Pendiente CI único del SHA final y QA física.
- Decisión: las unidades y notificaciones se conservan como ajustes operativos, los permisos generales permanecen en Legal y privacidad; datos demográficos tienen un único editor. No se cambia el esquema de persistencia ni onboarding.

### Corrección del gate Mobile
CI #45715280057: 37/38 pruebas de Perfil; `unified_profile_editor_test.dart` falla en scrollUntilVisible por múltiples Scrollable (ListView y campo editable). Se identifica el ListView del editor y se selecciona exclusivamente su Scrollable vertical, se cierra el foco de teclado y se garantiza visibilidad antes de pulsar. Se reutiliza el selector en las pruebas de edición demográfica/follow-up. Se mantienen las aserciones de guardado único, avatar, nombre, frecuencia y navegación. El upload QA posterior falló porque la etapa previa interrumpió la generación de imágenes; no se relaja el requisito de artefactos. Nuevo CI pendiente.
