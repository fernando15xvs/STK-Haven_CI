import 'package:core/domain/models/coach_relationship.dart';
import 'package:core/features/coach/application/coach_client_provider.dart';
import 'package:core/features/coach/presentation/pages/coach_client_progress_page.dart';
import 'package:core/features/coach/presentation/pages/coach_program_assignments_page.dart';
import 'package:core/features/coach/presentation/pages/coach_tasks_page.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/nutrition/presentation/pages/coach_nutrition_guidance_page.dart';
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
                        title: 'Programas asignados',
                        subtitle: asCoach
                            ? relationship.allows(
                                    CoachPermission.assignPrograms,
                                  )
                                ? 'Enviar una copia versionada de un programa local.'
                                : 'El cliente no concedió permiso para asignar programas.'
                            : 'Revisar, aceptar e instalar programas recibidos.',
                        enabled: !asCoach ||
                            relationship.allows(
                              CoachPermission.assignPrograms,
                            ),
                        onTap: !asCoach ||
                                relationship.allows(
                                  CoachPermission.assignPrograms,
                                )
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CoachProgramAssignmentsPage(
                                      clientUserId:
                                          relationship!.clientUserId,
                                      clientDisplayName: displayName,
                                    ),
                                  ),
                                )
                            : null,
                      ),
                      const Divider(height: 1),
                      _CapabilityTile(
                        icon: Icons.insights_outlined,
                        title: 'Progreso compartido',
                        subtitle: asCoach
                            ? relationship.allows(
                                    CoachPermission.viewProgress,
                                  )
                                ? 'Ver frecuencia, minutos, volumen, RIR y resúmenes permitidos.'
                                : 'El cliente no compartió progreso.'
                            : 'Revisa la misma vista resumida que puede consultar tu entrenador.',
                        enabled: !asCoach ||
                            relationship.allows(
                              CoachPermission.viewProgress,
                            ),
                        onTap: !asCoach ||
                                relationship.allows(
                                  CoachPermission.viewProgress,
                                )
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CoachClientProgressPage(
                                      clientUserId:
                                          relationship!.clientUserId,
                                      clientDisplayName: displayName,
                                    ),
                                  ),
                                )
                            : null,
                      ),
                      const Divider(height: 1),
                      _CapabilityTile(
                        icon: Icons.task_alt_outlined,
                        title: 'Tareas asignadas',
                        subtitle: asCoach
                            ? relationship.allows(
                                    CoachPermission.assignTasks,
                                  )
                                ? 'Asignar tareas, revisar adherencia y comentarios.'
                                : 'El cliente no concedió permiso para asignar tareas.'
                            : 'Completar tareas, revisar historial y activar recordatorios locales.',
                        enabled: !asCoach ||
                            relationship.allows(
                              CoachPermission.assignTasks,
                            ),
                        onTap: !asCoach ||
                                relationship.allows(
                                  CoachPermission.assignTasks,
                                )
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CoachTasksPage(
                                      clientUserId:
                                          relationship!.clientUserId,
                                      clientDisplayName: displayName,
                                      canAssign: asCoach &&
                                          relationship.allows(
                                            CoachPermission.assignTasks,
                                          ),
                                      canComment: !asCoach ||
                                          relationship.allows(
                                            CoachPermission.comment,
                                          ),
                                    ),
                                  ),
                                )
                            : null,
                      ),
                      const Divider(height: 1),
                      _CapabilityTile(
                        icon: Icons.restaurant_menu_outlined,
                        title: 'Orientación alimentaria',
                        subtitle: relationship.allows(
                                CoachPermission.viewNutrition)
                            ? (asCoach
                                ? 'Crear guías no clínicas versionadas y revisar historial.'
                                : 'Revisar la guía compartida y sus versiones.')
                            : 'Sin permiso para compartir alimentación.',
                        enabled: relationship.allows(
                          CoachPermission.viewNutrition,
                        ),
                        onTap: relationship.allows(
                                CoachPermission.viewNutrition)
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CoachNutritionGuidancePage(
                                      clientUserId:
                                          relationship!.clientUserId,
                                      clientDisplayName: displayName,
                                      canEdit: asCoach,
                                    ),
                                  ),
                                )
                            : null,
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
  final VoidCallback? onTap;

  const _CapabilityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.onTap,
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
      onTap: enabled ? onTap : null,
    );
  }
}

String _permissionLabel(CoachPermission permission) => switch (permission) {
      CoachPermission.viewWorkouts => 'Ver entrenamientos',
      CoachPermission.viewProgress => 'Ver progreso',
      CoachPermission.viewMeasurements => 'Ver medidas',
      CoachPermission.assignPrograms => 'Asignar programas',
      CoachPermission.assignTasks => 'Asignar tareas',
      CoachPermission.viewCheckins => 'Ver check-ins',
      CoachPermission.viewNutrition => 'Ver alimentación',
      CoachPermission.comment => 'Comentar',
    };

String _statusLabel(CoachRelationshipStatus status) => switch (status) {
      CoachRelationshipStatus.active => 'Activa',
      CoachRelationshipStatus.paused => 'Pausada',
      CoachRelationshipStatus.revoked => 'Revocada',
    };
