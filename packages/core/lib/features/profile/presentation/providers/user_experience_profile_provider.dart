import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/data/user_experience_profile_repository.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final userExperienceProfileRepositoryProvider =
    Provider<UserExperienceProfileRepository>((ref) {
  return UserExperienceProfileRepository(
    Hive.box<dynamic>(HiveBoxes.metadata),
  );
});

final userExperienceProfileProvider = AsyncNotifierProvider<
    UserExperienceProfileNotifier,
    UserExperienceProfile>(UserExperienceProfileNotifier.new);

class UserExperienceProfileNotifier
    extends AsyncNotifier<UserExperienceProfile> {
  UserExperienceProfileRepository get _repository =>
      ref.read(userExperienceProfileRepositoryProvider);

  @override
  Future<UserExperienceProfile> build() async {
    final repository = ref.watch(userExperienceProfileRepositoryProvider);

    // Legacy settings are needed only to seed a profile when none exists yet.
    // Watching SettingsState here rebuilds this AsyncNotifier after every
    // settings change. The previous late-final repository assignment then ran
    // a second time on Web and raised LateInitializationError.
    final legacySettings = ref.read(settingsProvider);
    return repository.getOrMigrate(legacySettings);
  }

  Future<void> updateProfile(UserExperienceProfile profile) async {
    await _repository.saveProfile(profile);
    state = AsyncValue.data(profile);
  }

  Future<void> setFaithPreference(FaithContentPreference preference) async {
    final current = state.value;
    if (current == null) return;
    if (preference != FaithContentPreference.enabled) {
      await ref
          .read(settingsProvider.notifier)
          .setDailyVerseNotifications(false);
    }
    await updateProfile(current.copyWith(faithPreference: preference));
  }

  Future<void> setCapabilities(Set<UserCapability> capabilities) async {
    final current = state.value;
    if (current == null) return;
    final safeCapabilities = capabilities.isEmpty
        ? const <UserCapability>{UserCapability.athlete}
        : capabilities;
    await updateProfile(current.copyWith(capabilities: safeCapabilities));
  }

  Future<void> setHabitsEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await updateProfile(current.copyWith(habitsEnabled: enabled));
  }
}
