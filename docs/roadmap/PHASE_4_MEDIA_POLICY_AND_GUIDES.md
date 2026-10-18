# STK Haven — Fase 4: medios de ejercicios y guías específicas

**18 de octubre de 2026 — Primera entrega de Fase 4.**

## Alcance incorporado

- `ExerciseDemonstrationLibrary`: 43 guías con tres pasos propios de cada ejercicio (preparación, ejecución, precaución). Los otros ejercicios curados reciben texto a partir de su definición particular; los personalizados mantienen sus propias instrucciones.
- `ExerciseDemonstrationCard`: ficha que prioriza la técnica sobre las estadísticas; tiene espacio para GIF específico y permite pausar/reproducir. Si el recurso no está disponible, falla de forma segura a texto, sin ilustraciones de otro ejercicio.
- `ExerciseLibraryPage` selección: vista previa de técnica con `Volver` y `Seleccionar ejercicio`; nunca se añade una selección al cancelar.
- Preferencias `reduceMotion` y ahorro del usuario: no reproducir movimiento, especialmente en dispositivos de menor capacidad.
- `approvedMedia` está vacío **intencionalmente**. No se presentan vídeos ni GIFs como si estuvieran implementados.

## Validación indispensable ANTES de incorporar un GIF

1. **Movimiento exacto**: vincular a un único `Exercise.id`. Verificar variante, máquina/barra/mancuerna, bilateral/unilateral y recorrido visual. Un GIF genérico de sentadilla no equivale automáticamente a sentadilla hack ni a sentadilla frontal.
2. **Derechos documentados**: autorización escrita para almacenar, empaquetar, redistribuir **comercialmente**, utilizar offline, modificar si fuera necesario y mostrar en una app pública. Guardar autor, enlace, alcance, vigencia y condiciones. GitHub público o licencia MIT de **código** no concede permisos sobre las imágenes de terceros.
3. **Revisión de técnica**: contrastar movimiento con las tres indicaciones de la ficha; un entrenador cualificado debe aprobar la animación, el punto de vista y posibles advertencias.
4. **Archivo local verificado**: GIF optimizado y/o poster en `apps/app_mobile/assets/exercise_media/`; darlo de alta en `pubspec.yaml` solo cuando existan archivos. Registrar metadatos en `ExerciseDemonstrationLibrary.approvedMedia`.
5. **Accesibilidad**: texto alternativo equivalente en guía, respeto por `SettingsState.reduceMotion`, posibilidad de pausar, sin destellos; bajo consumo, pruebas sin conexión y fallback cuando el recurso no abra.
6. **Mediciones**: comparar APK/IPA antes y después, memoria de decodificación y duración de carga; no descargar recursos multimedia al iniciar la app.

### Guía de permisos

- `distributionPermission` debe documentar un derecho real verificable; no basta rellenar un texto arbitrario. El diccionario actual se deja vacío hasta revisión humana de derechos.
- Las colecciones de GIFs de ExerciseDB v1 republicadas por terceros indican reservas de copyright y restricciones a redistribución/comercialización; **no** se incorporarán por simple copia desde GitHub.
- Los vídeos externos deben venir de fuentes autorizadas por los titulares. No introducir URLs remotas arbitrarias en presets.
- Una captura de referencia facilitada por el usuario no concede permiso de copiar sus animaciones.

### Lo que sigue pendiente

- Primera tanda de 30–40 GIFs **reales** y licenciados con correspondencia exacta.
- Posters accesibles y reproducción offline bajo todas las preferencias de movimiento/ahorro.
- Revisión clínica/biomecánica externa y pruebas en dispositivos físicos al cierre del roadmap, antes de producción.

**Persistencia:** este bloque no modifica `Exercise`, `HiveExercise`, snapshots, PRs, rutinas, favoritos, pesos, descansos ni registros. Los medios viven en un registro independiente.
