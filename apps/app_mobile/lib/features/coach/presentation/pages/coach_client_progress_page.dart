import 'package:core/domain/models/coach_client_progress.dart';
import 'package:core/features/coach/application/coach_progress_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachClientProgressPage extends ConsumerStatefulWidget {
  final String clientUserId;
  final String clientDisplayName;

  const CoachClientProgressPage({
    super.key,
    required this.clientUserId,
    required this.clientDisplayName,
  });

  @override
  ConsumerState<CoachClientProgressPage> createState() =>
      _CoachClientProgressPageState();
}

class _CoachClientProgressPageState
    extends ConsumerState<CoachClientProgressPage> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    final identity = ref.read(appIdentityProvider);
    if (identity.userId == widget.clientUserId) {
      await ref.read(coachProgressProvider.notifier).syncOwnProgress(
            ref.read(workoutHistoryProvider),
            silent: true,
          );
    }
    if (!mounted) return;
    await ref
        .read(coachProgressProvider.notifier)
        .loadClientProgress(widget.clientUserId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coachProgressProvider);
    final progress = state.byClientId[widget.clientUserId];
    final loading =
        state.operation == CoachProgressOperation.loadingClient;

    return Scaffold(
      appBar: AppBar(
        title: Text('Progreso · ${widget.clientDisplayName}'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Builder(
              builder: (context) {
                if (loading && progress == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.isError && progress == null) {
                  return _ErrorState(
                    message:
                        state.message ?? 'No se pudo cargar el progreso.',
                    onRetry: () => ref
                        .read(coachProgressProvider.notifier)
                        .loadClientProgress(widget.clientUserId),
                  );
                }

                if (progress == null || !progress.available) {
                  return const _EmptyState();
                }

                return _ProgressBody(progress: progress);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  final CoachClientProgress progress;

  const _ProgressBody({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              label: 'Entrenos 7 días',
              value: '${progress.workouts7d}',
              icon: Icons.fitness_center_outlined,
            ),
            _MetricCard(
              label: 'Entrenos 30 días',
              value: '${progress.workouts30d}',
              icon: Icons.calendar_month_outlined,
            ),
            _MetricCard(
              label: 'Minutos 7 días',
              value: '${progress.trainingMinutes7d}',
              icon: Icons.timer_outlined,
            ),
            _MetricCard(
              label: 'Series 7 días',
              value: '${progress.completedWorkingSets7d}',
              icon: Icons.repeat_rounded,
            ),
            _MetricCard(
              label: 'Volumen 7 días',
              value: _formatNumber(progress.volume7d),
              icon: Icons.insights_outlined,
            ),
            _MetricCard(
              label: 'RIR medio',
              value: progress.averageRir7d == null
                  ? '—'
                  : progress.averageRir7d!.toStringAsFixed(1),
              icon: Icons.speed_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _OperationalInsightCard(progress: progress),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.compare_arrows_rounded),
            title: const Text('Comparación de periodos'),
            subtitle: Text(
              'Últimos 7 días: ${progress.workouts7d} entrenos · '
              'Promedio semanal de 30 días: '
              '${(progress.workouts30d / (30 / 7)).toStringAsFixed(1)}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.ios_share_outlined),
            title: const Text('Exportar resumen'),
            subtitle: const Text('Copia un resumen legible, sin notas privadas ni detalle de series.'),
            trailing: const Icon(Icons.copy_rounded),
            onTap: () async {
              final text = _exportSummary(progress);
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Resumen copiado.')),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Último entrenamiento'),
            subtitle: Text(
              progress.lastWorkoutAt == null
                  ? 'Sin datos'
                  : _formatDateTime(progress.lastWorkoutAt!),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Entrenamientos recientes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          progress.workoutsVisible
              ? 'Resúmenes visibles por permiso “Ver entrenamientos”.'
              : 'El cliente comparte métricas globales, pero no sus entrenamientos individuales.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (!progress.workoutsVisible)
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Entrenamientos no compartidos'),
              subtitle: Text(
                'El permiso de progreso no concede automáticamente acceso '
                'a cada sesión.',
              ),
            ),
          )
        else if (progress.recentWorkouts.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.history_rounded),
              title: Text('Sin entrenamientos recientes'),
            ),
          )
        else
          for (final workout in progress.recentWorkouts) ...[
            _WorkoutCard(workout: workout),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 16),
        Text(
          'Este módulo comparte únicamente métricas de entrenamiento. '
          'No incluye notas privadas, nombres de ejercicios ni el detalle '
          'de cada serie.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  static String _formatNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

class _OperationalInsightCard extends StatelessWidget {
  final CoachClientProgress progress;
  const _OperationalInsightCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final last = progress.lastWorkoutAt;
    final days = last == null ? null : DateTime.now().difference(last.toLocal()).inDays;
    final needsAttention = last == null || days! >= 7;
    return Card(
      child: ListTile(
        leading: Icon(needsAttention ? Icons.notifications_active_outlined : Icons.check_circle_outline),
        title: Text(needsAttention ? 'Revisión operativa sugerida' : 'Actividad reciente'),
        subtitle: Text(
          last == null
              ? 'No hay entrenamiento reciente sincronizado. Revisa el plan o contacta al cliente.'
              : needsAttention
                  ? 'Han pasado $days días desde el último entrenamiento. Esta alerta es operativa, no médica.'
                  : 'El cliente registra actividad reciente; no hay alerta operativa por inactividad.',
        ),
      ),
    );
  }
}

String _exportSummary(CoachClientProgress p) {
  final last = p.lastWorkoutAt?.toLocal();
  final lastLabel = last == null
      ? 'Sin datos'
      : '${last.day.toString().padLeft(2, '0')}/${last.month.toString().padLeft(2, '0')}/${last.year}';
  return [
    'STK Haven · Resumen de progreso',
    'Entrenos 7 días: ${p.workouts7d}',
    'Entrenos 30 días: ${p.workouts30d}',
    'Minutos 7 días: ${p.trainingMinutes7d}',
    'Series 7 días: ${p.completedWorkingSets7d}',
    'Volumen 7 días: ${p.volume7d.toStringAsFixed(0)}',
    'RIR medio 7 días: ${p.averageRir7d?.toStringAsFixed(1) ?? '—'}',
    'Último entrenamiento: $lastLabel',
    'Generado: ${p.generatedAt.toLocal().toIso8601String()}',
  ].join('\n');
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final CoachSharedWorkoutSummary workout;

  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final local = workout.startedAt.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.fitness_center_outlined),
        title: Text(
          workout.routineName.trim().isEmpty
              ? 'Entrenamiento'
              : workout.routineName,
        ),
        subtitle: Text(
          [
            date,
            '${(workout.durationSeconds / 60).round()} min',
            '${workout.completedWorkingSets}/${workout.plannedWorkingSets} series',
            '${workout.completionPercent}%',
          ].join(' · '),
        ),
        trailing: workout.averageRir == null
            ? null
            : Text('RIR ${workout.averageRir!.toStringAsFixed(1)}'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined, size: 48),
            SizedBox(height: 12),
            Text(
              'Todavía no hay un resumen de progreso sincronizado.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
