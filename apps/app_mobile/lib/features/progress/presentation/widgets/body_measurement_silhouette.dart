import 'dart:math' as math;
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
  _Spot(MeasurementMetric.shoulders, 80, 82),
  _Spot(MeasurementMetric.chest, 80, 116),
  _Spot(MeasurementMetric.leftArm, 124, 139),
  _Spot(MeasurementMetric.rightArm, 36, 139),
  _Spot(MeasurementMetric.waist, 80, 169),
  _Spot(MeasurementMetric.hips, 80, 202),
  _Spot(MeasurementMetric.leftLeg, 100, 244),
  _Spot(MeasurementMetric.rightLeg, 60, 244),
  _Spot(MeasurementMetric.calves, 61, 298),
];
const _backSpots = <_Spot>[
  _Spot(MeasurementMetric.shoulders, 80, 82),
  _Spot(MeasurementMetric.leftArm, 36, 139),
  _Spot(MeasurementMetric.rightArm, 124, 139),
  _Spot(MeasurementMetric.waist, 80, 169),
  _Spot(MeasurementMetric.hips, 80, 203),
  _Spot(MeasurementMetric.leftLeg, 61, 245),
  _Spot(MeasurementMetric.rightLeg, 99, 245),
  _Spot(MeasurementMetric.calves, 99, 298),
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
        aspectRatio: 160/340,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(child: CustomPaint(
              painter: _AnatomyPainter(
                back: back, selected: selected,
                accent: scheme.primary,
                filled: scheme.onSurface.withValues(alpha:0.81),
                seam: scheme.surface,
                low: scheme.onSurface.withValues(alpha:0.13),
              ),
            )),
            for (final spot in spots)
              Positioned(
                left: math.max(0, math.min(width-28, width*spot.x/160-14)),
                top: math.max(0, math.min(height-28, height*spot.y/340-14)),
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
                        width: spot.metric==selected ? 17:12,
                        height: spot.metric==selected ? 17:12,
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

/// Original anatomical vector silhouette, drawn entirely in Flutter.
/// No Shutterstock/stock image or external copyrighted asset is embedded.
class _AnatomyPainter extends CustomPainter {
  final bool back;
  final MeasurementMetric selected;
  final Color accent, filled, seam, low;
  const _AnatomyPainter({
    required this.back,required this.selected,
    required this.accent,required this.filled,
    required this.seam,required this.low,
  });

  @override
  void paint(Canvas canvas,Size size) {
    canvas.save();
    canvas.scale(size.width/160,size.height/340);
    final stroke=Paint()
      ..color=seam.withValues(alpha:0.80)
      ..strokeWidth=1.5
      ..strokeCap=StrokeCap.round
      ..style=PaintingStyle.stroke;
    final body=Paint()..color=filled..isAntiAlias=true;
    final inner=Paint()..color=low..isAntiAlias=true;

    void shape(List<Offset> points,{Color? color}) {
      final path=Path()..addPolygon(points,true);
      canvas.drawPath(path,Paint()..color=(color??filled)..isAntiAlias=true);
      canvas.drawPath(path,stroke);
    }
    Offset o(double x,double y)=>Offset(x,y);
    void oval(double x,double y,double w,double h,{Color? color}) {
      final rect=Rect.fromCenter(center:o(x,y),width:w,height:h);
      canvas.drawOval(rect,Paint()..color=(color??filled)..isAntiAlias=true);
      canvas.drawOval(rect,stroke);
    }
    void vein(List<Offset> pts) {
      final p=Path()..moveTo(pts.first.dx,pts.first.dy);
      for(final point in pts.skip(1))p.lineTo(point.dx,point.dy);
      canvas.drawPath(p,stroke);
    }

    // All paths are mirrored around the midline and share a 160x340
    // coordinate system. Fingers and toes are distinct from limb tubes.
    oval(80,29,38,46);
    shape([o(73,49),o(87,49),o(91,68),o(69,68)]);
    for(final side in [-1.0,1.0]) {
      double x(double offset)=>80+side*offset;
      // Arm: deltoid, biceps/triceps, forearm and separated hand.
      shape([o(x(38),76),o(x(52),80),o(x(57),100),
        o(x(59),123),o(x(50),131),o(x(43),111),o(x(35),97)]);
      shape([o(x(50),124),o(x(60),125),o(x(64),159),
        o(x(59),171),o(x(50),165),o(x(45),142)]);
      shape([o(x(58),170),o(x(67),168),o(x(70),192),
        o(x(68),213),o(x(62),220),o(x(60),210),o(x(56),188)]);
      // Five fingers are implicit, but still individually articulated by seams.
      vein([o(x(63),201),o(x(65),216)]);
      vein([o(x(66),201),o(x(68),213)]);
      // Thigh and knee.
      shape([o(x(7),190),o(x(33),190),o(x(34),222),
        o(x(26),265),o(x(15),270),o(x(8),248)]);
      oval(x(21),267,19,15);
      // Calf, Achilles and foot.
      shape([o(x(13),275),o(x(28),274),o(x(30),296),
        o(x(25),322),o(x(24),329),o(x(17),329),
        o(x(16),306)]);
      shape([o(x(16),324),o(x(25),324),o(x(33),335),
        o(x(31),339),o(x(12),339),o(x(11),334)]);
    }
    // Torso, rib cage, waist and pelvis.
    shape([o(47,72),o(65,64),o(95,64),o(113,72),o(118,103),
      o(105,136),o(100,165),o(113,191),o(108,210),
      o(83,217),o(77,217),o(52,210),o(47,191),
      o(60,165),o(55,136),o(42,103)]);
    // Neck to clavicle or trapezius: different anatomical surfaces.
    if(back) {
      shape([o(73,62),o(87,62),o(108,77),
        o(92,107),o(80,119),o(68,107),o(52,77)],color:low);
      shape([o(43,111),o(63,115),o(78,127),o(68,159),
        o(54,150)],color:low);
      shape([o(117,111),o(97,115),o(82,127),o(92,159),
        o(106,150)],color:low);
      vein([o(80,66),o(80,180)]);
      oval(63,199,39,32,color:low);
      oval(97,199,39,32,color:low);
      vein([o(53,188),o(80,181),o(107,188)]);
    }else{
      shape([o(49,86),o(75,94),o(77,121),o(66,132),
        o(48,111)],color:low);
      shape([o(111,86),o(85,94),o(83,121),o(94,132),
        o(112,111)],color:low);
      vein([o(80,93),o(80,142)]);
      for(final y in [143.0,155.0,167.0]) {
        vein([o(69,y),o(80,y+2),o(91,y)]);
      }
      vein([o(64,137),o(58,167),o(75,182)]);
      vein([o(96,137),o(102,167),o(85,182)]);
      vein([o(80,183),o(80,211)]);
    }
    // Highlight the selected recorded perimeter zone, not an anatomical
    // muscle size. Do not change geometric scale based on circumference.
    final highlight=Paint()
      ..color=accent.withValues(alpha:0.26)
      ..style=PaintingStyle.fill;
    final regions=<MeasurementMetric,Rect>{
      MeasurementMetric.shoulders:Rect.fromCenter(center:o(80,82),width:77,height:18),
      MeasurementMetric.chest:Rect.fromCenter(center:o(80,112),width:72,height:32),
      MeasurementMetric.waist:Rect.fromCenter(center:o(80,169),width:48,height:27),
      MeasurementMetric.hips:Rect.fromCenter(center:o(80,201),width:65,height:29),
      MeasurementMetric.leftArm:Rect.fromCenter(
        center:o(back?38:122,139),width:21,height:56),
      MeasurementMetric.rightArm:Rect.fromCenter(
        center:o(back?122:38,139),width:21,height:56),
      MeasurementMetric.leftLeg:Rect.fromCenter(
        center:o(back?61:99,242),width:23,height:50),
      MeasurementMetric.rightLeg:Rect.fromCenter(
        center:o(back?99:61,242),width:23,height:50),
      MeasurementMetric.calves:Rect.fromCenter(center:o(80,297),width:79,height:43),
    };
    final rect=regions[selected];
    if(rect!=null)canvas.drawOval(rect,highlight);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AnatomyPainter old)=>
    old.back!=back||old.selected!=selected||old.accent!=accent||
    old.filled!=filled||old.seam!=seam||old.low!=low;
}
