# STK Haven — resumen de Medidas, altura e interfaz (móvil)

Estado: implementado en la rama móvil `feat/mobile-lottie-batch1-drafts-20261018`; PR público #43 **sin fusionar**.

## Interfaz (referencia del usuario)
- Conserva los PNG anatómicos transparentes originales, selector Frente/Espalda, etiquetas al costado y detalles táctiles.
- Añade al pie una tarjeta **Resumen de medidas**, estilo compacto con iconos, cuatro indicadores (2×2 en teléfono): **Peso**, **Grasa corporal**, **Cintura/cadera** y **Altura**.
- Las cifras se cargan de los registros reales y se muestran en tema oscuro y claro con los ocho colores de acento desde `AppColors.of(context)`. No se muestran números de ejemplo.
- Peso respeta kg/lb configurados; grasa muestra %, altura se ingresa y presenta en cm. Las diferencias usan signo neutro (ningún cambio de perímetro se clasifica como bueno/malo).
- Relación cintura/cadera se calcula solo de un registro que tenga ambos perímetros juntos; nunca une una cintura de una fecha con una cadera de otra.
- Registros incompletos/antiguos y valores no finitos se ignoran **por métrica**; sin dato muestra un guion y mensaje para registrar la altura.

## Persistencia
Se incorporó `heightCm` opcional a `BodyMeasurement` y `HiveBodyMeasurement`; se agregó como `@HiveField(13)` manteniendo los campos 0–12 intactos. Adaptador Hive actualizado a 14 campos, lectura con `fields[13] as double?` que acepta registros previos sin el campo. No se borra ni reescribe el historial de ningún usuario.

La hoja **Nueva medida** / **Editar medida** tiene ahora el campo **Altura (cm)**; rango validado 50–250 cm, opcional. Se puede guardar solo la altura. Se siguen respetando el guardado, control de errores, cancelación, teclado iOS, recordatorios y editor de historial existentes. El resumen en el mapa se actualiza automáticamente tras guardar.

## Pruebas
- `packages/core/test/features/progress/measurement_height_hive_test.dart`: mapeo y compatibilidad de valores antiguos nulos.
- `apps/app_mobile/test/features/progress/body_measurement_summary_test.dart`: datos parciales, razón emparejada por fecha, valores inválidos, kg/lb, 8 acentos y ambos temas en pantalla de 320 px.
- QA específico en el workflow público `.github/workflows/measurement_map_qa.yml`. El CI general conserva el control Android/iOS.

Sin cambios en web, Supabase, IDs de catálogo, producciones o rama principal. Este diseño es una **implementación móvil de las tarjetas del ejemplo**, no una copia de su arte de terceros.
