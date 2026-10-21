# STK Haven: comparación real 53-huesos GLB vs MP4

Los mismos GLB derivados del humano CC0 Innerscene (SHA pinneado) se
reproducen en Flutter y se capturan como 64 fotogramas por piloto,
16 FPS, 4 segundos, 320×320 y acento azul fijo en modo oscuro.

encode_video_comparison.py convierte estos fotogramas reales a MP4 H.264
baseline y compara tamaño contra el GLB LOD 53-huesos, nunca contra el
procedural v3.2. video_comparison_report.json incluye SHA de vídeos,
códec, tamaño, duración, ratio, tema fijo y estado NO aprobado.

Los vídeos se adjuntan solo a la evidencia CI del espejo público.
No se añade video_player, compatible desde SDK24+ en versiones recientes
mientras STK Haven debe preservar Android API23.
No se añaden assets al pubspec ni se distribuyen a los usuarios.
229 draft / 0 approved / 0 enabled. Sin GIF, web ni historial.
Los materiales del GLB se recolorean; el MP4 solo admite el tema
horneado en esta prueba. Se requiere revisar FPS/batería en dispositivos,
movimientos, oclusiones, licencia y segmentación muscular antes de
adoptar el formato final.
