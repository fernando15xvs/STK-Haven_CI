# STK Haven · C.3 — Core Dart puro: puertos de plataforma y regresión de datos

## Cambios agrupados
- Core recibe el cliente `supabase` Dart de `SupabaseFlutter.initialize` por inyección; no crea otro cliente, sesión o Auth y preserva RLS.
- Las dependencias de `flutter_riverpod` migran a `riverpod`; repositorios Hive usan `package:hive`; `Hive.initFlutter()` queda en el bootstrap Mobile antes de abrir cajas.
- `VerseWidgetSync`, `VerseBackgroundService`, `DailyVerseSettingsService`, `BackupFileService` y `DataExportService` quedan como API/puertos Dart Core; adaptadores Workmanager, MethodChannel, FilePicker, SharePlus y almacenamiento temporal viven en Mobile.
- `BibleDatabase.instance` en Core es una fachada Dart con APIs públicas idénticas, mientras SQLite/Sqflite permanece en Mobile y sigue abriendo **`biblia_v4.db`**, tabla e índices sin cambio. El isolate de Workmanager registra su propia instancia de SQLite.
- Preferencias históricas (versículo guardado, estado de consentimiento, estado de ánimo, horarios, reflexiones) mantienen **las mismas claves** mediante `CorePreferences`, cuyo adaptador Mobile usa el mismo `SharedPreferences.getInstance()`. El valor vacío de `STK_STORAGE_NAMESPACE` conserva el almacenamiento existente.
- `WorkoutCsvExport` en Core conserva BOM UTF-8, encabezados y 19 columnas; únicamente los archivos temporales y la hoja nativa de compartir quedan en Mobile.
- 167 archivos de tests Core usan el paquete Dart `test` y no incluyen `testWidgets` ni test de canales; tests de plugins/UI están en Mobile.
- Archivos `apps/app_web/**` no tocados. Core conserva los mismos modelos, ID de usuario, claves Hive, RIR, sesiones y políticas 15+/adultos; no hay migraciones SQL ni reseteo de onboarding.

## Criterios pendientes, no asumidos
- [ ] Ejecución de `flutter pub get --enforce-lockfile`, análisis Core/Mobile y pruebas Dart Core, Mobile, APK/IPA en espejo CI.
- [ ] Trasladar ocho providers de estado de `features/*/presentation/providers` a `features/*/application/providers`.
- [ ] Guardar evidencia de 0 importaciones Core Flutter/UI/plugins, 0 Core→Mobile/Web y 0 Mobile→Web; pasar gate arquitectónico estricto sin excepciones nuevas.
- [ ] Pruebas físicas Android e iOS: base bíblica guardada, zona horaria, notificaciones de consentimiento, reinicio, exportación/importación local y datos anteriores sin onboarding nuevo.
- [ ] No fusionar PR #57 hasta aprobación explícita.
