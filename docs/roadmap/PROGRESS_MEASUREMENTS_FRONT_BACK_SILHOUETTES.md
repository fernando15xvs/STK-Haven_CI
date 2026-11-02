# STK Haven — Progreso / Medidas: mapa corporal frontal y posterior

Estado: implementado en Flutter móvil, rama `feat/mobile-lottie-batch1-drafts-20261018` (PR público #43 sin fusionar).

## Implementación

La pestaña **Progreso → Medidas** presenta **dos siluetas vectoriales propias** hechas con `CustomPainter`: frente y espalda, simultáneamente, adaptadas a modo claro/oscuro y color de acento. No se incorporó la imagen con marca de agua de Shutterstock proporcionada como referencia.

Zonas táctiles accesibles con nombres/valores y chips alternativos, incluso en pantallas de 320 dp. Al seleccionar una región se presenta la medida guardada más reciente, fecha, valor anterior de otra fecha, cambio absoluto e historial. La selección sincroniza la métrica en la gráfica de evolución que ya tenía la app. No se modifican formularios ni registros pasados.

## Correspondencia con el esquema real, sin inventar tamaños musculares

| Campo Hive existente | Frente | Espalda | Notas |
|---|---|---|---|
| `shouldersCm` | hombros | hombros | perímetro |
| `chestCm` | pecho | — | perímetro torácico |
| `waistCm` | cintura | cintura | el mismo valor |
| `hipsCm` | caderas | glúteos/caderas | el mismo valor |
| `leftArmCm`, `rightArmCm` | cada brazo | cada brazo | derecha/izquierda anatómica, no de pantalla |
| `leftLegCm`, `rightLegCm` | cada muslo | cada muslo | un registro por lado |
| `calvesCm` | gemelos | gemelos | **un único valor general**, no inventar lados |
| `weightKg`, `bodyFatPercentage` | — | — | son globales y continúan en el historial |

**No** hay registro actual separado de bíceps, tríceps, romboides, dorsales, cuello, antebrazos o pantorrillas I/D; esos músculos pueden estar dibujados en las siluetas, pero **nunca** se etiquetan con centímetros inventados.

Cada campo busca su última medición válida y positiva **independientemente**, ya que los registros son parciales. La comparación utiliza el valor anterior en una fecha distinta; si no existe, muestra el estado sin referencia. Una subida/bajada es neutral, porque más perímetro no siempre significa más músculo.

## Pruebas y restricciones

Prueba móvil `test/features/progress/body_measurement_silhouette_test.dart`: datos parciales, diferentes fechas, invalidaciones, pantalla compacta, ambos temas, selección táctil frontal/trasera, vacío. Se integra en el test completo Flutter del CI público.

Sin migraciones, cambios en Supabase, web o modelo Hive. Sin nuevas dependencias, archivos de fuentes o imágenes de terceros. Los historiales, IDs, recordatorios y gráfica preexistente permanecen conservados.

Pendiente potencial: si en un futuro se agregan medidas específicas de cuello, antebrazo o pantorrilla por lado, debe aprobarse primero la evolución de esquema Hive, validaciones y migraciones, no inferirlas de los datos existentes.


## Revisión visual v2 — silueta como referencia (29-10-2026)

La primera silueta geométrica resultó visualmente insuficiente y fue reemplazada,
no ampliada. El cuerpo ahora utiliza **arte anatómico vectorial original**:
figura de tinta negro intenso, separaciones musculares blancas, anatomía de
pectorales/abdomen/deltoides/cuádriceps y, desde atrás, trapecio/dorsales,
glúteos/isquios/pantorrillas. Los SVG editables son
`apps/app_mobile/assets/measurement_anatomy/stk_anatomy_front.svg`
y `stk_anatomy_back.svg`. Se basan en vectores propios y NO incluyen ni
reproducen los archivos de Shutterstock compartidos como inspiración.

La app interpreta exactamente esos mismos caminos en Flutter Canvas (sin
`flutter_svg`, cambios en `pubspec.lock` o rasterización borrosa) desde
`body_anatomy_vector_data.dart`. La prueba verifica 1:1 los caminos SVG
y Dart, carga de ambos assets, mapa en 320 dp, modos claro y oscuro,
registro histórico y captura de pantalla real. Se usan fondos claros dentro
de las dos figuras aun en modo oscuro para conservar el contraste
negro/blanco, sin alterar el tema de la tarjeta.

Selección en el mapa: un contorno suave con el color de acento y un punto
táctil accesible. Los mismos nueve perímetros ya existentes son la fuente
de verdad. **No** son medidas aisladas de cada músculo del dibujo y
ningún nuevo campo ha sido agregado a Hive o Supabase.

**Validación específica:** [Measurement Map QA #9](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/40967241248) aprobó test Flutter y analyzer,
generando dos capturas de pantalla de la UI real para revisión. Este verde
no implica un merge del PR #43 ni valida por sí solo los demás módulos.
