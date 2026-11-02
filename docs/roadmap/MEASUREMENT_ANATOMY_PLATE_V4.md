# STK Haven — siluetas anatómicas v4 para Progreso → Medidas

**Estado:** arte vectorial original y vista interactiva implementados en rama de desarrollo, pendientes de aprobación artística del usuario. No copiar, calcar ni redistribuir Shutterstock.

## Motivo

La primera versión de `CustomPainter` parecía un maniquí geométrico; la segunda mejoró el contraste, pero conservaba un aspecto demasiado esquemático. Esta revisión reconstruye las dos láminas como **siluetas humanas negras con separación muscular blanca**, con proporciones de atleta estético y postura frontal/posterior neutral. Evita cuerpos de palitos, extremidades cilíndricas, piernas unidas, manos sobredimensionadas y pies rectangulares.

## Recursos y aplicación

- `apps/app_mobile/assets/measurement_anatomy/stk_anatomy_front.svg`
- `apps/app_mobile/assets/measurement_anatomy/stk_anatomy_back.svg`
- `apps/app_mobile/lib/features/progress/presentation/widgets/body_anatomy_vector_data.dart`

Los SVG y el renderizado nativo de Flutter comparten exactamente los mismos contornos M/L/Q/Z (sin dependencias de SVG en producción); el test de Flutter verifica esa coincidencia y genera capturas con ambos temas. La lámina permanece negro-blanco sobre una superficie clara constante en modo oscuro y claro, con el color de acento solo para la medida seleccionada. Los nueve campos de perímetro existentes son seleccionables con hitboxes accesibles; se conserva el valor más reciente válido por campo, fecha y evolución sin inventar tamaños de músculos individuales.

**Diseño v4:** cabeza, cuello, deltoides, pectorales, abdomen recto en compartimentos, oblicuos, serratos, bíceps, antebrazos, cuadríceps, rodillas, tibiales, trapecios, romboides, dorsales, erectores, glúteos, isquios y gemelos. Las piernas son piezas separadas y reflejadas, con un canal central continuo.

**Limitación honesta:** las láminas son arte lineal original, no atlas anatómico médico ni la imagen comprada del usuario. Aún requieren aprobación visual; su utilidad principal es ubicar perímetros registrados, no expresar medidas anatómicas de músculos.

## Validación

Flutter QA público: `.github/workflows/measurement_map_qa.yml`, que analiza el widget, prueba datos parciales, brazos/piernas I/D, pantalla estrecha y crea dos capturas de pantalla reales. El CI público general mantiene la validación ajena de recursos 3D antiguos y puede fallar por descarga CC0; no debe confundirse con la UI de Medidas.

No hay cambios en `main`, Supabase, web, historial de registros, ni en el catálogo de 229 ejercicios. Repositorio privado: `fernando15xvs/STK-Haven`; espejo CI público: `fernando15xvs/STK-Haven_CI`; PR público #43 abierto, no fusionado.
