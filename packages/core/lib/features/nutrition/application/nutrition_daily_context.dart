import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:core/features/recovery/application/sleep_diary.dart';
import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';

/// Contextual guidance only. Does not mutate any target, prescribe water,
/// add exercise calories, or turn recovery into a food restriction.
class NutritionDailyContext {
  const NutritionDailyContext._();

  /// Observed duration of completed sessions only. Missing records do not
  /// mean the person was inactive or imply that this is a scheduled rest day.
  static int completedTrainingMinutes(Iterable<WorkoutSession> sessions, DateTime now) =>
      sessions.where((s)=>SleepDiary.dayKey(s.finishedAt.toLocal())==SleepDiary.dayKey(now)
        && !s.finishedAt.isAfter(now) && !s.finishedAt.isBefore(s.startedAt)
        && s.durationSeconds>=600
        && s.exercises.any((e)=>e.sets.any((set)=>set.completed && set.setType==WorkoutSetType.working)))
      .fold<int>(0,(sum,s)=>sum+s.durationSeconds)~/60;

  /// Two seven-day windows with at least three distinct recorded days each.
  /// Returns descriptive evidence only, not a weight-loss rate or an automatic
  /// adjustment. A day with no measurement does not count as zero.
  static ({double earlier,double recent,int earlierDays,int recentDays})? weightReview(
      Iterable<BodyMeasurement> records,DateTime now){
    final day=DateTime(now.year,now.month,now.day);
    final start=DateTime(day.year,day.month,day.day-13);
    final split=DateTime(day.year,day.month,day.day-6);
    final byDay=<String,BodyMeasurement>{};
    for(final r in records){
      final value=r.weightKg;
      if(value==null||!value.isFinite||value<35||value>300||r.date.isAfter(now))continue;
      final d=r.date.toLocal();
      final date=DateTime(d.year,d.month,d.day);
      if(date.isBefore(start)||date.isAfter(day))continue;
      final key=SleepDiary.dayKey(date);
      if(byDay[key]==null||r.date.isAfter(byDay[key]!.date))byDay[key]=r;
    }
    final earlier=<double>[],recent=<double>[];
    for(final r in byDay.values){
      final d=r.date.toLocal();
      (DateTime(d.year,d.month,d.day).isBefore(split)?earlier:recent).add(r.weightKg!);
    }
    if(earlier.length<3||recent.length<3)return null;
    double median(List<double> values){
      values.sort();
      final m=values.length~/2;
      return values.length.isOdd?values[m]:(values[m-1]+values[m])/2;
    }
    return (earlier:median(earlier),recent:median(recent),earlierDays:earlier.length,recentDays:recent.length);
  }

  static String guidance({
    required StkNutritionIntent intent,
    required bool adultAuthorized,
    required DateTime now,
    required SleepDiary sleep,
    RecoveryCheckIn? recovery,
    required bool trainingCompleted,
    bool trainingPlanned = false,
  }) {
    final today = recovery != null &&
        SleepDiary.dayKey(recovery.date)==SleepDiary.dayKey(now) &&
        !recovery.updatedAt.isAfter(now) ? recovery : null;
    if (today?.painReported == true) {
      return 'Revisa las molestias con Recuperación. Evita compensar el descanso con más actividad.';
    }
    final hours = sleep.minutesFor(now);
    if ((hours != null && hours < 360) ||
        (today != null && (today.energy <= 2 || today.soreness >= 4))) {
      return 'Prioriza descanso y alimentación suficiente. Revisa la exigencia en Entrenar; no cambies metas para compensar.';
    }
    if (!adultAuthorized) {
      return 'Comidas variadas, descanso y actividad que disfrutes. Las metas de bienestar no dependen del peso.';
    }
    if (trainingCompleted || trainingPlanned) {
      return switch(intent) {
        StkNutritionIntent.volume => 'Acompaña tu entrenamiento con alimentación suficiente, hidratación y recuperación.',
        StkNutritionIntent.deficit => 'Conserva la calidad del entrenamiento y una alimentación suficiente. No añadas actividad para compensar comidas.',
        StkNutritionIntent.maintenance => 'Mantén una alimentación regular y revisa tu hidratación y recuperación.',
      };
    }
    return 'Mantén hábitos regulares. No tener una sesión registrada no exige añadir pasos ni cambiar el plan.';
  }
}

/// One internally coherent example, not three independently summed maxima.
/// Only for healthy exercising adults 19+, behind the existing numeric gate.
/// Protein reference: ISSN 2017 (doi:10.1186/s12970-017-0177-8);
/// AMDR bounds: Health Canada adult reference tables.
class TrainingMacroExample {
  const TrainingMacroExample(this.proteinG,this.carbsG,this.fatG);
  final int proteinG, carbsG, fatG;
  int get energy => 4*proteinG+4*carbsG+9*fatG;

  static TrainingMacroExample? calculate(AdultEnergyProfile profile,
      EnergyEstimate estimate) {
    if(profile.ageYears<19 || !profile.weightKg.isFinite ||
        profile.weightKg<35 || profile.weightKg>300 ||
        estimate.targetLow<=0 || estimate.targetHigh<estimate.targetLow ||
        estimate.targetHigh>10000 || estimate.goal!=profile.goal) return null;
    final kcal=(estimate.targetLow+estimate.targetHigh)/2;
    final factor=switch(profile.goal) {
      EnergyGoal.gradualLoss => 1.8,
      EnergyGoal.gradualGain => 1.6,
      EnergyGoal.maintenance => 1.6,
    };
    final protein=(profile.weightKg*factor).round();
    final fat=(kcal*.25/9).round();
    final carbs=((kcal-protein*4-fat*9)/4).round();
    final example=TrainingMacroExample(protein,carbs,fat);
    final total=example.energy;
    if(total<estimate.targetLow || total>estimate.targetHigh || carbs<0 ||
       protein*4/total<.10 || protein*4/total>.35 ||
       carbs*4/total<.45 || carbs*4/total>.65 ||
       fat*9/total<.20 || fat*9/total>.35) return null;
    return example;
  }
}
