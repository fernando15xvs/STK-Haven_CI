import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/domain/models/gamification_state.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:core/features/profile/application/gamification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/app_ui_styles.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/core/theme/components/section_heading.dart';
import 'package:gym_tracker/features/profile/presentation/pages/personal_profile_page.dart';
import 'package:gym_tracker/features/profile/presentation/pages/experience_preferences_page.dart';
import 'package:gym_tracker/features/profile/presentation/pages/achievements_page.dart';
import 'package:gym_tracker/features/profile/presentation/pages/profile_settings_page.dart';
import 'package:gym_tracker/features/profile/presentation/widgets/personal_profile_summary.dart';

/// One owner for visible identity and achievements. Preferences live in Ajustes;
/// performance metrics and training programs stay in Progreso and Entrenar.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userExperienceProfileProvider).value;
    final settings = ref.watch(settingsProvider);
    final gamification = ref.watch(gamificationProvider);
    final colors = AppColors.of(context);
    final tokens = AppUiTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            key: const ValueKey('profile_open_settings'),
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _open(context, const ProfileSettingsPage()),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: tokens.pageHorizontalPadding),
          children: [
            const SizedBox(height: 8),
            PersonalProfileSummary(
              onEdit: () => _open(
                context,
                const PersonalProfilePage(mobileCompactLayout: true),
              ),
            ),
            if (profile?.needsOptionalTrainingFollowup == true) ...[
              SizedBox(height: tokens.sectionGap),
              PremiumCard(
                key: const ValueKey('profile_legacy_training_followup'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Personaliza tu entrenamiento cuando quieras',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('Puedes completar solo lo que falte. Tus rutinas, '
                        'respuestas anteriores y cuenta se conservan.',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.tonal(
                          key: const ValueKey('profile_complete_legacy_training'),
                          onPressed: () => _open(
                            context, const ExperiencePreferencesPage()),
                          child: const Text('Revisar mis ajustes'),
                        ),
                        TextButton(
                          key: const ValueKey('profile_skip_legacy_training'),
                          onPressed: () async {
                            try {
                              await ref.read(userExperienceProfileProvider.notifier)
                                  .updateProfile(profile!.copyWith(
                                      legacyTrainingFollowupDismissed: true));
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text(
                                    'No se pudo guardar tu elección. Puedes reintentarlo.')),
                                );
                              }
                            }
                          },
                          child: const Text('Ahora no'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: tokens.sectionGap),
            const SectionHeading(title: 'TUS DATOS'),
            const SizedBox(height: 10),
            PremiumCard(
              child: _ProfileFacts(profile: profile, unit: settings.weightUnit),
            ),
            SizedBox(height: tokens.sectionGap),
            const SectionHeading(title: 'RECONOCIMIENTOS'),
            const SizedBox(height: 10),
            PremiumCard(
              onTap: () => _open(context, const AchievementsPage()),
              child: _LevelSummary(gamification: gamification),
            ),
            const SizedBox(height: 12),
            Text(
              'Solo mostramos aquí tus preferencias guardadas. '
              'Puedes editarlas sin volver a iniciar el onboarding.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            SizedBox(height: tokens.sectionGap + 24),
          ],
        ),
      ),
    );
  }
}

class _ProfileFacts extends StatelessWidget {
  const _ProfileFacts({required this.profile, required this.unit});
  final UserExperienceProfile? profile;
  final WeightUnit unit;

  String get goal => switch (profile?.trainingGoal) {
    TrainingGoal.hypertrophy => 'Ganar músculo',
    TrainingGoal.strength => 'Ganar fuerza',
    TrainingGoal.activeLifestyle => 'Vida activa',
    TrainingGoal.conditioning => 'Acondicionamiento',
    TrainingGoal.selfDirected => 'Entrenamiento libre',
    null => 'Sin definir',
  };
  String get experience => switch (profile?.trainingExperience) {
    TrainingExperience.beginner => 'Principiante',
    TrainingExperience.intermediate => 'Intermedio',
    TrainingExperience.advanced => 'Avanzado',
    null => 'Sin definir',
  };
  String get environment => switch (profile?.trainingEnvironment) {
    TrainingEnvironment.fullGym => 'Gimnasio',
    TrainingEnvironment.homeWeights => 'Casa con pesas',
    TrainingEnvironment.minimalEquipment => 'Casa · equipamiento básico',
    TrainingEnvironment.mixed => 'Casa y gimnasio',
    null => 'Sin definir',
  };
  String get duration => switch (profile?.sessionDuration) {
    SessionDurationPreference.minutes30 => '30 minutos',
    SessionDurationPreference.minutes45 => '45 minutos',
    SessionDurationPreference.minutes60 => '60 minutos',
    SessionDurationPreference.minutes75Plus => '75 minutos o más',
    SessionDurationPreference.variable => 'Flexible',
    null => 'Sin definir',
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final personal = profile;
    final birthDate = personal?.dateOfBirth;
    final gender = switch (personal?.genderIdentity) {
      GenderIdentity.woman => 'Mujer',
      GenderIdentity.man => 'Hombre',
      GenderIdentity.nonBinary => 'No binario / otra identidad',
      GenderIdentity.preferNotToSay => 'Prefiero no decirlo',
      null => 'Sin definir',
    };
    final items = <(String, String)>[
      if (personal?.optionalDemographicsConsented == true) ...[
        ('Fecha de nacimiento', birthDate == null ? 'Sin definir' :
          MaterialLocalizations.of(context).formatCompactDate(birthDate)),
        ('Género', gender),
      ],
      ('Objetivo', goal),
      ('Experiencia', experience),
      ('Días por semana',
       profile?.trainingDaysPerWeek == null
           ? 'Sin definir'
           : '${profile!.trainingDaysPerWeek} días'),
      ('Dónde entrenas', environment),
      ('Duración', duration),
      ('Unidad de peso', unit.label),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: colors.surfaceBorder),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(items[i].$1,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: Text(items[i].$2,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LevelSummary extends StatelessWidget {
  const _LevelSummary({required this.gamification});
  final GamificationState gamification;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final unlocked = gamification.achievements
        .where((a) => a.isUnlocked).length;
    return Row(
      children: [
        Icon(Icons.emoji_events_outlined, color: colors.gold, size: 34),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nivel ${gamification.level}',
                style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${gamification.xp} XP · $unlocked medallas desbloqueadas',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
      ],
    );
  }
}
