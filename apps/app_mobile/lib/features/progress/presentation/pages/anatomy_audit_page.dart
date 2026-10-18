import 'package:core/features/exercises/application/exercise_anatomy_audit.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/sync/presentation/backup_status_page.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// On-device diagnosis over the CURRENT providers, including historical
/// snapshots. It deliberately never modifies Hive, routines or PR records.
class AnatomyAuditPage extends ConsumerWidget {
  const AnatomyAuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(exerciseListProvider);
    final routines = ref.watch(routineListProvider);
    final history = ref.watch(workoutHistoryProvider);
    final audit = ExerciseAnatomyAudit.inspect(
      catalog: catalog,
      routines: routines,
      history: history,
    );
    final unresolved = audit.findings
        .where((finding) => finding.isUnresolved).toList(growable: false);
    final general = audit.findings
        .where((finding) => !finding.isUnresolved).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Revisión anatómica')),
      body: ListView(
        key: const ValueKey('anatomy_audit_list'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('Diagnóstico de este dispositivo',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          const Text(
            'Se revisan los ejercicios, rutinas y entrenamientos que la app '
            'tiene cargados en este dispositivo. Es una lectura, no una '
            'migración: los nombres, pesos, series, récords y fechas '
            'originales permanecen intactos.',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _Count(label: 'Ejercicios del catálogo',
                      value: audit.catalogExercises),
                  _Count(label: 'Referencias en rutinas',
                      value: audit.routineReferences),
                  _Count(label: 'Ejercicios registrados',
                      value: audit.historicalExercises),
                  _Count(label: 'Etiquetas sin asignar',
                      value: audit.unresolvedOccurrences),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!audit.hasFindings)
            const ListTile(
              key: ValueKey('audit_no_findings'),
              leading: Icon(Icons.check_circle_outline),
              title: Text('Sin observaciones anatómicas'),
              subtitle: Text(
                'Esta lectura no sustituye la revisión de técnica ni '
                'comprueba que exista una copia de seguridad.',
              ),
            ),
          _AuditSection(
            key: const ValueKey('audit_unresolved_section'),
            title: 'Etiquetas por clasificar',
            description: 'No se puede determinar un músculo concreto con '
                'seguridad. No se repartirán las series automáticamente.',
            findings: unresolved,
          ),
          _AuditSection(
            key: const ValueKey('audit_general_section'),
            title: 'Etiquetas generales',
            description: 'Son válidas para estadísticas de grupos, pero no '
                'indican una porción muscular específica.',
            findings: general,
          ),
          if (audit.missingRoutineExerciseIds.isNotEmpty ||
              audit.missingHistoricalExerciseIds.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('Referencias a ejercicios no disponibles',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Rutinas: ${audit.missingRoutineExerciseIds.length} '
                '· Historial: ${audit.missingHistoricalExerciseIds.length}'),
            const Text(
              'Una referencia antigua no significa que se haya perdido '
              'un entrenamiento. No se cambiarán sus identificadores.',
            ),
          ],
          const Divider(height: 28),
          const Text('Antes de cualquier cambio permanente',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Crea una copia local desde Datos y sincronización y verifica '
            'que el archivo quede guardado fuera de la app. '
            'No restaures ninguna copia para realizar esta auditoría: '
            'restaurar reemplaza datos locales. '
            'Esta pantalla no verifica una restauración ni habilita '
            'una migración automática.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('anatomy_audit_backups'),
            icon: const Icon(Icons.save_alt),
            label: const Text('Ir a Datos y sincronización'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BackupStatusPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value',
              style: Theme.of(context).textTheme.titleMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _AuditSection extends StatelessWidget {
  const _AuditSection({
    super.key,
    required this.title,
    required this.description,
    required this.findings,
  });

  final String title;
  final String description;
  final List<AnatomyAuditFinding> findings;

  String _source(AnatomyAuditSource source) => switch (source) {
        AnatomyAuditSource.catalogPrimary => 'Músculo principal del catálogo',
        AnatomyAuditSource.catalogSecondary => 'Secundario del catálogo',
        AnatomyAuditSource.historySnapshot => 'Etiqueta del historial',
      };

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      initiallyExpanded: findings.first.isUnresolved,
      title: Text(title),
      subtitle: Text('${findings.length} etiquetas distintas. $description'),
      children: [
        for (final finding in findings)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(finding.originalLabel),
            subtitle: Text(_source(finding.source)),
            trailing: Text('${finding.occurrences}×'),
          ),
      ],
    );
  }
}
