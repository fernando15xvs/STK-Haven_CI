import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/faith/data/bible_database.dart';
import 'package:core/features/faith/data/bible_repository.dart';
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
    // Watch init state — rebuild automatically when DB becomes ready
    final initState = ref.watch(bibleInitProvider);
    if (!initState.isReady) {
      return DailyVerseState(isLoading: initState.status == BibleDbStatus.loading);
    }

    final prefs = await SharedPreferences.getInstance();
    final savedText = prefs.getString('saved_verse');
    final savedRef  = prefs.getString('saved_reference');
    final savedMood = prefs.getString('current_mood') ?? 'General';
    final savedDateStr = prefs.getString('daily_verse_date');
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    // If we have a verse cached AND it is from today, use it directly.
    final isFresh = savedDateStr == todayStr && savedText != null && savedRef != null;

    Verse? initialVerse;
    if (isFresh) {
      try {
        final parts = savedRef.split(' ');
        final verseParts = parts.last.split(':');
        initialVerse = Verse(
          book: parts.sublist(0, parts.length - 1).join(' '),
          chapter: int.tryParse(verseParts[0]) ?? 1,
          verse: int.tryParse(verseParts.length > 1 ? verseParts[1] : '1') ?? 1,
          text: savedText,
        );
      } catch (_) {
        // malformed cache — fall through to fetch
      }
    }

    if (initialVerse == null) {
      // Either first launch, or a new day — fetch a fresh verse.
      final repo = ref.read(bibleRepositoryProvider);
      initialVerse = await repo.getRandomVerse(mood: savedMood);
      if (initialVerse != null) {
        await prefs.setString('saved_verse', initialVerse.text);
        await prefs.setString('saved_reference', initialVerse.reference);
        await prefs.setString('daily_verse_date', todayStr);
      }
    }

    return DailyVerseState(verse: initialVerse, mood: savedMood, isLoading: false);
  }

  Future<void> changeMood(String newMood) async {
    state = const AsyncValue.loading();
    final repo = ref.read(bibleRepositoryProvider);
    final newVerse = await repo.getRandomVerse(mood: newMood);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    if (newVerse != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_verse', newVerse.text);
      await prefs.setString('saved_reference', newVerse.reference);
      await prefs.setString('current_mood', newMood);
      await prefs.setString('daily_verse_date', todayStr);

      state = AsyncValue.data(DailyVerseState(verse: newVerse, mood: newMood, isLoading: false));
    } else {
      final s = state.value ?? DailyVerseState(isLoading: false);
      state = AsyncValue.data(s.copyWith(isLoading: false));
    }
  }
}

final dailyVerseProvider = AsyncNotifierProvider<DailyVerseNotifier, DailyVerseState>(DailyVerseNotifier.new);

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
