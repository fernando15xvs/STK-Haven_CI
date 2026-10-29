import 'dart:math' as math;
import 'body_anatomy_vector_data.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';

/// Maps existing *circumference* fields, not invented individual muscle sizes.
/// Weight and body-fat are deliberately not painted onto anatomical regions.
class SilhouetteMeasurement {
  final MeasurementMetric metric;
  final double value;
  final DateTime date;
  final double? previous;
  final DateTime? previousDate;

  const SilhouetteMeasurement(this.metric, this.value, this.date,
      this.previous, this.previousDate);

  double? get delta => previous == null ? null : value - previous!;
}

class SilhouetteMeasurementData {
  const SilhouetteMeasurementData._();

  static const metrics = <MeasurementMetric>[
    MeasurementMetric.shoulders,
    MeasurementMetric.chest,
    MeasurementMetric.waist,
    MeasurementMetric.hips,
    MeasurementMetric.leftArm,
    MeasurementMetric.rightArm,
    MeasurementMetric.leftLeg,
    MeasurementMetric.rightLeg,
    MeasurementMetric.calves,
  ];

  /// Each field uses its own latest valid record: entries may be partial.
  /// Compare against the previous distinct *date*, never another field.
  static SilhouetteMeasurement? latest(
      Iterable<BodyMeasurement> records, MeasurementMetric metric) {
    final values = <BodyMeasurement>[
      for (final record in records)
        if (metric.value(record) case final double value
            when value.isFinite && value > 0)
          record,
    ]..sort((a, b) => b.date.compareTo(a.date));
    if (values.isEmpty) return null;
    final newest = values.first;
    BodyMeasurement? prior;
    for (final record in values.skip(1)) {
      if (record.date.isBefore(newest.date)) {
        prior = record;
        break;
      }
    }
    return SilhouetteMeasurement(
      metric, metric.value(newest)!, newest.date,
      prior == null ? null : metric.value(prior),
      prior?.date,
    );
  }

  static String formatted(SilhouetteMeasurement? data) =>
      data == null ? 'Sin registro' : '${data.value.toStringAsFixed(1)} cm';
}

class _Spot {
  final MeasurementMetric metric;
  final double x;
  final double y;
  const _Spot(this.metric, this.x, this.y);
}

// The user's left appears on screen-right in the *front* view, and
// on screen-left in the *rear* view. Never swap stored left/right IDs.
const _frontSpots = <_Spot>[
  _Spot(MeasurementMetric.shoulders,100,85),
  _Spot(MeasurementMetric.chest,100,114),
  _Spot(MeasurementMetric.leftArm,153,152),
  _Spot(MeasurementMetric.rightArm,47,152),
  _Spot(MeasurementMetric.waist,100,177),
  _Spot(MeasurementMetric.hips,100,210),
  _Spot(MeasurementMetric.leftLeg,123,270),
  _Spot(MeasurementMetric.rightLeg,77,270),
  _Spot(MeasurementMetric.calves,77,366),
];
const _backSpots = <_Spot>[
  _Spot(MeasurementMetric.shoulders,100,85),
  _Spot(MeasurementMetric.leftArm,47,152),
  _Spot(MeasurementMetric.rightArm,153,152),
  _Spot(MeasurementMetric.waist,100,177),
  _Spot(MeasurementMetric.hips,100,210),
  _Spot(MeasurementMetric.leftLeg,77,270),
  _Spot(MeasurementMetric.rightLeg,123,270),
  _Spot(MeasurementMetric.calves,123,366),
];

