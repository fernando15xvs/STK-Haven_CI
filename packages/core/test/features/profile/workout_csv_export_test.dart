import 'package:core/features/profile/application/workout_csv_export.dart';
import 'package:test/test.dart';

void main() {
  test('CSV export has the same UTF-8 BOM and stable columns for empty history', () {
    final csv = WorkoutCsvExport.encode([]);
    expect(csv.startsWith('\uFEFF'), true);
    expect(csv, contains('Fecha'));
    expect(csv, contains('Rutina'));
    expect(csv, contains('RIR'));
    expect(csv, contains('Descanso entre lados (s)'));
    final rows = WorkoutCsvExport.buildRows([]);
    expect(rows.length, 1);
    expect(rows.single.length, 19);
  });
}
