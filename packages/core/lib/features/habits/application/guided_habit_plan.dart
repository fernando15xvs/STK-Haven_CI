enum GuidedHabitKind { night, breathing, personalPause }
enum GuidedHabitStage { prepare, breathe, reflect, close }
class GuidedHabitStep {
  final GuidedHabitStage stage;
  final int seconds;
  const GuidedHabitStep(this.stage,this.seconds);
}
abstract final class GuidedHabitPlan {
  static List<GuidedHabitStep> steps(GuidedHabitKind kind,int totalSeconds){
    final total=totalSeconds.clamp(60,3600).toInt();
    if(kind!=GuidedHabitKind.night)return [GuidedHabitStep(GuidedHabitStage.breathe,total)];
    final prepare=total~/10, breathe=total*3~/10, reflect=total*4~/10;
    return [GuidedHabitStep(GuidedHabitStage.prepare,prepare),GuidedHabitStep(GuidedHabitStage.breathe,breathe),
      GuidedHabitStep(GuidedHabitStage.reflect,reflect),GuidedHabitStep(GuidedHabitStage.close,total-prepare-breathe-reflect)];
  }
  static GuidedHabitStage stageAt(GuidedHabitKind kind,int elapsed,int target){
    var remaining=elapsed.clamp(0,target).toInt();
    final plan=steps(kind,target);
    for(final step in plan){if(remaining<step.seconds)return step.stage;remaining-=step.seconds;}
    return plan.last.stage;
  }
}
