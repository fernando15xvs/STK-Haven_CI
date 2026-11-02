import 'package:core/core/theme/app_palette.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:flutter/material.dart';

/// Independent latest observation for partial records. Historical measurements
/// are never interpreted as zero and future measurements are not invented.
class SummaryObservation {
  final double value;
  final DateTime date;
  final double? previous;
  const SummaryObservation(this.value, this.date, this.previous);

  double? get difference => previous == null ? null : value - previous!;
}

class MeasurementSummaryData {
  const MeasurementSummaryData._();

  static SummaryObservation? latest(
    Iterable<BodyMeasurement> measurements,
    double? Function(BodyMeasurement) valueOf,
  ) {
    final entries = <({DateTime date, double value})>[
      for (final measurement in measurements)
        if (valueOf(measurement) case final double v
            when v.isFinite && v > 0)
          (date: measurement.date, value: v),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (entries.isEmpty) return null;
    final current = entries.first;
    double? previous;
    for (final entry in entries.skip(1)) {
      if (entry.date.isBefore(current.date)) {
        previous = entry.value;
        break;
      }
    }
    return SummaryObservation(current.value, current.date, previous);
  }

  static SummaryObservation? weight(Iterable<BodyMeasurement> values) =>
      latest(values, (m) => m.weightKg);
  static SummaryObservation? fat(Iterable<BodyMeasurement> values) =>
      latest(values, (m) => m.bodyFatPercentage);
  static SummaryObservation? height(Iterable<BodyMeasurement> values) =>
      latest(values, (m) => m.heightCm);

  /// Compute the ratio only from a single recording, never by joining a
  /// waist from one date to hips from a different date.
  static SummaryObservation? waistHipRatio(Iterable<BodyMeasurement> values) =>
      latest(values, (m) {
        final waist = m.waistCm, hips = m.hipsCm;
        if (waist == null || hips == null || !waist.isFinite ||
            !hips.isFinite || waist <= 0 || hips <= 0) {
          return null;
        }
        return waist / hips;
      });
}

/// Reference-style dashboard beneath the front/back muscle figure.
/// Four tiles wrap to 2x2 on phones; all text and accents remain theme aware.
class BodyMeasurementSummary extends StatelessWidget {
  final List<BodyMeasurement> measurements;
  final WeightUnit weightUnit;
  const BodyMeasurementSummary({
    super.key,
    required this.measurements,
    required this.weightUnit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final weight = MeasurementSummaryData.weight(measurements);
    final fat = MeasurementSummaryData.fat(measurements);
    final ratio = MeasurementSummaryData.waistHipRatio(measurements);
    final height = MeasurementSummaryData.height(measurements);

    String weightValue(SummaryObservation? v) => v == null
        ? '—'
        : WeightConverter.displayWeight(v.value, weightUnit)
            .toStringAsFixed(1);
    String change(SummaryObservation? v, {double Function(double)? convert}) {
      if (v?.difference == null) return 'Sin comparación';
      final delta = convert == null ? v!.difference! : convert(v!.difference!);
      if (delta == 0) return 'Sin cambio';
      return '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}';
    }

    return Card(
      key: const Key('measurement_summary'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('Resumen de medidas',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800))),
              Icon(Icons.insights_outlined, size: 20, color: colors.primary),
            ]),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: tileWidth, child: _SummaryTile(
                    testKey: 'summary_weight',
                    icon: Icons.monitor_weight_outlined,
                    title: 'Peso',
                    value: weightValue(weight),
                    suffix: weight == null ? '' : weightUnit.label,
                    supporting: weight == null
                      ? 'Sin registro'
                      : '${change(weight,
                            convert: (v) => WeightConverter.displayWeight(v, weightUnit))} ${weightUnit.label}',
                    colors: colors,
                  )),
                  SizedBox(width: tileWidth, child: _SummaryTile(
                    testKey: 'summary_fat',
                    icon: Icons.percent_rounded,
                    title: 'Grasa corporal',
                    value: fat == null ? '—' : fat.value.toStringAsFixed(1),
                    suffix: fat == null ? '' : '%',
                    supporting: fat == null ? 'Sin registro'
                      : '${change(fat)} puntos',
                    colors: colors,
                  )),
                  SizedBox(width: tileWidth, child: _SummaryTile(
                    testKey: 'summary_waist_hip',
                    icon: Icons.accessibility_new_rounded,
                    title: 'Cintura / cadera',
                    value: ratio == null ? '—' : ratio.value.toStringAsFixed(2),
                    suffix: '',
                    supporting: ratio == null
                        ? 'Registra ambas juntas' : 'Misma fecha',
                    colors: colors,
                  )),
                  SizedBox(width: tileWidth, child: _SummaryTile(
                    testKey: 'summary_height',
                    icon: Icons.height_rounded,
                    title: 'Altura',
                    value: height == null ? '—' : height.value.toStringAsFixed(1),
                    suffix: height == null ? '' : 'cm',
                    supporting: height == null
                      ? 'Agrégala en Nueva medida' : 'Última altura registrada',
                    colors: colors,
                  )),
                ],
              );
            }),
            const SizedBox(height: 12),
            Text(
              'Datos reales de tus registros. La relación cintura/cadera '
              'solo aparece cuando ambas medidas se guardaron juntas.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String testKey;
  final IconData icon;
  final String title;
  final String value;
  final String suffix;
  final String supporting;
  final AppColors colors;
  const _SummaryTile({
    required this.testKey,
    required this.icon,
    required this.title,
    required this.value,
    required this.suffix,
    required this.supporting,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(testKey),
      height: 119,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: colors.primary, size: 18),
            const SizedBox(width: 5),
            Expanded(child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.textSecondary),
            )),
          ]),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$value${suffix.isEmpty ? '' : ' $suffix'}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          const Spacer(),
          Text(supporting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
