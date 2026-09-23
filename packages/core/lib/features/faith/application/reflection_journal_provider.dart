import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/verse.dart';
import 'package:core/features/faith/data/reflection_journal_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final reflectionJournalRepositoryProvider = Provider<ReflectionJournalRepository>((ref) {
  return ReflectionJournalRepository(Hive.box(HiveBoxes.metadata));
});

final reflectionJournalProvider =
    NotifierProvider<ReflectionJournalNotifier, List<ReflectionJournalEntry>>(
  ReflectionJournalNotifier.new,
);

class ReflectionJournalNotifier extends Notifier<List<ReflectionJournalEntry>> {
  @override
  List<ReflectionJournalEntry> build() {
    return ref.read(reflectionJournalRepositoryProvider).getEntries();
  }

  Future<void> saveVerse(Verse verse, String mood) async {
    state = await ref
        .read(reflectionJournalRepositoryProvider)
        .saveVerse(verse: verse, mood: mood);
  }

  Future<void> updateNote(String id, String note) async {
    state = await ref
        .read(reflectionJournalRepositoryProvider)
        .updateNote(id, note);
  }

  Future<void> delete(String id) async {
    state = await ref.read(reflectionJournalRepositoryProvider).delete(id);
  }
}

class FaithQuickAction {
  final String label;
  final String prompt;

  const FaithQuickAction(this.label, this.prompt);
}

const havenFaithQuickActions = <FaithQuickAction>[
  FaithQuickAction(
    'Reflexionar',
    'Ayúdame a reflexionar con calma sobre mi día desde una perspectiva de fe y con preguntas breves.',
  ),
  FaithQuickAction(
    'Gratitud',
    'Guíame en una breve reflexión de gratitud por las cosas buenas de hoy.',
  ),
  FaithQuickAction(
    'Ánimo',
    'Compárteme un mensaje breve de ánimo basado en valores de fe, esperanza y perseverancia.',
  ),
  FaithQuickAction(
    'Oración',
    'Ayúdame a redactar una oración breve y sencilla para este momento.',
  ),
];
