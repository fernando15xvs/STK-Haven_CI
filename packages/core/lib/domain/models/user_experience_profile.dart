import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';

/// Optional personal identity, deliberately separate from energy equations.
enum GenderIdentity { woman, man, nonBinary, preferNotToSay }

enum UserCapability { athlete, coach }

enum TrainingGoal {
  hypertrophy,
  strength,
  activeLifestyle,
  conditioning,
  selfDirected,
}

enum TrainingExperience { beginner, intermediate, advanced }

enum SessionDurationPreference {
  minutes30,
  minutes45,
  minutes60,
  minutes75Plus,
  variable,
}

enum TrainingEnvironment {
  fullGym,
  homeWeights,
  minimalEquipment,
  mixed,
}

enum PlanningPreference {
  recommendation,
  selfDirected,
  decideLater,
}

enum FaithContentPreference {
  enabled,
  disabled,
  undecided,
}

class UserExperienceProfile {
  static const int currentOnboardingVersion = 3;

  final String displayName;
  final String? avatarEmoji;
  /// Private, locally stored thumbnail. Not included in coach-sharing payloads.
  final String? avatarPhotoBase64;
  final bool showWorkoutReflections;
  final Set<UserCapability> capabilities;
  final TrainingGoal? trainingGoal;
  final TrainingExperience? trainingExperience;
  final int? trainingDaysPerWeek;
  final SessionDurationPreference sessionDuration;
  final TrainingEnvironment? trainingEnvironment;
  final PlanningPreference planningPreference;
  final WeightUnit weightUnit;
  final bool workoutRemindersWanted;
  final FaithContentPreference faithPreference;
  final bool habitsEnabled;
  /// Legacy optional DOB for demographic equations. Never proof of adulthood.
  final DateTime? dateOfBirth;
  /// Separately declared DOB for the proposed 15+ eligibility flow.
  /// Never authorizes a privileged nutrition RPC or verifies identity.
  final DateTime? eligibilityBirthDate;
  final GenderIdentity? genderIdentity;
  /// A separate optional physiological input for an adult energy equation.
  final EnergyEquationSex? equationSexForEnergy;
  /// Local opt-in. Legacy records remain readable, but are never silently
  /// marked as consented. This does not grant server-verified adult access.
  final bool optionalDemographicsConsented;
  final DateTime? optionalDemographicsConsentedAt;
  final DateTime? optionalDemographicsUpdatedAt;
  final int onboardingVersion;
  /// Optional legacy follow-up can be declined without changing or
  /// repeating the user's completed onboarding answers.
  final bool legacyTrainingFollowupDismissed;

  const UserExperienceProfile({
    this.displayName = '',
    this.avatarEmoji,
    this.avatarPhotoBase64,
    this.showWorkoutReflections = true,
    this.capabilities = const <UserCapability>{UserCapability.athlete},
    this.trainingGoal,
    this.trainingExperience,
    this.trainingDaysPerWeek,
    this.sessionDuration = SessionDurationPreference.variable,
    this.trainingEnvironment,
    this.planningPreference = PlanningPreference.decideLater,
    this.weightUnit = WeightUnit.kg,
    this.workoutRemindersWanted = false,
    this.faithPreference = FaithContentPreference.undecided,
    this.habitsEnabled = false,
    this.dateOfBirth,
    this.eligibilityBirthDate,
    this.genderIdentity,
    this.equationSexForEnergy,
    this.optionalDemographicsConsented = false,
    this.optionalDemographicsConsentedAt,
    this.optionalDemographicsUpdatedAt,
    this.onboardingVersion = 0,
    this.legacyTrainingFollowupDismissed = false,
  });

  String get preferredName => displayName.trim().isEmpty ? 'Tu perfil' : displayName.trim();

  bool get faithEnabled => faithPreference == FaithContentPreference.enabled;

  bool get hasDecidedFaithPreference =>
      faithPreference != FaithContentPreference.undecided;

