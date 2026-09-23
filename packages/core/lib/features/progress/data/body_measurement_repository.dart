import 'package:hive/hive.dart';
import '../../../database/hive/models/hive_body_measurement.dart';
import '../../../domain/models/body_measurement.dart';

class BodyMeasurementRepository {
  final Box<HiveBodyMeasurement> _box;

  BodyMeasurementRepository(this._box);

  List<BodyMeasurement> getAllMeasurements() {
    return _box.values.map((h) => h.toDomain()).toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // descending
  }

  Future<void> saveMeasurement(BodyMeasurement measurement) async {
    final hiveModel = HiveBodyMeasurement.fromDomain(measurement);
    await _box.put(measurement.id, hiveModel);
  }

  Future<void> deleteMeasurement(String id) async {
    await _box.delete(id);
  }
}
