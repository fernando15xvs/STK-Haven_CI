import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class PersonalReadingDocument {
  final String id;
  final String title;
  final String originalFileName;
  final String localPath;
  final DateTime importedAt;
  final DateTime? lastReadAt;
  final int currentPage;
  final int totalPages;

  const PersonalReadingDocument({
    required this.id,
    required this.title,
    required this.originalFileName,
    required this.localPath,
    required this.importedAt,
    this.lastReadAt,
    this.currentPage = 1,
    this.totalPages = 0,
  });

  double get progress {
    if (totalPages <= 0) return 0;
    return (currentPage / totalPages).clamp(0.0, 1.0).toDouble();
  }

  int get suggestedPagesPerDay {
    if (totalPages <= 0) return 0;
    final remaining = (totalPages - currentPage).clamp(0, totalPages);
    if (remaining == 0) return 0;
    return (remaining / 14).ceil();
  }

  PersonalReadingDocument copyWith({
    String? title,
    DateTime? lastReadAt,
    int? currentPage,
    int? totalPages,
  }) {
    return PersonalReadingDocument(
      id: id,
      title: title ?? this.title,
      originalFileName: originalFileName,
      localPath: localPath,
      importedAt: importedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'originalFileName': originalFileName,
        'localPath': localPath,
        'importedAt': importedAt.toIso8601String(),
        'lastReadAt': lastReadAt?.toIso8601String(),
        'currentPage': currentPage,
        'totalPages': totalPages,
      };

  factory PersonalReadingDocument.fromJson(Map<String, dynamic> json) {
    final currentPage = (json['currentPage'] as num?)?.toInt() ?? 1;
    final totalPages = (json['totalPages'] as num?)?.toInt() ?? 0;
    return PersonalReadingDocument(
      id: '${json['id'] ?? ''}'.trim(),
      title: '${json['title'] ?? ''}'.trim(),
      originalFileName: '${json['originalFileName'] ?? ''}'.trim(),
      localPath: '${json['localPath'] ?? ''}'.trim(),
      importedAt:
          DateTime.tryParse('${json['importedAt']}') ?? DateTime.now(),
      lastReadAt: json['lastReadAt'] == null
          ? null
          : DateTime.tryParse('${json['lastReadAt']}'),
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 0 ? 0 : totalPages,
    );
  }
}

class PersonalReadingLibraryRepository {
  static const String _storageKey = 'personal_reading_library_v1';
  static const Uuid _uuid = Uuid();

  Future<List<PersonalReadingDocument>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <PersonalReadingDocument>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <PersonalReadingDocument>[];
      final items = decoded
          .whereType<Map>()
          .map(
            (item) => PersonalReadingDocument.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where(
            (item) =>
                item.id.isNotEmpty &&
                item.title.isNotEmpty &&
                item.localPath.isNotEmpty,
          )
          .toList(growable: false);
      items.sort((a, b) {
        final aDate = a.lastReadAt ?? a.importedAt;
        final bDate = b.lastReadAt ?? b.importedAt;
        return bDate.compareTo(aDate);
      });
      return items;
    } catch (_) {
      return const <PersonalReadingDocument>[];
    }
  }

  Future<PersonalReadingDocument?> importPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
    );
    if (result.isEmpty) return null;

    final picked = result.first;
    final sourcePath = picked.path;
    if (sourcePath == null || sourcePath.trim().isEmpty) return null;

    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'reading_library'));
    await directory.create(recursive: true);

    final id = _uuid.v4();
    final destination = p.join(directory.path, '$id.pdf');
    await File(sourcePath).copy(destination);

    final originalName = picked.name.trim().isEmpty
        ? p.basename(sourcePath)
        : picked.name.trim();
    final title = _titleFromFileName(originalName);
    final document = PersonalReadingDocument(
      id: id,
      title: title,
      originalFileName: originalName,
      localPath: destination,
      importedAt: DateTime.now(),
    );

    final items = await load();
    await _save(<PersonalReadingDocument>[document, ...items]);
    return document;
  }

  Future<void> updateProgress(
    PersonalReadingDocument document, {
    required int currentPage,
    int? totalPages,
  }) async {
    final items = await load();
    final index = items.indexWhere((item) => item.id == document.id);
    if (index < 0) return;

    final safeTotal = totalPages ?? items[index].totalPages;
    final maxPage = safeTotal > 0 ? safeTotal : 1000000;
    final safePage = currentPage.clamp(1, maxPage).toInt();
    items[index] = items[index].copyWith(
      currentPage: safePage,
      totalPages: safeTotal,
      lastReadAt: DateTime.now(),
    );
    await _save(items);
  }

  Future<void> rename(String id, String title) async {
    final normalized = title.trim();
    if (normalized.isEmpty) return;
    final items = await load();
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    items[index] = items[index].copyWith(title: normalized);
    await _save(items);
  }

  Future<void> remove(PersonalReadingDocument document) async {
    final items = await load()
      ..removeWhere((item) => item.id == document.id);
    await _save(items);
    try {
      final file = File(document.localPath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Metadata removal should still succeed if the local file vanished.
    }
  }

  Future<void> _save(List<PersonalReadingDocument> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  static String _titleFromFileName(String fileName) {
    final withoutExtension = p.basenameWithoutExtension(fileName);
    final spaced = withoutExtension.replaceAll(RegExp(r'[_-]+'), ' ');
    final normalized = spaced.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return 'Libro importado';
    return normalized
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          if (word.length <= 3 && word == word.toUpperCase()) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }
}