/// Front and back visible simultaneously. Zones are interactive,
/// keyboard/screen-reader accessible, and follow app light/dark/accent.
class BodyMeasurementSilhouette extends StatelessWidget {
  final List<BodyMeasurement> measurements;
  final MeasurementMetric selected;
  final ValueChanged<MeasurementMetric> onSelected;
  const BodyMeasurementSilhouette({
    super.key,
    required this.measurements,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = SilhouetteMeasurementData.latest(measurements, selected);
    final history = MeasurementProgress(measurements, selected);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Mapa de medidas corporales',
            style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text('Selecciona una zona. Se muestran perímetros registrados, '
            'no el tamaño aislado de cada músculo.',
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start,children: [
            Expanded(child: _BodyView(
              key: const ValueKey('silhouette_front'),
              label: 'Frente',
              back: false,
              spots: _frontSpots,
              selected: selected,
              measurements: measurements,
              onSelected: onSelected,
            )),
            const SizedBox(width: 8),
            Expanded(child: _BodyView(
              key: const ValueKey('silhouette_back'),
              label: 'Espalda',
              back: true,
              spots: _backSpots,
              selected: selected,
              measurements: measurements,
              onSelected: onSelected,
            )),
          ]),
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('silhouette_selected_detail'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.26),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.20)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selected.label,
                  style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(SilhouetteMeasurementData.formatted(data),
                  key: const ValueKey('silhouette_selected_value'),
                  style: Theme.of(context).textTheme.titleLarge),
                if (data != null) ...[
                  Text('Registrado: ${DateFormat('dd/MM/yyyy').format(data.date)}',
                    style: Theme.of(context).textTheme.bodySmall),
                  if (data.previous != null)
                    Text('Anterior: ${data.previous!.toStringAsFixed(1)} cm'
                      ' · ${data.delta! >= 0 ? '+' : ''}'
                      '${data.delta!.toStringAsFixed(1)} cm',
                      key: const ValueKey('silhouette_delta')),
                ] else
                  Text('Todavía no has registrado esta medida.',
                    style: Theme.of(context).textTheme.bodySmall),
                if (history.points.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text('${history.points.length} '
                    '${history.points.length == 1 ? 'registro' : 'registros'}'
                    ' en el historial · Ver evolución debajo',
                    style: Theme.of(context).textTheme.bodySmall),
                ],
              ]),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6,runSpacing: 6,children: [
            for (final metric in SilhouetteMeasurementData.metrics)
              ActionChip(
                key: ValueKey('measure_chip_${metric.name}'),
                tooltip: metric.label,
                avatar: Icon(Icons.circle,
                  size: 11,
                  color: selected == metric ? scheme.primary
                    : SilhouetteMeasurementData.latest(measurements,metric) != null
                      ? scheme.tertiary : scheme.outline),
                label: Text('${metric.label}: '
                  '${SilhouetteMeasurementData.latest(measurements,metric)?.value.toStringAsFixed(1) ?? '—'}'
                  '${SilhouetteMeasurementData.latest(measurements,metric) == null ? '' : ' cm'}'),
                onPressed: () => onSelected(metric),
              ),
          ]),
          const SizedBox(height: 6),
          Text('Los gemelos tienen una única medida general; el registro '
            'actual no distingue pantorrilla izquierda y derecha. '
            'Un cambio de perímetro no demuestra por sí solo ganancia muscular.',
            style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

class _BodyView extends StatelessWidget {
  final bool back;
  final String label;
  final List<_Spot> spots;
  final MeasurementMetric selected;
  final List<BodyMeasurement> measurements;
  final ValueChanged<MeasurementMetric> onSelected;
  const _BodyView({
    super.key, required this.back, required this.label,
    required this.spots,required this.selected,
    required this.measurements,required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Text(label,style:Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 5),
      AspectRatio(
        aspectRatio: 200/440,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E5E9)),
              ),
            )),
            Positioned.fill(child: CustomPaint(
              painter: _AnatomyPainter(
                back: back, selected: selected,
                accent: scheme.primary,

              ),
            )),
            for (final spot in spots)
              Positioned(
                left: math.max(0, math.min(width-28, width*spot.x/200-14)),
                top: math.max(0, math.min(height-28, height*spot.y/440-14)),
                width:28, height:28,
                child: Semantics(
                  button: true,
                  label: '${back?'Espalda':'Frente'}, ${spot.metric.label}, '
                    '${SilhouetteMeasurementData.formatted(
                      SilhouetteMeasurementData.latest(measurements,spot.metric))}',
                  child: Tooltip(
                    message: spot.metric.label,
                    child: InkWell(
                      key: ValueKey('map_${back?'back':'front'}_${spot.metric.name}'),
                      borderRadius: BorderRadius.circular(30),
                      onTap: ()=>onSelected(spot.metric),
                      child: Center(child: AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        width: spot.metric==selected ? 15:9,
                        height: spot.metric==selected ? 15:9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:spot.metric==selected ? scheme.primary
                            : SilhouetteMeasurementData.latest(
                                measurements,spot.metric)!=null
                              ? scheme.tertiary : scheme.surface,
                          border: Border.all(color:scheme.onSurface,width:1.1),
                          boxShadow: [
                            BoxShadow(color:scheme.shadow.withValues(alpha:0.22),
                              blurRadius:3)
                          ],
                        ),
                      )),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      ),
    ]);
  }
}

