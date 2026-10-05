import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_task_templates.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:core/features/habits/presentation/pages/study_habits_page.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/personal_reading_library.dart';
import 'personal_pdf_reader_page.dart';
import 'recovery_pause_page.dart';
import 'wind_down_page.dart';

class StudyHabitsMobilePage extends ConsumerStatefulWidget {
  const StudyHabitsMobilePage({super.key});

  @override
  ConsumerState<StudyHabitsMobilePage> createState() =>
      _StudyHabitsMobilePageState();
}

class _StudyHabitsMobilePageState extends ConsumerState<StudyHabitsMobilePage> {
  final PersonalReadingLibraryRepository _library =
      PersonalReadingLibraryRepository();
  List<PersonalReadingDocument> _documents = const [];
  bool _loadingLibrary = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _reloadLibrary();
  }

  Future<void> _reloadLibrary() async {
    final items = await _library.load();
    if (!mounted) return;
    setState(() {
      _documents = items;
      _loadingLibrary = false;
    });
  }

  Future<void> _importPdf() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final document = await _library.importPdf();
      await _reloadLibrary();
      if (document != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PersonalPdfReaderPage(
              document: document,
              repository: _library,
            ),
          ),
        );
        await _reloadLibrary();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo importar el PDF: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openDocument(PersonalReadingDocument document) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PersonalPdfReaderPage(
          document: document,
          repository: _library,
        ),
      ),
    );
    await _reloadLibrary();
  }

  Future<void> _deleteDocument(PersonalReadingDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar libro'),
        content: Text(
          'Se eliminará "${document.title}" de este iPhone. '
          'El archivo no se sube a la nube.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _library.remove(document);
    await _reloadLibrary();
  }

  Future<void> _activateReminder(
    HabitTaskTemplate template, {
    required int hour,
    required int minute,
  }) async {
    final notifier = ref.read(habitTasksProvider.notifier);
    final state = ref.read(habitTasksProvider);
    HabitTask? task;
    for (final item in state.tasks) {
      if (!item.archived && item.title == template.title) {
        task = item;
        break;
      }
    }
    final resolvedTask =
        task ?? await notifier.createFromTemplate(template);
    final now = DateTime.now();
    final scheduledAt = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    final ok = await notifier.setReminder(
      taskId: resolvedTask.id,
      enabled: true,
      scheduledAt: scheduledAt,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Recordatorio activado a las '
                  '${hour.toString().padLeft(2, '0')}:'
                  '${minute.toString().padLeft(2, '0')}.'
              : 'No se pudo activar el recordatorio. Revisa permisos de notificaciones.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(habitTasksProvider);
    final dueToday = ref.watch(dueHabitTasksTodayProvider);
    final faithEnabled = ref.watch(
      userExperienceProfileProvider.select(
        (profile) => profile.value?.faithEnabled ?? false,
      ),
    );

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final readingTaskIds = taskState.tasks
        .where(
          (task) =>
              task.type == HabitTaskType.readingTimer ||
              task.type == HabitTaskType.studySession,
        )
        .map((task) => task.id)
        .toSet();
    final readingMinutesWeek = taskState.completions
        .where(
          (completion) =>
              completion.status == HabitTaskCompletionStatus.completed &&
              !completion.completedAt.isBefore(sevenDaysAgo) &&
              readingTaskIds.contains(completion.taskId),
        )
        .fold<int>(
          0,
          (sum, completion) => sum + completion.minutesSpent,
        );
    final completedToday = taskState.completions.where((completion) {
      final date = completion.completedAt;
      return completion.status == HabitTaskCompletionStatus.completed &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Hábitos & Lectura')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          children: [
            _Overview(
              pending: dueToday.length,
              completed: completedToday,
              readingMinutes: readingMinutesWeek,
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Mi biblioteca',
              subtitle:
                  'Tus PDFs se guardan solo en este dispositivo. STK Haven recuerda tu página y te sugiere un ritmo.',
              trailing: FilledButton.icon(
                onPressed: _importing ? null : _importPdf,
                icon: const Icon(Icons.upload_file),
                label: Text(_importing ? 'Importando…' : 'Subir PDF'),
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingLibrary)
              const Center(child: CircularProgressIndicator())
            else if (_documents.isEmpty)
              const _InfoCard(
                icon: Icons.library_books_outlined,
                title: 'Tu biblioteca está vacía',
                body:
                    'Importa un libro en PDF desde Archivos. No se envía a Supabase.',
              )
            else
              ..._documents.take(5).map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BookCard(
                        document: document,
                        onOpen: () => _openDocument(document),
                        onDelete: () => _deleteDocument(document),
                      ),
                    ),
                  ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _activateReminder(
                HabitTaskTemplates.personalReading20Minutes,
                hour: 20,
                minute: 30,
              ),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Recordarme leer · 20:30'),
            ),
            if (faithEnabled) ...[
              const SizedBox(height: 28),
              const _SectionHeader(
                title: 'Biblia más fácil de entender',
                subtitle:
                    'La app mantiene Reina-Valera 1909 porque es de dominio público. Las versiones modernas requieren licencia.',
              ),
              const SizedBox(height: 12),
              const _InfoCard(
                icon: Icons.menu_book_outlined,
                title: 'Opciones futuras',
                body:
                    'NTV: muy clara y natural. TLA: lenguaje muy sencillo. '
                    'NVI: clara pero más cercana a una traducción de estudio. '
                    'No incluiremos su texto sin autorización del titular.',
              ),
            ],
            const SizedBox(height: 28),
            const _SectionHeader(
              title: 'Dormir con la mente más tranquila',
              subtitle:
                  'Respiración 4/6, descarga mental y cierre del día en 10 minutos.',
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.bedtime_outlined,
              title: 'Rutina nocturna',
              subtitle: 'Baja revoluciones antes de acostarte.',
              primaryLabel: 'Empezar',
              onPrimary: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WindDownPage(),
                ),
              ),
              secondaryLabel: 'Recordarme 22:30',
              onSecondary: () => _activateReminder(
                HabitTaskTemplates.windDown10Minutes,
                hour: 22,
                minute: 30,
              ),
            ),
            const SizedBox(height: 28),
            const _SectionHeader(
              title: 'Recuperación',
              subtitle:
                  'Un espacio privado para atravesar impulsos, registrar disparadores y elegir una acción segura.',
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.shield_outlined,
              title: 'Pausa de recuperación',
              subtitle:
                  'Respira, mide la intensidad y retrasa la decisión automática.',
              primaryLabel: 'Abrir pausa',
              onPrimary: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RecoveryPausePage(),
                ),
              ),
              secondaryLabel: 'Check-in 19:00',
              onSecondary: () => _activateReminder(
                HabitTaskTemplates.recoveryPause,
                hour: 19,
                minute: 0,
              ),
            ),
            const SizedBox(height: 28),
            const _SectionHeader(
              title: 'Planes y tareas',
              subtitle:
                  'Tus planes de estudio, tareas diarias, rachas, recordatorios e historial siguen disponibles.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StudyHabitsPage(),
                ),
              ),
              icon: const Icon(Icons.task_alt_outlined),
              label: const Text('Abrir planes y tareas'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final int pending;
  final int completed;
  final int readingMinutes;

  const _Overview({
    required this.pending,
    required this.completed,
    required this.readingMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _Metric(value: '$pending', label: 'Pendientes')),
            Expanded(child: _Metric(value: '$completed', label: 'Hoy')),
            Expanded(
              child: _Metric(
                value: '${readingMinutes}m',
                label: 'Lectura · 7 días',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 5),
        Text(subtitle),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(body),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final PersonalReadingDocument document;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _BookCard({
    required this.document,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (document.progress * 100).round();
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: document.totalPages <= 0
                          ? null
                          : document.progress,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      document.totalPages <= 0
                          ? 'Abrir para detectar páginas'
                          : 'Página ${document.currentPage} de '
                              '${document.totalPages} · $percent%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (document.suggestedPagesPerDay > 0)
                      Text(
                        'Ritmo sugerido: '
                        '${document.suggestedPagesPerDay} páginas/día',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Eliminar de este dispositivo',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onPrimary,
                    child: Text(primaryLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(
                      secondaryLabel,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