  int? ageAt(DateTime now) {
    final dob = eligibilityBirthDate ?? dateOfBirth;
    if (dob == null || dob.isAfter(now)) return null;
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years < 0 ? null : years;
  }

  /// Only missing training choices are worth surfacing for legacy profiles.
  /// No birth date, equation input, faith answer or age verification is
  /// required to dismiss the suggestion or continue training.
  bool get needsOptionalTrainingFollowup =>
      !legacyTrainingFollowupDismissed &&
      onboardingVersion > 0 &&
      onboardingVersion < currentOnboardingVersion &&
      (trainingGoal == null ||
       trainingExperience == null ||
       trainingDaysPerWeek == null ||
       trainingEnvironment == null);

  bool get isCoach => capabilities.contains(UserCapability.coach);

  bool get isAthlete => capabilities.contains(UserCapability.athlete);

  UserExperienceProfile copyWith({
    String? displayName,
    String? avatarEmoji,
    bool clearAvatar = false,
    String? avatarPhotoBase64,
    bool clearAvatarPhoto = false,
    bool? showWorkoutReflections,
    Set<UserCapability>? capabilities,
    TrainingGoal? trainingGoal,
    bool clearTrainingGoal = false,
    TrainingExperience? trainingExperience,
    bool clearTrainingExperience = false,
    int? trainingDaysPerWeek,
    bool clearTrainingDays = false,
    SessionDurationPreference? sessionDuration,
    TrainingEnvironment? trainingEnvironment,
    bool clearTrainingEnvironment = false,
    PlanningPreference? planningPreference,
    WeightUnit? weightUnit,
    bool? workoutRemindersWanted,
    FaithContentPreference? faithPreference,
    bool? habitsEnabled,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    DateTime? eligibilityBirthDate,
    bool clearEligibilityBirthDate = false,
    GenderIdentity? genderIdentity,
    bool clearGenderIdentity = false,
    EnergyEquationSex? equationSexForEnergy,
    bool clearEquationSexForEnergy = false,
    bool? optionalDemographicsConsented,
    DateTime? optionalDemographicsConsentedAt,
    bool clearOptionalDemographicsConsentAt = false,
    DateTime? optionalDemographicsUpdatedAt,
    int? onboardingVersion,
    bool? legacyTrainingFollowupDismissed,
  }) {
    return UserExperienceProfile(
      displayName: displayName ?? this.displayName,
      avatarEmoji: clearAvatar ? null : (avatarEmoji ?? this.avatarEmoji),
      avatarPhotoBase64: clearAvatarPhoto
          ? null
          : (avatarPhotoBase64 ?? this.avatarPhotoBase64),
      showWorkoutReflections: showWorkoutReflections ?? this.showWorkoutReflections,
      capabilities: capabilities ?? this.capabilities,
      trainingGoal:
          clearTrainingGoal ? null : (trainingGoal ?? this.trainingGoal),
      trainingExperience: clearTrainingExperience
          ? null
          : (trainingExperience ?? this.trainingExperience),
      trainingDaysPerWeek: clearTrainingDays
          ? null
          : (trainingDaysPerWeek ?? this.trainingDaysPerWeek),
      sessionDuration: sessionDuration ?? this.sessionDuration,
      trainingEnvironment: clearTrainingEnvironment
          ? null
          : (trainingEnvironment ?? this.trainingEnvironment),
      planningPreference: planningPreference ?? this.planningPreference,
      weightUnit: weightUnit ?? this.weightUnit,
      workoutRemindersWanted:
          workoutRemindersWanted ?? this.workoutRemindersWanted,
      faithPreference: faithPreference ?? this.faithPreference,
      habitsEnabled: habitsEnabled ?? this.habitsEnabled,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      eligibilityBirthDate: clearEligibilityBirthDate
          ? null : (eligibilityBirthDate ?? this.eligibilityBirthDate),
      genderIdentity: clearGenderIdentity ? null : (genderIdentity ?? this.genderIdentity),
      equationSexForEnergy: clearEquationSexForEnergy
          ? null : (equationSexForEnergy ?? this.equationSexForEnergy),
      optionalDemographicsConsented:
          optionalDemographicsConsented ?? this.optionalDemographicsConsented,
      optionalDemographicsConsentedAt: clearOptionalDemographicsConsentAt
          ?null:(optionalDemographicsConsentedAt ??
            this.optionalDemographicsConsentedAt),
      optionalDemographicsUpdatedAt: optionalDemographicsUpdatedAt ??
          this.optionalDemographicsUpdatedAt,
      onboardingVersion: onboardingVersion ?? this.onboardingVersion,
      legacyTrainingFollowupDismissed:
          legacyTrainingFollowupDismissed ??
          this.legacyTrainingFollowupDismissed,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'displayName': displayName,
      'avatarEmoji': avatarEmoji,
      'avatarPhotoBase64': avatarPhotoBase64,
      'showWorkoutReflections': showWorkoutReflections,
      'capabilities': capabilities.map((value) => value.name).toList()..sort(),
      'trainingGoal': trainingGoal?.name,
      'trainingExperience': trainingExperience?.name,
      'trainingDaysPerWeek': trainingDaysPerWeek,
      'sessionDuration': sessionDuration.name,
      'trainingEnvironment': trainingEnvironment?.name,
      'planningPreference': planningPreference.name,
      'weightUnit': weightUnit.name,
      'workoutRemindersWanted': workoutRemindersWanted,
      'faithPreference': faithPreference.name,
      // Kept explicit for diagnostics/export readability. The enum remains the
      // source of truth because onboarding supports a third "decide later" state.
      'faithEnabled': faithEnabled,
      'habitsEnabled': habitsEnabled,
      'dateOfBirth': dateOfBirth == null
          ? null : '${dateOfBirth!.year.toString().padLeft(4, '0')}-'
              '${dateOfBirth!.month.toString().padLeft(2, '0')}-'
              '${dateOfBirth!.day.toString().padLeft(2, '0')}',
      'eligibilityBirthDate': eligibilityBirthDate == null
          ? null : '${eligibilityBirthDate!.year.toString().padLeft(4, '0')}-'
              '${eligibilityBirthDate!.month.toString().padLeft(2, '0')}-'
              '${eligibilityBirthDate!.day.toString().padLeft(2, '0')}',
      'genderIdentity': genderIdentity?.name,
      'equationSexForEnergy': equationSexForEnergy?.name,
      'optionalDemographicsConsented': optionalDemographicsConsented,
      'optionalDemographicsConsentedAt':
          optionalDemographicsConsentedAt?.toIso8601String(),
      'optionalDemographicsUpdatedAt':
          optionalDemographicsUpdatedAt?.toIso8601String(),
      'onboardingVersion': onboardingVersion,
      'legacyTrainingFollowupDismissed': legacyTrainingFollowupDismissed,
    };
  }

