import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/faith/data/bible_database.dart';
import 'package:core/features/faith/data/bible_repository.dart';
import 'package:core/features/faith/data/contextual_passage_catalog.dart';
import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/domain/models/verse.dart';
import 'package:shared_preferences/shared_preferences.dart';

final bibleRepositoryProvider = Provider<BibleRepository>((ref) {
  return BibleRepository(BibleDatabase.instance);
});

class DailyVerseState {
  final Verse? verse;
  final String mood;
  final bool isLoading;

  DailyVerseState({this.verse, this.mood = 'General', this.isLoading = true});

  DailyVerseState copyWith({Verse? verse, String? mood, bool? isLoading}) {
    return DailyVerseState(
      verse: verse ?? this.verse,
      mood: mood ?? this.mood,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DailyVerseNotifier extends AsyncNotifier<DailyVerseState> {
  @override
  Future<DailyVerseState> build() async {
    // Read SharedPreferences FIRST, regardless of whether SQLite is ready.
    // This makes an existing verse visible immediately after the splash.
    final init = ref.watch(bibleInitProvider);
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString('saved_verse');
    final reference = prefs.getString('saved_reference');
    final mood = prefs.getString('current_mood') ?? 'General';
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final fresh = prefs.getString('daily_verse_date') == todayStr &&
        prefs.getInt('daily_passage_version') == 2;

    Verse? cached;
    if (fresh && text != null && text.trim().isNotEmpty &&
        reference != null && reference.trim().isNotEmpty) {
      try {
        final split = reference.lastIndexOf(' ');
        if (split > 0) {
          final location = reference.substring(split + 1).split(':');
          final range = location[1].split('-');
          cached = Verse(
            book: reference.substring(0, split),
            chapter: int.parse(location[0]),
            verse: int.parse(range[0]),
            endVerse: range.length > 1 ? int.parse(range[1]) : null,
            text: text,
            explanation: prefs.getString('daily_passage_explanation'),
            reflectionQuestion: prefs.getString('daily_passage_question'),
          );
        }
      } catch (_) {
        // Corrupt cached reference: fetch a fresh verse if Bible is ready.
      }
    }
    if (fresh && cached != null) {
      return DailyVerseState(verse: cached, mood: mood, isLoading: false);
    }
    if (!init.isReady) {
      // Yesterday's verse is preferable to a blank dashboard while updating.
      return DailyVerseState(
        verse: cached, mood: mood, isLoading: cached == null,
      );
    }

    final current = await ContextualPassageCatalog.daily(
        ref.read(bibleRepositoryProvider), today);
    if (current != null) {
      await prefs.setString('saved_verse', current.text);
      await prefs.setString('saved_reference', current.reference);
      await prefs.setString('daily_passage_explanation', current.explanation ?? '');
      await prefs.setString('daily_passage_question', current.reflectionQuestion ?? '');
      await prefs.setInt('daily_passage_version', 2);
      await prefs.setString('daily_verse_date', todayStr);
    }
    return DailyVerseState(
      verse: current ?? cached, mood: mood, isLoading: false,
    );
  }

  /// Actualiza la selección visible sin reemplazar el mensaje fijo de hoy.
  /// La página de Reflexión observa moodPassageProvider para cargar la
  /// lectura adecuada; Inicio sigue leyendo exclusivamente state.verse.
  Future<void> changeMood(String newMood) async {
    if (!ContextualPassageCatalog.moodOptions.contains(newMood)) return;
    final previous = state.value ?? DailyVerseState(isLoading: false);
    state = AsyncValue.data(previous.copyWith(mood: newMood));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_mood', newMood);
  }

}

final dailyVerseProvider = AsyncNotifierProvider<DailyVerseNotifier, DailyVerseState>(DailyVerseNotifier.new);

/// Reflexión temática independiente del versículo diario compartido con
/// Inicio, widget y notificaciones. Se resuelve solo cuando se visita la
/// página de Reflexión diaria y se selecciona un estado distinto de General.
final moodPassageProvider = FutureProvider.autoDispose.family<Verse?, String>(
  (ref, mood) async {
    if (mood == 'General' ||
        !ContextualPassageCatalog.moodOptions.contains(mood)) {
      return null;
    }
    final init = ref.watch(bibleInitProvider);
    final dailyVerse = ref.watch(dailyVerseProvider).value?.verse;
    if (!init.isReady) return null;
    return ContextualPassageCatalog.mood(
      ref.read(bibleRepositoryProvider),
      mood: mood,
      day: DateTime.now(),
      dailyVerse: dailyVerse,
    );
  },
);

final randomVerseProvider = FutureProvider.autoDispose<Verse?>((ref) async {
  // Ensure DB is initialized
  final initState = ref.watch(bibleInitProvider);
  if (!initState.isReady) {
    return null;
  }
  
  final repo = ref.read(bibleRepositoryProvider);
  // Get user's current mood to give a tailored message
  final prefs = await SharedPreferences.getInstance();
  final savedMood = prefs.getString('current_mood') ?? 'General';
  
  return repo.getRandomVerse(mood: savedMood);
});