/// The source SVG files in assets/measurement_anatomy are original artwork.
/// Paths are interpreted natively with Flutter Canvas to avoid raster blur or
/// adding an SVG rendering dependency to the shipped application.
/// Only absolute SVG M, L, Q and Z commands are allowed.
class _AnatomyPainter extends CustomPainter {
  final bool back;
  final MeasurementMetric selected;
  final Color accent;
  const _AnatomyPainter({required this.back, required this.selected,
    required this.accent});

  static final Map<String,Path> _pathCache = <String,Path>{};
  static final RegExp _tokens = RegExp(r'[MLQZ]|-?(?:\d+(?:\.\d+)?|\.\d+)');

  static Path _pathFromSvg(String data) => _pathCache.putIfAbsent(data, () {
    final values = _tokens.allMatches(data).map((m) => m.group(0)!).toList();
    final path = Path();
    var i = 0;
    while (i < values.length) {
      final command = values[i++];
      switch (command) {
        case 'M':
          path.moveTo(double.parse(values[i++]),double.parse(values[i++]));
        case 'L':
          path.lineTo(double.parse(values[i++]),double.parse(values[i++]));
        case 'Q':
          final x1 = double.parse(values[i++]);
          final y1 = double.parse(values[i++]);
          path.quadraticBezierTo(x1,y1,double.parse(values[i++]),
            double.parse(values[i++]));
        case 'Z':
          path.close();
        default:
          throw FormatException('Unsupported anatomical SVG path token: $command');
      }
    }
    return path;
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 440);
    final anatomyInk = const Color(0xFF111318);
    final seam = const Color(0xFFF6F8FA);
    final shapePaint = Paint()
      ..color = anatomyInk
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final borderPaint = Paint()
      ..color = seam
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // The character head is a single clean silhouette: no placeholder
    // geometric limbs. Every muscle contour below is vector path art.
    canvas.drawOval(const Rect.fromLTWH(84,11,32,46),shapePaint);
    final contours = back ? anatomyBackContours : anatomyFrontContours;
    for (final contour in contours) {
      canvas.save();
      if (contour.mirrored) {
        canvas.translate(200,0);
        canvas.scale(-1,1);
      }
      final path = _pathFromSvg(contour.d);
      if (contour.solid) {
        canvas.drawPath(path,shapePaint);
      }
      borderPaint.strokeWidth = contour.width;
      canvas.drawPath(path,borderPaint);
      canvas.restore();
    }

    // Small transparent outline, not a painted muscle or fake change in
    // actual body shape. Uses the existing saved circumferences only.
    final regions = <MeasurementMetric,Rect>{
      MeasurementMetric.shoulders:
        Rect.fromCenter(center:const Offset(100,85),width:81,height:28),
      MeasurementMetric.chest:
        Rect.fromCenter(center:const Offset(100,114),width:74,height:30),
      MeasurementMetric.waist:
        Rect.fromCenter(center:const Offset(100,177),width:48,height:29),
      MeasurementMetric.hips:
        Rect.fromCenter(center:const Offset(100,210),width:62,height:32),
      MeasurementMetric.leftArm:
        Rect.fromCenter(center:Offset(back?47:153,153),width:21,height:47),
      MeasurementMetric.rightArm:
        Rect.fromCenter(center:Offset(back?153:47,153),width:21,height:47),
      MeasurementMetric.leftLeg:
        Rect.fromCenter(center:Offset(back?77:123,270),width:30,height:53),
      MeasurementMetric.rightLeg:
        Rect.fromCenter(center:Offset(back?123:77,270),width:30,height:53),
      MeasurementMetric.calves:
        Rect.fromCenter(center:const Offset(100,365),width:79,height:38),
    };
    final region = regions[selected];
    if (region != null) {
      canvas.drawOval(region,Paint()
        ..color = accent.withValues(alpha:0.13)
        ..style = PaintingStyle.fill);
      canvas.drawOval(region,Paint()
        ..color = accent.withValues(alpha:0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..isAntiAlias = true);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AnatomyPainter previous) =>
      previous.back != back ||
      previous.selected != selected ||
      previous.accent != accent;
}
