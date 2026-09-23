import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';
import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/domain/models/verse.dart';

class BibleReaderState {
  final List<String> books;
  final String? selectedBook;
  final List<int> chapters;
  final int? selectedChapter;
  final List<Verse> verses;
  final bool isLoading;

  BibleReaderState({
    this.books = const [],
    this.selectedBook,
    this.chapters = const [],
    this.selectedChapter,
    this.verses = const [],
    this.isLoading = true,
  });

  BibleReaderState copyWith({
    List<String>? books,
    String? selectedBook,
    List<int>? chapters,
    int? selectedChapter,
    List<Verse>? verses,
    bool? isLoading,
  }) {
    return BibleReaderState(
      books: books ?? this.books,
      selectedBook: selectedBook ?? this.selectedBook,
      chapters: chapters ?? this.chapters,
      selectedChapter: selectedChapter ?? this.selectedChapter,
      verses: verses ?? this.verses,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BibleReaderNotifier extends AsyncNotifier<BibleReaderState> {
  @override
  Future<BibleReaderState> build() async {
    // React to DB initialization — rebuild when ready
    final initState = ref.watch(bibleInitProvider);
    if (!initState.isReady) {
      return BibleReaderState(isLoading: initState.status == BibleDbStatus.loading);
    }

    final repo = ref.read(bibleRepositoryProvider);
    final books = await repo.getBooks();
    
    if (books.isEmpty) {
      return BibleReaderState(isLoading: false);
    }
    
    final selectedBook = books.first;
    final chapters = await repo.getChapters(selectedBook);
    final selectedChapter = chapters.isNotEmpty ? chapters.first : 1;
    final verses = await repo.getVerses(selectedBook, selectedChapter);

    return BibleReaderState(
      books: books,
      selectedBook: selectedBook,
      chapters: chapters,
      selectedChapter: selectedChapter,
      verses: verses,
      isLoading: false,
    );
  }

  Future<void> selectBook(String book) async {
    // Capture current state BEFORE overwriting with loading
    final current = state.value ?? BibleReaderState();
    state = const AsyncValue.loading();
    final repo = ref.read(bibleRepositoryProvider);
    
    final chapters = await repo.getChapters(book);
    final selectedChapter = chapters.isNotEmpty ? chapters.first : 1;
    final verses = await repo.getVerses(book, selectedChapter);

    state = AsyncValue.data(current.copyWith(
      selectedBook: book,
      chapters: chapters,
      selectedChapter: selectedChapter,
      verses: verses,
      isLoading: false,
    ));
  }

  Future<void> selectChapter(int chapter) async {
    // Capture current state BEFORE overwriting with loading
    final current = state.value ?? BibleReaderState();
    state = const AsyncValue.loading();
    final repo = ref.read(bibleRepositoryProvider);
    
    if (current.selectedBook == null) {
      state = AsyncValue.data(current.copyWith(isLoading: false));
      return;
    }

    final verses = await repo.getVerses(current.selectedBook!, chapter);

    state = AsyncValue.data(current.copyWith(
      selectedChapter: chapter,
      verses: verses,
      isLoading: false,
    ));
  }
}

final bibleReaderProvider = AsyncNotifierProvider<BibleReaderNotifier, BibleReaderState>(BibleReaderNotifier.new);
