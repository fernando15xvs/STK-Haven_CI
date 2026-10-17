import 'package:core/domain/models/verse.dart';
import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';
import 'package:core/features/faith/data/bible_database.dart';
import 'package:core/features/faith/data/bible_repository.dart';
import 'package:core/features/faith/data/contextual_passage_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No SQLite or internet dependency in the mood-selection tests.
class _FakeBibleRepository extends BibleRepository {
  _FakeBibleRepository() : super(BibleDatabase.instance);

  @override
  Future<List<String>> getBooks() async {
    return <String>{
      ...ContextualPassageCatalog.passages.map((p) => p.book),
      for (final mood in ContextualPassageCatalog.moodOptions)
        ...ContextualPassageCatalog.forMood(mood, DateTime(2026, 10, 17))
            .map((p) => p.book),
    }.toList();
  }

  @override
  Future<List<Verse>> getVerses(String book, int chapter) async => [
    for (var v = 1; v <= 155; v++)
      Verse(
        book: book,
        chapter: chapter,
        verse: v,
        text: 'Texto de prueba del versículo $v.',
      ),
  ];
}

class _ReadyBibleInit extends BibleInitNotifier {
  @override
  BibleInitState build() =>
      const BibleInitState(status: BibleDbStatus.ready);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('daily selection remains the same and every mood has a thematic pool',
      () {
    final day = DateTime(2026, 10, 17);
    final daily = ContextualPassageCatalog.forDay(day);
    expect(daily.key, ContextualPassageCatalog.forDay(
      day.add(const Duration(hours: 10))).key);
    expect(ContextualPassageCatalog.moodOptions, contains('Alegre'));
    for (final mood in ContextualPassageCatalog.moodOptions) {
      final pool = ContextualPassageCatalog.forMood(
        mood, day, avoidKey: daily.key,
      );
      if (mood == 'General') {
        expect(pool, isEmpty);
      } else {
        expect(pool.length, greaterThanOrEqualTo(2));
        expect(pool.first.key, isNot(daily.key));
        expect(pool.every((p) => p.meaning.isNotEmpty &&
            p.question.isNotEmpty), isTrue);
      }
    }
  });

  test('changing mood updates reflection but not Home daily verse or cache',
      () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      bibleInitProvider.overrideWith(_ReadyBibleInit.new),
      bibleRepositoryProvider.overrideWithValue(_FakeBibleRepository()),
    ]);
    addTearDown(container.dispose);

    final initial = await container.read(dailyVerseProvider.future);
    expect(initial.verse, isNotNull);
    final dailyId = initial.verse!.id;
    final prefs = await SharedPreferences.getInstance();
    final savedReference = prefs.getString('saved_reference');
    expect(savedReference, initial.verse!.reference);

    await container.read(dailyVerseProvider.notifier).changeMood('Enojado');
    expect(container.read(dailyVerseProvider).value!.mood, 'Enojado');
    expect(container.read(dailyVerseProvider).value!.verse!.id, dailyId);
    final angry = await container.read(moodPassageProvider('Enojado').future);
    expect(angry, isNotNull);
    expect(angry!.id, isNot(dailyId));
    expect(angry.explanation, isNotEmpty);
    expect(prefs.getString('saved_reference'), savedReference);

    await container.read(dailyVerseProvider.notifier).changeMood('Alegre');
    final happy = await container.read(moodPassageProvider('Alegre').future);
    expect(happy, isNotNull);
    expect(happy!.id, isNot(angry.id));
    expect(container.read(dailyVerseProvider).value!.verse!.id, dailyId);
    expect(prefs.getString('current_mood'), 'Alegre');
    expect(prefs.getString('saved_reference'), savedReference);

    await container.read(dailyVerseProvider.notifier).changeMood('General');
    expect(container.read(dailyVerseProvider).value!.verse!.id, dailyId);
  });

  test('selected mood persists across provider restarts independently of day',
      () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer(overrides: [
      bibleInitProvider.overrideWith(_ReadyBibleInit.new),
      bibleRepositoryProvider.overrideWithValue(_FakeBibleRepository()),
    ]);
    await first.read(dailyVerseProvider.future);
    await first.read(dailyVerseProvider.notifier).changeMood('Triste');
    first.dispose();

    final second = ProviderContainer(overrides: [
      bibleInitProvider.overrideWith(_ReadyBibleInit.new),
      bibleRepositoryProvider.overrideWithValue(_FakeBibleRepository()),
    ]);
    addTearDown(second.dispose);
    final stored = await second.read(dailyVerseProvider.future);
    expect(stored.mood, 'Triste');
    final passage = await second.read(moodPassageProvider('Triste').future);
    expect(passage, isNotNull);
    expect(passage!.id, isNot(stored.verse!.id));
    expect(passage.reflectionQuestion, isNotEmpty);
  });
}
