/// A small, local-only audit trail of user-confirmed wellness-goal edits.
/// Stores no food, medical data or identity; never used to calculate a goal.
enum WellnessGoalChangeSource { preferences, nutritionReview }

class WellnessGoalChange {
  const WellnessGoalChange({
    required this.previousTarget,
    required this.newTarget,
    required this.changedAt,
    required this.source,
  });

  final int previousTarget;
  final int newTarget;
  final DateTime changedAt;
  final WellnessGoalChangeSource source;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'previousTarget': previousTarget,
    'newTarget': newTarget,
    'changedAt': changedAt.toIso8601String(),
    'source': source.name,
  };

  factory WellnessGoalChange.fromJson(Map<String, dynamic> json) {
    final previous=(json['previousTarget'] as num).toInt();
    final next=(json['newTarget'] as num).toInt();
    final time=DateTime.parse(json['changedAt'] as String);
    if(previous<0 || next<0 || previous>1000000 || next>1000000){
      throw const FormatException('Invalid wellness goal history');
    }
    return WellnessGoalChange(
      previousTarget: previous,
      newTarget: next,
      changedAt: time,
      source: WellnessGoalChangeSource.values.firstWhere(
        (e)=>e.name==json['source'],
        orElse:()=>WellnessGoalChangeSource.preferences),
    );
  }

  /// Keep the metadata bounded. Legacy preference payloads have no history.
  static List<WellnessGoalChange> restore(dynamic data) {
    if(data is! List)return const <WellnessGoalChange>[];
    final changes=<WellnessGoalChange>[];
    for(final item in data) {
      if(item is! Map)continue;
      try{
        changes.add(WellnessGoalChange.fromJson(
          Map<String,dynamic>.from(item)));
      }catch(_){/* A bad audit row must not reset existing goals. */}
    }
    return List<WellnessGoalChange>.unmodifiable(
      changes.length>10?changes.sublist(changes.length-10):changes);
  }

  static List<WellnessGoalChange> append(
    Iterable<WellnessGoalChange> existing,
    WellnessGoalChange change,
  ) {
    final all=[...existing,change];
    return List<WellnessGoalChange>.unmodifiable(
      all.length>10?all.sublist(all.length-10):all);
  }
}