  factory UserExperienceProfile.fromJson(Map<String, dynamic> json) {
    final rawCapabilities = json['capabilities'];
    final parsedCapabilities = rawCapabilities is Iterable
        ? rawCapabilities
            .map(
              (value) => _enumByName(
                UserCapability.values,
                value?.toString(),
              ),
            )
            .whereType<UserCapability>()
            .toSet()
        : <UserCapability>{};

    final rawDays = (json['trainingDaysPerWeek'] as num?)?.toInt();
    final safeDays = rawDays != null && rawDays >= 2 && rawDays <= 6
        ? rawDays
        : null;

    final parsedFaith = _enumByName(
      FaithContentPreference.values,
      json['faithPreference']?.toString(),
    );

    final legacyFaithEnabled = json['faithEnabled'];
    final faithPreference = parsedFaith ??
        (legacyFaithEnabled is bool
            ? (legacyFaithEnabled
                ? FaithContentPreference.enabled
                : FaithContentPreference.disabled)
            : FaithContentPreference.undecided);

    final rawOnboardingVersion =
        (json['onboardingVersion'] as num?)?.toInt() ?? 0;

    return UserExperienceProfile(
      displayName: (json['displayName'] as String? ?? '').trim(),
      avatarEmoji: json['avatarEmoji'] as String?,
      avatarPhotoBase64: json['avatarPhotoBase64'] is String
          ? json['avatarPhotoBase64'] as String
          : null,
      showWorkoutReflections: json['showWorkoutReflections'] as bool? ?? true,
      capabilities: parsedCapabilities.isEmpty
          ? const <UserCapability>{UserCapability.athlete}
          : parsedCapabilities,
      trainingGoal: _enumByName(
        TrainingGoal.values,
        json['trainingGoal']?.toString(),
      ),
      trainingExperience: _enumByName(
        TrainingExperience.values,
        json['trainingExperience']?.toString(),
      ),
      trainingDaysPerWeek: safeDays,
      sessionDuration: _enumByName(
            SessionDurationPreference.values,
            json['sessionDuration']?.toString(),
          ) ??
          SessionDurationPreference.variable,
      trainingEnvironment: _enumByName(
        TrainingEnvironment.values,
        json['trainingEnvironment']?.toString(),
      ),
      planningPreference: _enumByName(
            PlanningPreference.values,
            json['planningPreference']?.toString(),
          ) ??
          PlanningPreference.decideLater,
      weightUnit: _enumByName(
            WeightUnit.values,
            json['weightUnit']?.toString(),
          ) ??
          WeightUnit.kg,
      workoutRemindersWanted:
          json['workoutRemindersWanted'] as bool? ?? false,
      faithPreference: faithPreference,
      habitsEnabled: json['habitsEnabled'] as bool? ?? false,
      dateOfBirth: _parseBirthDate(json['dateOfBirth']),
      eligibilityBirthDate: _parseBirthDate(json['eligibilityBirthDate']),
      genderIdentity: _enumByName(
        GenderIdentity.values, json['genderIdentity']?.toString()),
      equationSexForEnergy: _enumByName(
        EnergyEquationSex.values, json['equationSexForEnergy']?.toString()),
      // Never synthesize consent for old backups merely because they contain
      // a birthday. Their prior values and other preferences are preserved.
      optionalDemographicsConsented:
          json['optionalDemographicsConsented'] == true,
      optionalDemographicsConsentedAt:
          json['optionalDemographicsConsented'] == true
            ?DateTime.tryParse(
                json['optionalDemographicsConsentedAt']?.toString()??'')
            :null,
      optionalDemographicsUpdatedAt:DateTime.tryParse(
        json['optionalDemographicsUpdatedAt']?.toString()??''),
      onboardingVersion:
          rawOnboardingVersion < 0 ? 0 : rawOnboardingVersion,
      // Old backups without this key retain a voluntary, dismissible prompt.
      legacyTrainingFollowupDismissed:
          json['legacyTrainingFollowupDismissed'] == true,
    );
  }

  factory UserExperienceProfile.fromLegacySettings(SettingsState settings) {
    return UserExperienceProfile(
      weightUnit: settings.weightUnit,
      workoutRemindersWanted: settings.workoutRemindersEnabled,
      // Existing users already had Faith surfaced by default. Preserve their
      // current experience during migration rather than silently hiding data.
      faithPreference:
          settings.showDailyVerse || settings.dailyVerseNotifications
              ? FaithContentPreference.enabled
              : FaithContentPreference.disabled,
      onboardingVersion: settings.hasCompletedOnboarding ? 1 : 0,
    );
  }
}

DateTime? _parseBirthDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final date = DateTime.tryParse(value);
  if (date == null || date.year < 1900 || date.isAfter(DateTime.now())) {
    return null;
  }
  // Reject impossible dates silently normalized by some DateTime parsers.
  final pattern =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  if (value != pattern) return null;
  return DateTime(date.year, date.month, date.day);
}

T? _enumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
