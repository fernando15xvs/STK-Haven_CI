# STK Haven — Medidas PNG anatómicas

La vista de Progreso → Medidas usa dos PNG **originales** de anatomía muscular
`body_front.png` y `body_back.png`, fondo transparente, con etiquetas,
puntos interactivos y líneas de medida dibujados dinámicamente por Flutter.

El botón **Frente / Espalda** cambia el cuerpo. Cada etiqueta o punto abre
`MeasurementMuscleDetailPage`, que utiliza un PNG específico de la región,
resalta visualmente la zona de interés, presenta el último perímetro real,
la fecha, el cambio y el historial completo con un gráfico.

**Campos actuales:** hombros, pecho, cintura, caderas, brazo izquierdo/derecho,
pierna izquierda/derecha y gemelos (solo general). No se inventan valores
independientes para trapecios, dorsales, bíceps ni pantorrillas I/D.

Los PNG de detalle se generaron a partir de los cuerpos originales con enfoque
regional; son imágenes ilustrativas, no certificados anatómicos de volumen.
Para el pecho se utiliza una ilustración específica con los pectorales azules.
Los registros, la gráfica previa, la base Hive y la web permanecen intactos.

Los archivos PNG están en `apps/app_mobile/assets/measurement_anatomy/png/`.
Se comprueban sus firmas PNG en Flutter y las cuatro capturas de ambos temas
y lados se guardan desde el runner Flutter en CI público.

**QA:** PR #43 abierto, rama `feat/mobile-lottie-batch1-drafts-20261018`,
sin merge ni activación en producción. El usuario debe revisar la calidad
visual de las ilustraciones antes de considerarlas definitivas.
