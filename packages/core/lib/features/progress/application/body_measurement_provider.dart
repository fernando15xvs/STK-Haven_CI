import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../database/hive/hive_boxes.dart';
import '../../../database/hive/models/hive_body_measurement.dart';
import '../../../domain/models/body_measurement.dart';
import '../data/body_measurement_repository.dart';

final bodyMeasurementRepositoryProvider = Provider<BodyMeasurementRepository>((ref) {
  final box = Hive.box<HiveBodyMeasurement>(HiveBoxes.bodyMeasurements);
  return BodyMeasurementRepository(box);
});

final bodyMeasurementProvider = NotifierProvider<BodyMeasurementNotifier, List<BodyMeasurement>>(
  BodyMeasurementNotifier.new,
);

class BodyMeasurementNotifier extends Notifier<List<BodyMeasurement>> {
  late final BodyMeasurementRepository _repository;

  @override
  List<BodyMeasurement> build() {
    _repository = ref.watch(bodyMeasurementRepositoryProvider);
    return _repository.getAllMeasurements();
  }

  Future<void> saveMeasurement(BodyMeasurement measurement) async {
    await _repository.saveMeasurement(measurement);
    state = _repository.getAllMeasurements();
  }

  Future<void> deleteMeasurement(String id) async {
    await _repository.deleteMeasurement(id);
    state = _repository.getAllMeasurements();
  }
}
