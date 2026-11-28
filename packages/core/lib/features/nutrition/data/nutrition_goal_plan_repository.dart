import 'package:core/domain/models/nutrition_goal_plan.dart';
import 'package:hive/hive.dart';

/// Per authenticated account on-device. No backend grant is read or written
/// here: the caller must still check server-side adult nutrition access.
class NutritionGoalPlanRepository {
  NutritionGoalPlanRepository(this._metadata,this.ownerId)
      :assert(ownerId!='');

  final Box<dynamic> _metadata;
  final String ownerId;
  String get _key=>'stk_nutrition_goal_plan_v1_$ownerId';

  NutritionGoalPlan? read(){
    final value=_metadata.get(_key);
    if(value is! Map)return null;
    try{
      return NutritionGoalPlan.fromJson(Map<String,dynamic>.from(value));
    }catch(_){return null;}
  }
  /// Archive prior explicitly saved calculations in the same account-scoped
  /// record and atomic write. Pause/review edits are not new calculations.
  List<NutritionGoalPlan> previousPlans(){
    final raw=_metadata.get(_key);
    if(raw is! Map || raw['previousPlans'] is! List)return const [];
    final plans=<NutritionGoalPlan>[];
    for(final value in (raw['previousPlans'] as List).take(24)){
      if(value is! Map)continue;
      try{plans.add(NutritionGoalPlan.fromJson(Map<String,dynamic>.from(value)));}
      catch(_){/* Skip invalid old snapshot. */}
    }
    return List.unmodifiable(plans);
  }

  Future<void> save(NutritionGoalPlan plan) async {
    final previous=read();
    final history=previousPlans();
    final archive=[
      if(previous!=null && previous.savedAt!=plan.savedAt) previous,
      ...history,
    ].take(24).map((e)=>e.toJson()).toList();
    await _metadata.put(_key,{...plan.toJson(),'previousPlans':archive});
  }
  Future<void> clear()=>_metadata.delete(_key);
}
