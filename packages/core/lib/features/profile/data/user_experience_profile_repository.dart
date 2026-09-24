import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/data/settings_repository.dart';
import 'package:hive/hive.dart';

class UserExperienceProfileRepository {
  static const String storageKey = 'user_experience_profile_v1';

  final Box<dynamic> _metadataBox;

  UserExperienceProfileRepository(this._metadataBox);

  UserExperienceProfile? getStoredProfile() {
    final raw = _metadataBox.get(storageKey);
    if (raw is! Map) return null;

    return UserExperienceProfile.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }

  Future<UserExperienceProfile> getOrMigrate(
    SettingsState legacySettings,
  ) async {
    final stored = getStoredProfile();
    if (stored != null) return stored;

    final profile = _metadataBox.containsKey(SettingsRepository.storageKey)
        ? UserExperienceProfile.fromLegacySettings(legacySettings)
        : const UserExperienceProfile();

    await saveProfile(profile);
    return profile;
  }

  Future<void> saveProfile(UserExperienceProfile profile) {
    return _metadataBox.put(storageKey, profile.toJson());
  }
}
