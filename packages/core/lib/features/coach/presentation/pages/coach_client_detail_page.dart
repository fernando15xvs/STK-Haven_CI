import 'package:core/domain/models/coach_relationship.dart';
import 'package:core/features/coach/application/coach_client_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachClientDetailPage extends ConsumerWidget {
  final String relationshipId;

  const CoachClientDetailPage({
    super.key,
    required this.relationshipId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(coachClientProvider);
    final userId = ref.watch(appIdentityProvider).userId;

    CoachClientRelationship? relationship;
    for (final item in state.relationships) {
      if (item.id == relationshipId) {
        relationship = item;
        break;
      }
    }

    if (relationship == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cliente')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off_rounded, size: 42),
                const SizedBox(height: 12),
                const Text(
                  'La relación ya no está disponible en esta sesión.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref
                      .read(coachClientProvider.notifier)
                      .refreshRelationships(),
                  child: const Text('Actualizar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final asCoach = relationship.isCoach(userId);
    final counterpart = relationship.counterpartDisplayName?.trim();
    final displayName = counterpart?.isNotEmpty == true
        ? counterpart!
        : (asCoach ? 'Cliente vinculado' : 'Entrenador vinculado');

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          child: Icon(
                            asCoach
                                ? Icons.person_outline
                                : Icons.sports_outlined,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                asCoach
                                    ? 'Relación como entrenador'
                                    : 'Relación como cliente',
                              ),
                            ],
                          ),
                        ),
                        Chip(label: Text(_statusLabel(relationship.status))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'Permisos vigentes',
                  child: relationship.permissions.isEmpty
                      ? const Text('No hay permisos de datos concedidos.')
                      : Column(
                          children: [
                            for (final permission
                                in CoachPermission.values)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  relationship.permissions
                                          .contains(permission)
                                      ? Icons.check_circle_outline
                                      : Icons.block_outlined,
                                ),
                                title: Text(_permissionLabel(permission)),
                                subtitle: Text(
                                  relationship.permissions
                                          .contains(permission)
                                      ? 'Permitido'
                                      : 'No permitido',
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                _Section(
                  title: asCoach ? 'Cliente' : 'Entrenador',
                  child: Column(
                    children: [
                      _CapabilityTile(
                        icon: Icons.fitness_center_outlined,
                        title: 'Programa asignado',
                        subtitle: asCoach
                            ? relationship.allows(
                                    CoachPermission.assignPrograms,
                                  )
                                ? 'Disponible cuando D5/D6 active asignaciones seguras.'
                                : 'El cliente no concedió permiso para asignar programas.'
                            : 'Las asignaciones aparecerán aquí cuando D5/D6 estén activas.',
                        enabled: false,
                      ),
                      const Divider(height: 1),
                      _CapabilityTile(
                        icon: Icons.insights_outlined,
                        title: 'Progreso compartido',
                        subtitle: asCoach
                            ? relationship.allows(
                                    CoachPermission.viewProgress,
                                  )
                                ? 'Disponible cuando D7 active datos compartidos con RLS.'
                                : 'El cliente no compartió progreso.'
                            : 'Tus datos no se comparten hasta que D7 esté activo.',
                        enabled: false,
                      ),
                      const Divider(height: 1),
                      _CapabilityTile(
                        icon: Icons.monitor_weight_outlined,
                        title: 'Medidas',
                        subtitle: relationship.allows(
                                CoachPermission.viewMeasurements)
                            ? 'Permiso concedido; lectura remota aún no activada.'
                            : 'Sin permiso.',
                        enabled: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Este detalle no consulta datos de entrenamiento de otros usuarios '
                  'hasta que cada módulo tenga su propio contrato cloud y RLS. '
                  'La relación por sí sola no permite acceder a datos no autorizados.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;

  const _CapabilityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: enabled ? const Icon(Icons.chevron_right) : null,
    );
  }
}

String _permissionLabel(CoachPermission permission) => switch (permission) {
      CoachPermission.viewWorkouts => 'Ver entrenamientos',
      CoachPermission.viewProgress => 'Ver progreso',
      CoachPermission.viewMeasurements => 'Ver medidas',
      CoachPermission.assignPrograms => 'Asignar programas',
      CoachPermission.viewCheckins => 'Ver check-ins',
      CoachPermission.viewNutrition => 'Ver alimentación',
      CoachPermission.comment => 'Comentar',
    };

String _statusLabel(CoachRelationshipStatus status) => switch (status) {
      CoachRelationshipStatus.active => 'Activa',
      CoachRelationshipStatus.paused => 'Pausada',
      CoachRelationshipStatus.revoked => 'Revocada',
    };
