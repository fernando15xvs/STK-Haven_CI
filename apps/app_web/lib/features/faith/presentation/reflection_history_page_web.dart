import 'package:core/features/faith/application/reflection_journal_provider.dart';
import 'package:core/features/faith/data/reflection_journal_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

class ReflectionHistoryPageWeb extends ConsumerStatefulWidget {
  const ReflectionHistoryPageWeb({super.key});

  @override
  ConsumerState<ReflectionHistoryPageWeb> createState() =>
      _ReflectionHistoryPageWebState();
}

class _ReflectionHistoryPageWebState
    extends ConsumerState<ReflectionHistoryPageWeb> {
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: entries.isEmpty
              ? const _EmptyState()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
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
                          const SizedBox(width: 12),
                          DropdownButton<String?>(
                            value: _mood,
                            hint: const Text('Estado'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos'),
                              ),
                              ...moods.map(
                                (mood) => DropdownMenuItem<String?>(
                                  value: mood,
                                  child: Text(mood),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(() => _mood = value),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No hay reflexiones que coincidan con estos filtros.',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 60),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) =>
                                  _ReflectionCard(entry: filtered[index]),
                            ),
                    ),
                  ],
                ),
        ),
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
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              'Todavía no guardaste reflexiones.',
              style: AppTypography.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Guarda una reflexión diaria para construir tu historial personal. El contenido guardado permanece disponible desde el almacenamiento local.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
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
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 7,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: '¿Qué quieres recordar de esta reflexión?',
            ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(label: Text(entry.mood)),
              const Spacer(),
              Text(
                DateFormat('dd MMM yyyy', 'es').format(entry.createdAt),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              IconButton(
                onPressed: () => _editNote(context, ref),
                icon: const Icon(Icons.edit_note_outlined),
                tooltip: 'Editar nota',
              ),
              IconButton(
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar',
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            '“${entry.verseText}”',
            style: AppTypography.bodyLarge.copyWith(height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            entry.verseReference,
            style: AppTypography.labelLarge.copyWith(color: AppColors.primary),
          ),
          if (entry.note.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
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
