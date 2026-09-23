import 'package:core/core/services/backup_activity_service.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/profile/presentation/widgets/platform_settings_page.dart';
import 'package:core/features/sync/application/cloud_sync_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BackupStatusPage extends ConsumerWidget {
  const BackupStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(cloudSyncProvider);
    final activity = Hive.box(HiveBoxes.analyticsCache);

    return Scaffold(
      appBar: AppBar(title: const Text('Copias y restauración')),
      body: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: activity.listenable(
          keys: const [
            BackupActivityService.lastLocalExportKey,
            BackupActivityService.lastRestoreKey,
            BackupActivityService.lastRestoreSourceKey,
          ],
        ),
        builder: (context, _, __) {
          final local = BackupActivityService.lastLocalExportAt;
          final restore = BackupActivityService.lastRestoreAt;
          final restoreSource = BackupActivityService.lastRestoreSource;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusCard(
                icon: Icons.save_alt_rounded,
                title: 'Copia local',
                value: local == null
                    ? 'Aún no se registró una exportación local.'
                    : 'Última exportación: ${_formatDate(local)}',
                detail:
                    'Se genera como archivo JSON. Guárdalo en una ubicación que controles.',
              ),
              const SizedBox(height: 12),
              _StatusCard(
                icon: cloud.signedIn
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                title: 'Copia en la nube',
                value: !cloud.signedIn
                    ? 'Sin sesión de sincronización.'
                    : cloud.remoteUpdatedAt == null
                        ? 'Todavía no existe una copia remota.'
                        : 'Última copia: ${_formatDate(cloud.remoteUpdatedAt!)}',
                detail: cloud.signedIn
                    ? 'Cuenta: ${cloud.email ?? 'sesión activa'}'
                    : 'La nube es opcional; STK Haven sigue siendo local-first.',
              ),
              if (restore != null) ...[
                const SizedBox(height: 12),
                _StatusCard(
                  icon: Icons.restore_rounded,
                  title: 'Última restauración registrada',
                  value: _formatDate(restore),
                  detail:
                      'Origen: ${restoreSource ?? 'no especificado'}.',
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'DIRECCIÓN DE LOS DATOS',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              const _DirectionCard(
                icon: Icons.cloud_upload_outlined,
                title: 'Subir copia',
                direction: 'Este dispositivo  →  Nube',
                description:
                    'El estado actual de este dispositivo pasa a ser la copia remota de referencia.',
              ),
              const SizedBox(height: 10),
              const _DirectionCard(
                icon: Icons.cloud_download_outlined,
                title: 'Restaurar nube',
                direction: 'Nube  →  Este dispositivo',
                description:
                    'La copia remota reemplaza los datos locales de STK Haven. No se fusionan silenciosamente.',
                destructive: true,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PlatformSettingsPage(),
                  ),
                ),
                icon: const Icon(Icons.settings_backup_restore_rounded),
                label: const Text('Administrar sincronización'),
              ),
              const SizedBox(height: 8),
              Text(
                'Antes de restaurar desde la nube, exporta o sube el estado local actual si necesitas conservarlo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(value),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionCard extends StatelessWidget {
  const _DirectionCard({
    required this.icon,
    required this.title,
    required this.direction,
    required this.description,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String direction;
  final String description;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = destructive ? colors.error : colors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        color: accent.withValues(alpha: 0.07),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 5),
                Text(
                  direction,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 5),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
