import 'package:core/domain/models/hydration_preferences.dart';
import 'package:core/domain/models/step_goal_preferences.dart';
import 'package:core/domain/models/wellness_goal_change.dart';
import 'package:test/test.dart';

void main() {
  WellnessGoalChange change(int from,int to, {
    WellnessGoalChangeSource source=WellnessGoalChangeSource.nutritionReview,
  })=>WellnessGoalChange(
    previousTarget:from,newTarget:to,
    changedAt:DateTime.utc(2026,11,15,20),
    source:source,
  );

  test('old water and steps preferences remain readable without audit fields',(){
    final hydration=HydrationPreferences.fromJson({
      'targetMl':2700,'reminderEnabled':true,'reminderHour':17,
    });
    final steps=StepGoalPreferences.fromJson({
      'targetSteps':6400,'reminderEnabled':true,
      'reminderCadence':'gentle',
    });
    expect(hydration.targetMl,2700);
    expect(hydration.reminderEnabled,isTrue);
    expect(hydration.goalChanges,isEmpty);
    expect(steps.targetSteps,6400);
    expect(steps.reminderCadence,StepReminderCadence.gentle);
    expect(steps.goalChanges,isEmpty);
  });

  test('single preference write includes target and its confirmed provenance',(){
    final audit=change(3000,3200);
    final water=HydrationPreferences(
      reminderEnabled:true,reminderHour:8,
      goalChanges:WellnessGoalChange.append(const [],audit),
    ).copyWith(targetMl:3200);
    final restored=HydrationPreferences.fromJson(water.toJson());
    expect(restored.targetMl,3200);
    expect(restored.reminderEnabled,isTrue);
    expect(restored.reminderHour,8);
    expect(restored.goalChanges.single.previousTarget,3000);
    expect(restored.goalChanges.single.newTarget,3200);
    expect(restored.goalChanges.single.source,
      WellnessGoalChangeSource.nutritionReview);
    expect(restored.goalChanges.single.changedAt,audit.changedAt);

    final stepPrefs=StepGoalPreferences(
      targetSteps:6500,reminderEnabled:true,
      reminderCadence:StepReminderCadence.gentle,
      goalChanges:WellnessGoalChange.append(const [],
        change(5000,6500,source:WellnessGoalChangeSource.preferences)),
    );
    final restoredSteps=StepGoalPreferences.fromJson(stepPrefs.toJson());
    expect(restoredSteps.targetSteps,6500);
    expect(restoredSteps.reminderEnabled,isTrue);
    expect(restoredSteps.reminderCadence,StepReminderCadence.gentle);
    expect(restoredSteps.goalChanges.single.source,
      WellnessGoalChangeSource.preferences);
  });

  test('audit is bounded and corrupt entries never reset the actual goal',(){
    final many=<WellnessGoalChange>[
      for(var i=0;i<14;i++)change(1000+i*100,1100+i*100),
    ];
    final prefs=HydrationPreferences.fromJson({
      'targetMl':2100,
      'goalChanges':[
        {'previousTarget':-1,'newTarget':2400,
          'changedAt':'invalid','source':'nutritionReview'},
        ...many.map((item)=>item.toJson()),
        'unexpected',
      ],
    });
    expect(prefs.targetMl,2100);
    expect(prefs.goalChanges,hasLength(10));
    expect(prefs.goalChanges.first.previousTarget,1400);
    expect(prefs.goalChanges.last.previousTarget,2300);
    expect(WellnessGoalChange.append(prefs.goalChanges,
      change(2100,2200)),hasLength(10));
  });

  test('missing audit and invalid sources do not confer permission or rewrite targets',(){
    final legacy=StepGoalPreferences.fromJson({
      'targetSteps':6200,
      'goalChanges':[{
        'previousTarget':6000,'newTarget':6200,
        'changedAt':'2026-11-15T20:00:00.000Z','source':'unknown',
      }],
    });
    expect(legacy.targetSteps,6200);
    expect(legacy.goalChanges.single.source,
      WellnessGoalChangeSource.preferences);
  });
}
