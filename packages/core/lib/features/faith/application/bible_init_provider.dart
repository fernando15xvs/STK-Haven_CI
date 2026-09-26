import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/faith/data/bible_database.dart';
import 'package:core/features/faith/application/faith_feature_policy.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';

/// Observable initialization state for the Bible SQLite database.
enum BibleDbStatus { idle, loading, ready, error }

class BibleInitState {
  final BibleDbStatus status;
  final String? errorMessage;

  const BibleInitState({this.status = BibleDbStatus.idle, this.errorMessage});

  bool get isReady => status == BibleDbStatus.ready;

  BibleInitState copyWith({BibleDbStatus? status, String? errorMessage}) {
    return BibleInitState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class BibleInitNotifier extends Notifier<BibleInitState> {
  @override
  BibleInitState build() => const BibleInitState();

  /// Call this after HiveDatabase.init(). When the DB is ready it invalidates
  /// dependent providers so the UI refreshes automatically.
  Future<void> initialize() async {
    final faithEnabled =
        ref.read(userExperienceProfileProvider).value?.faithEnabled == true;
    if (!FaithFeaturePolicy.shouldLoadBible(faithEnabled: faithEnabled)) {
      state = const BibleInitState(status: BibleDbStatus.idle);
      return;
    }
    state = const BibleInitState(status: BibleDbStatus.loading);
    try {
      final initialized = await BibleDatabase.instance
          .initializeDatabaseFromInternet((_) {});
      if (!initialized) {
        throw StateError('No fue posible preparar los datos de la Biblia.');
      }
      state = const BibleInitState(status: BibleDbStatus.ready);
      // dailyVerseProvider and bibleReaderProvider watch bibleInitProvider,
      // so they will rebuild automatically.
    } catch (e) {
      state = BibleInitState(
        status: BibleDbStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final bibleInitProvider =
    NotifierProvider<BibleInitNotifier, BibleInitState>(BibleInitNotifier.new);
