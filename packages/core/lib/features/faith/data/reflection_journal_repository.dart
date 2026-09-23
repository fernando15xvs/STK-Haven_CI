import 'package:core/domain/models/verse.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ReflectionJournalEntry {
  final String id;
  final DateTime createdAt;
  final String mood;
  final String verseReference;
  final String verseText;
  final String note;

  const ReflectionJournalEntry({
    required this.id,
    required this.createdAt,
    required this.mood,
    required this.verseReference,
    required this.verseText,
    this.note = '',
  });

  ReflectionJournalEntry copyWith({String? note}) => ReflectionJournalEntry(
        id: id,
        createdAt: createdAt,
        mood: mood,
        verseReference: verseReference,
        verseText: verseText,
        note: note ?? this.note,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'mood': mood,
        'verseReference': verseReference,
        'verseText': verseText,
        'note': note,
      };

  static ReflectionJournalEntry? fromMap(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final id = map['id']?.toString().trim() ?? '';
    final reference = map['verseReference']?.toString().trim() ?? '';
    final text = map['verseText']?.toString().trim() ?? '';
    final createdAt = DateTime.tryParse(map['createdAt']?.toString() ?? '');
    if (id.isEmpty || reference.isEmpty || text.isEmpty || createdAt == null) {
      return null;
    }
    return ReflectionJournalEntry(
      id: id,
      createdAt: createdAt,
      mood: map['mood']?.toString().trim().isNotEmpty == true
          ? map['mood'].toString().trim()
          : 'General',
      verseReference: reference,
      verseText: text,
      note: map['note']?.toString().trim() ?? '',
    );
  }
}

class ReflectionJournalRepository {
  static const storageKey = 'faith_reflection_journal_v1';
  static const maxEntries = 180;

  final Box<dynamic> _box;

  ReflectionJournalRepository(this._box);

  List<ReflectionJournalEntry> getEntries() {
    final raw = _box.get(storageKey);
    if (raw is! List) return const [];
    final entries = raw
        .map(ReflectionJournalEntry.fromMap)
        .whereType<ReflectionJournalEntry>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final deduped = <String, ReflectionJournalEntry>{};
    for (final entry in entries) {
      deduped.putIfAbsent(entry.id, () => entry);
    }
    return List.unmodifiable(deduped.values.take(maxEntries));
  }

  Future<List<ReflectionJournalEntry>> saveVerse({
    required Verse verse,
    required String mood,
    DateTime? createdAt,
  }) async {
    final timestamp = createdAt ?? DateTime.now();
    final id = '${timestamp.toIso8601String()}_${verse.id}';
    final next = [
      ReflectionJournalEntry(
        id: id,
        createdAt: timestamp,
        mood: mood.trim().isEmpty ? 'General' : mood.trim(),
        verseReference: verse.reference,
        verseText: verse.text.trim(),
      ),
      ...getEntries(),
    ].take(maxEntries).toList(growable: false);
    await _write(next);
    return List.unmodifiable(next);
  }

  Future<List<ReflectionJournalEntry>> updateNote(String id, String note) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return getEntries();
    final normalizedNote = note.trim();
    final next = getEntries()
        .map((entry) => entry.id == normalizedId
            ? entry.copyWith(note: normalizedNote)
            : entry)
        .toList(growable: false);
    await _write(next);
    return List.unmodifiable(next);
  }

  Future<List<ReflectionJournalEntry>> delete(String id) async {
    final normalizedId = id.trim();
    final next = getEntries()
        .where((entry) => entry.id != normalizedId)
        .toList(growable: false);
    await _write(next);
    return List.unmodifiable(next);
  }

  Future<void> _write(List<ReflectionJournalEntry> entries) async {
    await _box.put(
      storageKey,
      entries.map((entry) => entry.toMap()).toList(growable: false),
    );
  }
}
