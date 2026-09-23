import 'package:core/features/faith/application/reflection_journal_provider.dart';
import 'package:core/features/faith/data/reflection_journal_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class ReflectionHistoryPage extends ConsumerStatefulWidget {
  const ReflectionHistoryPage({super.key});

  @override
  ConsumerState<ReflectionHistoryPage> createState() =>
      _ReflectionHistoryPageState();
}

class _ReflectionHistoryPageState extends ConsumerState<ReflectionHistoryPage> {
  final TextEditingController _search = TextEditingController();
  String? _mood;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(reflectionJournalProvider);
    final moods = entries.map((entry) => entry.mood).toSet().toList()..sort();
    final query = _search.text.trim().toLowerCase();
    final filtered = entries.where((entry) {
      if (_mood != null && entry.mood != _mood) return false;
      if (query.isEmpty) return true;
      return entry.verseText.toLowerCase().contains(query) ||
          entry.verseReference.toLowerCase().contains(query) ||
          entry.note.toLowerCase().contains(query) ||
          entry.mood.toLowerCase().contains(query);
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reflexiones')),
      body: entries.isEmpty
          ? const _EmptyState()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar texto, cita o nota',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                if (moods.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        ChoiceChip(
                          label: const Text('Todas'),
                          selected: _mood == null,
                          onSelected: (_) => setState(() => _mood = null),
                        ),
                        const SizedBox(width: 8),
                        ...moods.expand(
                          (mood) => [
                            ChoiceChip(
                              label: Text(mood),
                              selected: _mood == mood,
                              onSelected: (_) => setState(() => _mood = mood),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              'No hay reflexiones que coincidan con estos filtros.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: AppSpacing.pagePadding,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _ReflectionCard(entry: filtered[index]),
                        ),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_stories_outlined,
              size: 52,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              'Todavía no guardaste reflexiones.',
              style: AppTypography.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Desde Reflexión diaria puedes guardar un mensaje y añadirle una nota personal. El historial se conserva localmente para poder consultarlo sin conexión.',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReflectionCard extends ConsumerWidget {
  final ReflectionJournalEntry entry;
  const _ReflectionCard({required this.entry});

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: entry.note);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nota personal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: '¿Qué quieres recordar de esta reflexión?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      await ref
          .read(reflectionJournalProvider.notifier)
          .updateNote(entry.id, value);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reflexión'),
        content: const Text(
          'Se eliminará también la nota personal asociada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(reflectionJournalProvider.notifier).delete(entry.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryFaded,
                  borderRadius: AppRadius.sm_,
                ),
                child: Text(
                  entry.mood,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('dd MMM yyyy', 'es').format(entry.createdAt),
                style: AppTypography.bodySmall,
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'note') _editNote(context, ref);
                  if (value == 'delete') _delete(context, ref);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'note', child: Text('Editar nota')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '“${entry.verseText}”',
            style: AppTypography.bodyLarge.copyWith(height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            entry.verseReference,
            style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
          ),
          if (entry.note.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: AppRadius.md_,
              ),
              child: Text(entry.note, style: AppTypography.bodyMedium),
            ),
          ],
        ],
      ),
    );
  }
}
