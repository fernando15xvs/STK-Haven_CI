# Regla permanente de STK Haven — familias, variantes y demostraciones visuales

**Estado:** regla de producto aceptada el 28 de octubre de 2026. Especificación para iOS y Android; no habilita nuevos ejercicios automáticamente.

## 1. Dos niveles distintos

- **Familia de movimiento** (para navegación y búsqueda): p. ej. pecho → press horizontal, espalda → remos, piernas → sentadillas.
- **Variante ejecutable** (para entrenamiento, técnica, imágenes, historial y programación): entidad con **ID de ejercicio propio y estable** cuando cambian materialmente el implemento, el apoyo/postura, la trayectoria, el agarre, la unilateralidad o la ejecución.

No confundir **posición sentado** con **press inclinado**: la familia horizontal/inclinada/declinada depende del vector y la trayectoria del empuje, no de estar sentado o acostado.

## 2. Ejemplo obligatorio: press horizontal de pecho

| Variante | Aparato / postura | Media demostrativa |
| --- | --- | --- |
| Press banca plano con barra | Barra libre, acostado | 4 imágenes de ese montaje |
| Press banca plano con mancuernas | 2 mancuernas, acostado | 4 imágenes con mancuernas |
| Press plano en Smith | Barra guiada, banco plano | 4 imágenes mostrando raíles Smith |
| Press horizontal sentado en máquina convergente | Asiento, palancas convergentes | 4 imágenes de la trayectoria real |
| Press horizontal sentado en máquina fija | Asiento, agarres de recorrido fijo | 4 imágenes de esa máquina |
| Press unilateral horizontal en máquina | Un brazo, control troncal | 4 imágenes específicas unilateral |

**No crear ejercicios por marca/modelo comercial** si biomecánica, soporte, trayectoria y técnica son equivalentes. No fusionar las máquinas cuando esas características sí cambien.

## 3. Regla para imágenes y técnica

1. Cada variante habilitada necesita su **secuencia propia de 3 o 4 imágenes distintas** y su técnica específica. Preferencia: cuatro posiciones (inicio, ejecución, contracción y retorno).
2. **Nunca** reutilizar imágenes de press con barra en variantes de mancuernas, Smith o máquina. El equipo mostrado, postura, agarre, rango y trayectoria deben corresponder al ID real.
3. Estilo **anatómico realista, atlético y proporcionado**, como la referencia visual aprobada. **No** siluetas de palitos/círculos, formas geométricas esquemáticas ni personajes 3D provisionales.
4. PNG con transparencia verdadera, sin fondo ni texto de instrucción embebido. Flutter proporciona textos accesibles y localizables para cada paso; funcionar en claro/oscuro y con los ocho acentos.
5. **Rojo = músculos principales; azul = músculos secundarios.** Identificar zonas correctas por variante (ej. remo: deltoides posterior como secundario según ejecución). Los estabilizadores deben etiquetarse con precisión y sin inflar su contribución.
6. No declarar aprobado por CI verde: revisar manualmente calidad anatómica, corrección del equipo/ejecución, cuatro fases, recortes, transparencia y permisos/licencia antes de activar.
7. Mantener la separación entre medio **experimental/QA** y medio **aprobado**, sin habilitar masivamente los 229 borradores.

## 4. Integridad del catálogo

- Antes de añadir una variante, buscar si ya existe un ID en `preset_exercises.dart` o `curated_exercise_catalog.dart`; **no duplicarlo**.
- Preservar todos los IDs existentes, rutinas e historial; migraciones únicamente explícitas y probadas.
- La familia agrupa en la interfaz; **no sustituye** el ID específico que registra peso, series, descanso, progresión o unilateralidad.
- Aplicar estos criterios de forma uniforme a presses, remos, jalones, sentadillas, curls y demás familias.
- No modificar la web, Supabase o producción por documentar esta regla; los cambios móviles requieren sus propias pruebas y revisión.

## 5. Situación actual, no confundir con implementación completa

En la fase piloto hay imágenes solo para `ex_bench_press`, `ex_barbell_row` y `ex_squat`, habilitables con una bandera de compilación QA. **La regla está establecida, pero aún no existe la UI completa de familias y variantes ni imágenes aprobadas para todas las variantes**. El IPA CI #605 es solo una muestra experimental sin firma Apple.

**Fuente principal:** `fernando15xvs/STK-Haven`. **Espejo de CI exclusivamente público:** `fernando15xvs/STK-Haven_CI`. Rama `feat/mobile-lottie-batch1-drafts-20261018`; PR público #43 permanece abierto y sin fusionar.
