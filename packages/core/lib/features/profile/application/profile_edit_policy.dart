import 'dart:convert';
import 'package:core/domain/models/user_experience_profile.dart';

/// Pure Dart merge of the single editor's owned fields. A stale draft never
/// overwrites unrelated settings or silently restores revoked demographic data.
class ProfileEditPolicy {
  /// Local optional demographics are distinct from legal age/eligibility.
  /// Revocation clears only these fields; unrelated history and settings stay.
  static UserExperienceProfile withDemographicConsent(
      UserExperienceProfile profile, bool enabled, DateTime now) {
    if (enabled) {
      if (profile.optionalDemographicsConsented) return profile;
      return profile.copyWith(optionalDemographicsConsented:true,
        optionalDemographicsConsentedAt:now);
    }
    return profile.copyWith(optionalDemographicsConsented:false,
      clearOptionalDemographicsConsentAt:true, clearDateOfBirth:true,
      clearGenderIdentity:true, clearEquationSexForEnergy:true);
  }

  static UserExperienceProfile merge({required UserExperienceProfile original,
      required UserExperienceProfile draft, required UserExperienceProfile current,
      required DateTime now}) {
    final before = original.toJson();
    final proposed = draft.toJson();
    final latest = current.toJson();
    bool equal(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);
    final name = draft.displayName.trim();
    if (name.length > 40 || name.contains(RegExp(r'[\x00-\x1F]'))) {
      throw const FormatException('Nombre no válido.');
    }
    proposed['displayName'] = name;
    const groups = [
      ['displayName'], ['avatarEmoji','avatarPhotoBase64'], ['trainingGoal'],
      ['trainingExperience'], ['trainingDaysPerWeek'], ['sessionDuration'],
      ['trainingEnvironment'], ['planningPreference'], ['capabilities'],
      ['faithPreference'], ['showWorkoutReflections'], ['habitsEnabled'], ['showSleepOnHome'],
      ['dateOfBirth','genderIdentity','equationSexForEnergy',
        'optionalDemographicsConsented','optionalDemographicsConsentedAt'],
    ];
    var changedDemographics = false;
    for (final keys in groups) {
      if (!keys.any((k) => !equal(before[k],proposed[k]))) continue;
      if (keys.any((k) => !equal(before[k],latest[k]) && !equal(proposed[k],latest[k]))) {
        throw StateError('El perfil cambió mientras editabas. Vuelve a abrirlo.');
      }
      if (keys.contains('dateOfBirth')) {
        changedDemographics = true;
        final hasData = draft.dateOfBirth != null || draft.genderIdentity != null ||
            draft.equationSexForEnergy != null;
        if (hasData && !draft.optionalDemographicsConsented) {
          throw const FormatException('Autoriza los datos opcionales antes de guardarlos.');
        }
      }
      for (final key in keys) { latest[key] = proposed[key]; }
    }
    if (changedDemographics) latest['optionalDemographicsUpdatedAt'] = now.toIso8601String();
    return UserExperienceProfile.fromJson(latest);
  }
}
