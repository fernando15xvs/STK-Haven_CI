import 'package:core/domain/models/settings_state.dart';

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
  static const int currentOnboardingVersion = 2;

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
  final int onboardingVersion;

  const UserExperienceProfile({
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
    this.onboardingVersion = 0,
  });

  bool get faithEnabled => faithPreference == FaithContentPreference.enabled;

  bool get hasDecidedFaithPreference =>
      faithPreference != FaithContentPreference.undecided;

  bool get isCoach => capabilities.contains(UserCapability.coach);

  bool get isAthlete => capabilities.contains(UserCapability.athlete);

  UserExperienceProfile copyWith({
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
    int? onboardingVersion,
  }) {
    return UserExperienceProfile(
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
      onboardingVersion: onboardingVersion ?? this.onboardingVersion,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
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
      'onboardingVersion': onboardingVersion,
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
      onboardingVersion:
          rawOnboardingVersion < 0 ? 0 : rawOnboardingVersion,
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

T? _enumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
