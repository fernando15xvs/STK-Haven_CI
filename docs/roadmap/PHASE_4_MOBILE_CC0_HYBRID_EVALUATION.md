# STK Haven — licencias CC0 y laboratorio híbrido móvil (2026-10-21)

## Modelo humano seleccionado para evaluar
Innerscene: Human base mesh with editable 53-bone rig, GLB de 4,8 MB.
El autor lo declara CC0 1.0 y lo basa en componentes MakeHuman/MPFB CC0.
Fuente y descarga:
https://www.innerscene.com/tools/library/3d-parts/human-base-mesh-with-editable-53-bone-rig-8e7c8ab1

El permiso anunciado admite uso comercial, modificación y redistribución
sin atribución obligatoria. Guardar autor, URL, licencia y SHA256 de cada
archivo real importado en source_provenance.json. Esta base está riggeada
pero NO es un ecorché hiperrealista ni incluye animaciones: faltan retargeting
de 19 a 53 huesos, anatomía muscular, esculturas y review humano.

Otras fuentes: MakeHuman/MPFB core CC0
https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.md
y Blender Studio Human Base Meshes CC0
https://www.blender.org/download/demo-files/#assets
Los extras de terceros pueden tener licencias diferentes. Z-Anatomy tiene
CC-BY-SA para material adaptado, no es la fuente base CC0 seleccionada.
No usar modelos/animaciones Mixamo brutos en un producto de redistribución
sin revisar sus condiciones de licencia.

## Implementación verificable
- model_license_registry.json guarda fuentes y estado no aprobado.
- stage_cc0_humanoid.py permite importar GLB desde archivo autorizado o
  descargar desde URL verificada. Inspecciona GLB, 45-120 joints y
  dependencias de textura; genera SHA256 y manifiesto. Si la descarga
  opcional falla, registra source_unavailable, NO crea un modelo falso.
- anatomical_video_capture_test.dart renderiza 64 fotogramas de cada GLB
  experimental v3.2, bajo Flutter, desde exactamente la misma geometría
  usada en la prueba 3D. Aún NO es la nueva base CC0.
- encode_video_comparison.py genera 3 MP4 H.264 baseline, 320x320,
  16 fps, 4 s, CRF24; video_comparison_report.json registra tamaño, códec,
  duración, fps y digest. Sin GIF y sin nuevas dependencias de Flutter.
- CI espejo público genera artefactos de GLB, MP4 y registro de licencia,
  pero ninguno forma parte del bundle del usuario ni del catálogo.

## Límites
Se conserva Android minSdk23. Video_player reciente pide SDK24+ según:
https://pub.dev/packages/video_player
No añadirlo aún. El MP4 lleva acento azul y fondo oscuro fijos;
el GLB soporta recoloreado temático dinámico. No afirmar equivalencia
en las 16 apariencias, ni comparación definitiva de calidad profesional.
Todavía falta un modelo 53-huesos retargeteado y animado, así como
medición de CPU, memoria, energía, H.264 hardware, jank y calidad visual
en Android e iPhone físicos.

Fuente privada STK-Haven; espejo público STK-Haven_CI, PR #43. Nada en
apps/app_web, historial ni Supabase. 229 draft / 0 approved / 0 enabled.

## Descarga real comprobada por CI #433
- Archivo CC0 en artefacto `stk-haven-visual-pilots`, 4.994.640 bytes.
- SHA-256 inmovilizado en el registro de fuentes:
  `7135e03b6259e970458deff3e0458610914d7c35164cae12611101361e4a5749`.
- 53 huesos, 55 nodos, 1 malla, 1 material y **0 animaciones**.
- Se guardó el asset **solo en artefactos de QA, no en la app**. Cualquier cambio futuro de bytes bloquea el stage y requiere revisión de procedencia.
- Los vídeos MP4 experimentales siguen representando el GLB geométrico v3.2, no este cuerpo CC0; hace falta retargeting antes de comparar calidad final.
