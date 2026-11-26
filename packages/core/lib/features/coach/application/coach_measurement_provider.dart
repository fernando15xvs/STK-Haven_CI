import 'package:core/core/services/supabase_client_gateway.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase/supabase.dart';

/// No identifiers of local records, notes, photos or entire history are uploaded.
const coachMeasurementLabels = <String, String>{
  'weightKg':'Peso (kg)', 'bodyFatPercentage':'Grasa corporal (%)',
  'heightCm':'Estatura (cm)', 'shouldersCm':'Hombros (cm)',
  'chestCm':'Pecho (cm)', 'waistCm':'Cintura (cm)', 'hipsCm':'Cadera (cm)',
  'leftArmCm':'Brazo izquierdo (cm)', 'rightArmCm':'Brazo derecho (cm)',
  'leftLegCm':'Pierna izquierda (cm)', 'rightLegCm':'Pierna derecha (cm)',
  'calvesCm':'Pantorrilla (cm)', 'neckCm':'Cuello (cm)',
  'leftForearmCm':'Antebrazo izquierdo (cm)', 'rightForearmCm':'Antebrazo derecho (cm)',
  'leftCalfCm':'Pantorrilla izquierda (cm)', 'rightCalfCm':'Pantorrilla derecha (cm)',
};

Map<String, double> coachMeasurementValues(BodyMeasurement measurement) {
  final candidates = <String,double?>{
    'weightKg':measurement.weightKg, 'bodyFatPercentage':measurement.bodyFatPercentage,
    'heightCm':measurement.heightCm, 'shouldersCm':measurement.shouldersCm,
    'chestCm':measurement.chestCm, 'waistCm':measurement.waistCm, 'hipsCm':measurement.hipsCm,
    'leftArmCm':measurement.leftArmCm, 'rightArmCm':measurement.rightArmCm,
    'leftLegCm':measurement.leftLegCm, 'rightLegCm':measurement.rightLegCm,
    'calvesCm':measurement.calvesCm, 'neckCm':measurement.neckCm,
    'leftForearmCm':measurement.leftForearmCm, 'rightForearmCm':measurement.rightForearmCm,
    'leftCalfCm':measurement.leftCalfCm, 'rightCalfCm':measurement.rightCalfCm,
  };
  return Map.unmodifiable({for (final entry in candidates.entries)
    if (entry.value != null && validCoachMeasurement(entry.key,entry.value!)) entry.key:entry.value!});
}
bool validCoachMeasurement(String key, num value) =>
    coachMeasurementLabels.containsKey(key) && value.isFinite &&
    (key == 'bodyFatPercentage' ? value >= 0 && value <= 100 : value > 0 && value <= 500);

class CoachMeasurementShare {
  final String relationshipId;
  final DateTime measuredAt, sharedAt;
  final Map<String,double> values;
  const CoachMeasurementShare({required this.relationshipId, required this.measuredAt,
    required this.sharedAt, required this.values});
  factory CoachMeasurementShare.fromJson(Map<String,dynamic> json, String relationshipId) {
    final raw = json['values'];
    final measuredAt = DateTime.tryParse('${json['measured_at']}');
    final sharedAt = DateTime.tryParse('${json['shared_at']}');
    if (json['relationship_id'] != relationshipId || raw is! Map || raw.isEmpty ||
        measuredAt == null || sharedAt == null) throw const FormatException('Invalid measurement share');
    final values = <String,double>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString(), value = entry.value;
      if (value is! num || !validCoachMeasurement(key,value)) throw const FormatException('Invalid measurement field');
      values[key] = value.toDouble();
    }
    return CoachMeasurementShare(relationshipId: relationshipId, measuredAt: measuredAt,
      sharedAt: sharedAt, values: Map.unmodifiable(values));
  }
}

class CoachMeasurementService {
  final SupabaseClient client;
  const CoachMeasurementService(this.client);
  Future<CoachMeasurementShare?> read(String relationshipId) async {
    final data = await client.rpc('stk_get_coach_measurements',params:{'p_relationship_id':relationshipId});
    if (data == null) return null;
    if (data is! Map) throw const FormatException('Invalid measurement share');
    return CoachMeasurementShare.fromJson(Map<String,dynamic>.from(data),relationshipId);
  }
  Future<void> share(String relationshipId, DateTime measuredAt, Map<String,double> values) async {
    if (values.isEmpty || values.entries.any((entry)=>!validCoachMeasurement(entry.key,entry.value))) {
      throw const FormatException('Invalid measurement fields');
    }
    await client.rpc('stk_share_coach_measurements',params:{
      'p_relationship_id':relationshipId,'p_measured_at':measuredAt.toUtc().toIso8601String(),
      'p_values':values,
    });
  }
  Future<void> clear(String relationshipId) async {
    await client.rpc('stk_clear_coach_measurements',params:{'p_relationship_id':relationshipId});
  }
}
final coachMeasurementServiceProvider = Provider((ref)=>CoachMeasurementService(CoreSupabaseClient.client));
typedef CoachMeasurementQuery = ({String relationshipId,String userId});
final coachMeasurementProvider = FutureProvider.autoDispose.family<CoachMeasurementShare?,CoachMeasurementQuery>((ref,query) async {
  final actor=ref.watch(appIdentityProvider.select((value)=>(value.signedIn,value.userId)));
  if (!actor.$1 || actor.$2 != query.userId) return null;
  return ref.watch(coachMeasurementServiceProvider).read(query.relationshipId);
});
