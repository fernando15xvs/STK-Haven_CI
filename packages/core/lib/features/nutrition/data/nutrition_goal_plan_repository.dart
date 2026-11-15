import 'package:core/domain/models/nutrition_goal_plan.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  Future<void> save(NutritionGoalPlan plan)=>_metadata.put(_key,plan.toJson());
  Future<void> clear()=>_metadata.delete(_key);
}
