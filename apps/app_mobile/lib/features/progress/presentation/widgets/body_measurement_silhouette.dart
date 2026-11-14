import 'dart:math' as math;

import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';
import 'package:flutter/material.dart';
import 'package:core/core/theme/app_palette.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

/// Only actual recorded circumferences are allowed here.
/// A given record may contain only one field: each metric uses its own
/// most recent valid observation (never fabricated interpolations).
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
    MeasurementMetric.neck,
    MeasurementMetric.shoulders,
    MeasurementMetric.chest,
    MeasurementMetric.leftArm,
    MeasurementMetric.rightArm,
    MeasurementMetric.leftForearm,
    MeasurementMetric.rightForearm,
    MeasurementMetric.leftLeg,
    MeasurementMetric.rightLeg,
    MeasurementMetric.waist,
    MeasurementMetric.hips,
    MeasurementMetric.leftCalf,
    MeasurementMetric.rightCalf,
  ];

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
    BodyMeasurement? previous;
    for (final record in values.skip(1)) {
      if (record.date.isBefore(newest.date)) {
        previous = record;
        break;
      }
    }
    return SilhouetteMeasurement(
      metric, metric.value(newest)!, newest.date,
      previous == null ? null : metric.value(previous),
      previous?.date,
    );
  }

  static String formatted(SilhouetteMeasurement? value) =>
      value == null ? 'Sin registro' : '${value.value.toStringAsFixed(1)} cm';
}

/// Geometry is normalized to the whole image area (transparent PNG).
/// The user's LEFT is on the right when viewed from the FRONT.
class _Callout {
  final MeasurementMetric metric;
  final String shortName;
  final bool labelLeft;
  final double row;
  final Offset anchor;
  const _Callout(this.metric, this.shortName, this.labelLeft,
      this.row, this.anchor);
}

// Independent front/rear tape contours; avoid duplicated measurements.
// Anchors are NORMALIZED TO THE DISPLAYED ANATOMY IMAGE, not the full card.
// Calibrated against the source front/back plates and the user's iPhone
// captures. Each dot names a measurement contour, not an isolated muscle.
// Front is mirrored anatomically: the person's right is image left.
// MeasurementMetric is the authoritative contorno identifier; never invent
// measurements named "Espalda" or "Glúteos" from illustration labels.
const _front = <_Callout>[
  _Callout(MeasurementMetric.neck, 'Cuello', true, .085, Offset(.50, .166)),
  _Callout(MeasurementMetric.shoulders, 'Hombros', false, .160, Offset(.82, .190)),
  _Callout(MeasurementMetric.chest, 'Tórax', true, .265, Offset(.50, .245)),
  _Callout(MeasurementMetric.rightArm, 'Brazo der.', true, .410, Offset(.215, .300)),
  _Callout(MeasurementMetric.leftArm, 'Brazo izq.', false, .405, Offset(.785, .300)),
  _Callout(MeasurementMetric.rightLeg, 'Muslo der.', true, .720, Offset(.415, .535)),
  _Callout(MeasurementMetric.leftLeg, 'Muslo izq.', false, .720, Offset(.585, .535)),
];

const _rear = <_Callout>[
  // Viewed from behind, the person's right side is on the image right.
  _Callout(MeasurementMetric.leftForearm, 'Ant. izq.', true, .260, Offset(.19, .385)),
  _Callout(MeasurementMetric.rightForearm, 'Ant. der.', false, .270, Offset(.81, .385)),
  _Callout(MeasurementMetric.waist, 'Cintura', true, .490, Offset(.50, .360)),
  _Callout(MeasurementMetric.hips, 'Cadera', false, .535, Offset(.54, .460)),
  _Callout(MeasurementMetric.leftCalf, 'Pant. izq.', true, .790, Offset(.40, .730)),
  _Callout(MeasurementMetric.rightCalf, 'Pant. der.', false, .790, Offset(.60, .730)),
];

/// A single authentic anatomical PNG, side labels and leader-lines.
/// Nothing (including cm values) is baked into the PNG asset.
class BodyMeasurementSilhouette extends StatefulWidget {
  final List<BodyMeasurement> measurements;
  final MeasurementMetric selected;
  final ValueChanged<MeasurementMetric> onSelected;
  final VoidCallback? onAddMeasurement;
  final VoidCallback? onHistory;

  const BodyMeasurementSilhouette({
    super.key,
    required this.measurements,
    required this.selected,
    required this.onSelected,
    this.onAddMeasurement,
    this.onHistory,
  });

  @override
  State<BodyMeasurementSilhouette> createState() =>
      _BodyMeasurementSilhouetteState();
}

class _BodyMeasurementSilhouetteState extends State<BodyMeasurementSilhouette> {
  bool _back = false;

  void _open(MeasurementMetric metric) {
    widget.onSelected(metric);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeasurementMuscleDetailPage(
          metric: metric,
          measurements: widget.measurements,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final accent = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Medidas corporales',
              style: AppTypography.headlineSmall)),
            if (widget.onAddMeasurement != null)
              TextButton.icon(
                key: const Key('measurement_add_button'),
                onPressed: widget.onAddMeasurement,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Nueva'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
          SegmentedButton<bool>(
            key: const Key('measurement_view_switch'),
            segments: const [
              ButtonSegment(value:false,label:Text('Frente')),
              ButtonSegment(value:true,label:Text('Espalda')),
            ],
            selected: {_back},
            onSelectionChanged: (values) {
              final nextBack = values.first;
              setState(() => _back = nextBack);
              final positions = nextBack ? _rear : _front;
              if (!positions.any((entry) => entry.metric == widget.selected)) {
                widget.onSelected(nextBack
                    ? MeasurementMetric.waist : MeasurementMetric.chest);
              }
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? accent.primaryFaded : accent.surfaceHigh),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? accent.primary : accent.textPrimary),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            key: Key(_back ? 'silhouette_back' : 'silhouette_front'),
            color: accent.surface,
            child: LayoutBuilder(builder: (context, limits) {
              // The anatomical PNG has a 0.4 width/height ratio. Reserve
              // generous outer margins for readable left/right callouts.
              final w = limits.maxWidth;
              // Callouts must grow with accessibility text instead of
              // clipping two rows in a hard-coded 42px badge. Increase
              // canvas height enough to avoid same-side overlap at 320px.
              final scaler = MediaQuery.textScalerOf(context);
              final labelHeight = math.max(
                42.0,
                scaler.scale(AppTypography.labelSmall.fontSize!) *
                    AppTypography.labelSmall.height! +
                    scaler.scale(AppTypography.bodySmall.fontSize!) *
                    AppTypography.bodySmall.height! +
                    AppSpacing.xxs * 2 + AppSpacing.xs,
              );
              final h = math.max(
                math.max(405.0, labelHeight / 0.11),
                math.min(570.0, w * 1.43),
              );
              // Keep the actual PNG coordinate space at its intrinsic 0.4
              // width/height ratio. Previously the Image used BoxFit.contain
              // while dots used the full, stretched slot: at 160% text the
              // empty letterbox grew and markers drifted off the anatomy.
              const anatomyAspect = .4;
              final figureWidth = math.min(w * .57, h * .95 * anatomyAspect);
              final figureHeight = figureWidth / anatomyAspect;
              final figureLeft = (w - figureWidth) / 2;
              final figureTop = (h - figureHeight) / 2;
              final positions = _back ? _rear : _front;
              // Only draw leader lines for labels that really exist.
              // Every anatomical point remains interactive, even without data.
              final visible = [
                for (var i = 0; i < positions.length; i++)
                  if (SilhouetteMeasurementData.latest(
                        widget.measurements, positions[i].metric) != null) i,
              ];
              final ink = accent.primary;
              // Compact screens need wider labels when the user requests
              // larger accessibility text, without shrinking Outfit glyphs.
              final badgeWidth = w * (w < 360 ? .30 : .265);
              final anchors = [
                for (final c in positions)
                  Offset(figureLeft + c.anchor.dx * figureWidth,
                    figureTop + c.anchor.dy * figureHeight),
              ];
              final ends = [
                for (final i in visible)
                  Offset(positions[i].labelLeft
                      ? badgeWidth + 3 : w - badgeWidth - 3,
                    positions[i].row * h + labelHeight * .5),
              ];
              return SizedBox(
                height: h,
                child: Stack(children: [
                  Positioned(
                    left:figureLeft, top:figureTop,
                    width:figureWidth,height:figureHeight,
                    child: Image.asset(
                      _back
                        ? 'assets/measurement_anatomy/png/body_back.png'
                        : 'assets/measurement_anatomy/png/body_front.png',
                      key: const Key('measurement_anatomy_png'),
                      fit:BoxFit.contain,
                      filterQuality:FilterQuality.high,
                      semanticLabel: _back
                          ? 'Anatomía muscular posterior'
                          : 'Anatomía muscular frontal',
                    ),
                  ),
                  Positioned.fill(child:IgnorePointer(child:CustomPaint(
                    painter:_LeaderLines(
                      anchors:[for(final i in visible) anchors[i]],
                      ends:ends,color:ink),
                  ))),
                  // Show all recorded contorno values as compact badges;
                  // still allow opening every unrecorded contour via its dot.
                  for (final i in visible)
                    Positioned(
                      left:positions[i].labelLeft ? 3 : w-badgeWidth-3,
                      top:positions[i].row*h,
                      width:badgeWidth,
                      height:labelHeight,
                      child: _MeasureCalloutBadge(
                        key:Key('measure_chip_${positions[i].metric.name}'),
                        metric:positions[i].metric,
                        shortName:positions[i].shortName,
                        value:SilhouetteMeasurementData.latest(
                          widget.measurements,positions[i].metric),
                        selected:widget.selected == positions[i].metric,
                        onPressed:()=>_open(positions[i].metric),
                      ),
                    ),
                  for(var i=0;i<positions.length;i++)
                    Positioned(
                      key: Key('map_${_back?'back':'front'}_${positions[i].metric.name}'),
                      left:anchors[i].dx-22,top:anchors[i].dy-22,
                      width:44,height:44,
                      child:Semantics(
                        button:true,
                        label:'${positions[i].metric.label}, '
                          '${SilhouetteMeasurementData.formatted(
                            SilhouetteMeasurementData.latest(
                              widget.measurements,positions[i].metric))}',
                        child:InkResponse(
                          radius:22,
                          onTap:()=>_open(positions[i].metric),
                          child:Center(child:Container(
                            width:widget.selected==positions[i].metric?13:10,
                            height:widget.selected==positions[i].metric?13:10,
                            decoration:BoxDecoration(
                              shape:BoxShape.circle,
                              color:ink,
                              border:Border.all(color:accent.surface,width:1.6),
                              
                            ),
                          )),
                        ),
                      ),
                    ),
                ]),
              );
            }),
          ),
          if (widget.onHistory != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                key: const Key('measurement_history_button'),
                onPressed: widget.onHistory,
                icon: const Icon(Icons.history_rounded),
                label: const Text('Ver historial'),
              ),
            ),
          ],
          Text(
            'Toca cualquier punto para consultar su perímetro, '
            'aunque todavía no tenga registros.',
            style: AppTypography.bodySmall.copyWith(
              color: accent.textSecondary),
          ),
        ],
      );

  }
}

class _MeasureCalloutBadge extends StatelessWidget {
  final MeasurementMetric metric;
  final String shortName;
  final SilhouetteMeasurement? value;
  final bool selected;
  final VoidCallback onPressed;
  const _MeasureCalloutBadge({
    super.key,required this.metric,required this.shortName,
    required this.value,required this.selected,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final foreground = selected ? palette.onPrimary : palette.textPrimary;
    return Semantics(
      button: true,
      label: '${metric.label}: ${SilhouetteMeasurementData.formatted(value)}',
      child: Material(
        color: selected ? palette.primary : palette.surfaceHigh,
        borderRadius: AppRadius.sm_,
        child: InkWell(
          borderRadius: AppRadius.sm_,
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.sm_,
              border: Border.all(
                color: selected ? palette.primary : palette.surfaceBorder,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
              vertical: AppSpacing.xxs,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(color: foreground),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value == null ? '—' : '${value!.value.toStringAsFixed(1)} cm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation('wght', 700)],
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: selected ? palette.onPrimary : palette.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderLines extends CustomPainter {
  final List<Offset> anchors,ends;
  final Color color;
  const _LeaderLines({required this.anchors,
    required this.ends,required this.color});
  @override
  void paint(Canvas canvas,Size size){
    final pen=Paint()
      ..color=color.withValues(alpha:.90)
      ..strokeWidth=1.7
      ..strokeCap=StrokeCap.round
      ..style=PaintingStyle.stroke;
    for(var i=0;i<anchors.length;i++) {
      final a=anchors[i],e=ends[i];
      final knee=Offset(e.dx+(a.dx-e.dx)*.43,e.dy);
      canvas.drawPath(Path()..moveTo(e.dx,e.dy)
        ..lineTo(knee.dx,knee.dy)
        ..lineTo(a.dx,a.dy),pen);
    }
  }
  @override
  bool shouldRepaint(covariant _LeaderLines old) =>
    old.anchors!=anchors||old.ends!=ends||old.color!=color;
}

/// Dedicated page: PNG muscle crop, exact recorded values, recent entries
/// and a chart in the currently selected app theme/accent.
class MeasurementMuscleDetailPage extends StatelessWidget {
  final MeasurementMetric metric;
  final List<BodyMeasurement> measurements;
  const MeasurementMuscleDetailPage({
    super.key,required this.metric,required this.measurements,
  });

  @override
  Widget build(BuildContext context) {
    final scheme=Theme.of(context).colorScheme;
    final value=SilhouetteMeasurementData.latest(measurements,metric);
    final progress=MeasurementProgress(measurements,metric);
    // History chart progresses chronologically from left to right.
    // Recent records are listed newest-first in their own section.
    final chartPoints = progress.points;
    final records = chartPoints.reversed.toList();
    final detailKey = switch (metric) {
      MeasurementMetric.shoulders => 'shoulders',
      MeasurementMetric.chest => 'chest',
      MeasurementMetric.waist => 'waist',
      MeasurementMetric.hips => 'hips',
      MeasurementMetric.leftArm => 'left_arm',
      MeasurementMetric.rightArm => 'right_arm',
      MeasurementMetric.leftLeg => 'left_leg',
      MeasurementMetric.rightLeg => 'right_leg',
      MeasurementMetric.calves => 'calves',
      _ => null, // New metric image is the complete original anatomy.
    };
    return Scaffold(
      appBar:AppBar(title:Text(metric.label)),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Container(
          key:const Key('measurement_detail_anatomy'),
          height:220,
          clipBehavior:Clip.antiAlias,
          decoration:BoxDecoration(
            color:scheme.brightness==Brightness.dark
                ? const Color(0xFF101722):const Color(0xFFF4F6F9),
            borderRadius:BorderRadius.circular(18)),
          child:Image.asset(
            detailKey == null
               ? (metric == MeasurementMetric.leftCalf || metric == MeasurementMetric.rightCalf
                   ? 'assets/measurement_anatomy/png/body_back.png'
                   : 'assets/measurement_anatomy/png/body_front.png')
               : 'assets/measurement_anatomy/png/detail_$detailKey.png',
            semanticLabel:'Región anatómica destacada: ${metric.label}',
            fit:BoxFit.contain,
          ),
        ),
        const SizedBox(height:12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Medida actual', style: AppTypography.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  SilhouetteMeasurementData.formatted(value),
                  key: const Key('measurement_detail_value'),
                  style: AppTypography.headlineLarge,
                ),
                if (value != null) ...[
                  const SizedBox(height: 12),
                  Text('Registrado el', style: AppTypography.labelMedium),
                  Text(DateFormat('dd/MM/yyyy').format(value.date),
                    style: AppTypography.bodyMedium),
                  const SizedBox(height: 10),
                  Text('Medida anterior', style: AppTypography.labelMedium),
                  Text(
                    value.previous == null
                        ? 'Sin comparación'
                        : '${value.previous!.toStringAsFixed(1)} cm',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Cambio vs. anterior',
                    style: AppTypography.labelMedium),
                  Text(
                    value.delta == null ? 'Sin comparación'
                      : value.delta!.abs() < .05 ? 'Sin cambio'
                      : '${value.delta! > 0 ? '+' : ''}${value.delta!.toStringAsFixed(1)} cm',
                    key: const Key('measurement_detail_delta'),
                    style: AppTypography.bodyMedium,
                  ),
                ] else const Text('Sin registros todavía.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Historial', style: AppTypography.headlineSmall),
                const SizedBox(height: 12),
                if (progress.canCompare)
                  _MeasurementHistoryChart(points: chartPoints)
                else
                  Text(
                    'Registra esta medida en dos fechas distintas para ver su evolución.',
                    style: AppTypography.bodySmall,
                  ),
                const SizedBox(height: 14),
                Text('Registros recientes', style: AppTypography.labelLarge),
                for (var i = 0; i < math.min(records.length, 12); i++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${records[i].value.toStringAsFixed(1)} cm',
                      style: AppTypography.bodyMedium,
                    ),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(records[i].date),
                      style: AppTypography.bodySmall,
                    ),
                    trailing: i + 1 < records.length &&
                            records[i].date.isAfter(records[i + 1].date)
                        ? Text(
                            (records[i].value-records[i + 1].value).abs() < .05
                                ? 'Sin cambio'
                                : '${records[i].value > records[i + 1].value ? '+' : ''}${(records[i].value-records[i + 1].value).toStringAsFixed(1)} cm',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.of(context).textSecondary,
                            ),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height:12),
        Text(_measureInstructions(metric),style:Theme.of(context).textTheme.bodyMedium),
         const SizedBox(height:8),
         Text('Se muestra el perímetro que registraste, no el tamaño '
          'individual de un músculo. Más centímetros no siempre implican '
          'ganancia muscular.',
          style:Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

/// Tappable, chronological measurement history; selection never changes
/// the underlying recorded observations or their order.
class _MeasurementHistoryChart extends StatefulWidget {
  final List<MeasurementPoint> points;
  const _MeasurementHistoryChart({required this.points});

  @override
  State<_MeasurementHistoryChart> createState() =>
      _MeasurementHistoryChartState();
}

class _MeasurementHistoryChartState extends State<_MeasurementHistoryChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final index = (_selectedIndex ?? (points.length - 1))
        .clamp(0, points.length - 1);
    final selected = points[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, limits) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final usefulWidth = math.max(1.0, limits.maxWidth - 32);
              final percent =
                  ((details.localPosition.dx - 16) / usefulWidth).clamp(0.0, 1.0);
              setState(() {
                _selectedIndex =
                    (percent * (points.length - 1)).round();
              });
            },
            child: SizedBox(
              height: 150,
              child: CustomPaint(
                key: const Key('measurement_detail_chart'),
                painter: _MetricHistoryPainter(
                  points, AppColors.of(context).primary, index),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('dd/MM/yyyy').format(points.first.date),
              style: AppTypography.labelSmall),
            Text(DateFormat('dd/MM/yyyy').format(points.last.date),
              style: AppTypography.labelSmall),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${selected.value.toStringAsFixed(1)} cm · ${DateFormat('dd/MM/yyyy').format(selected.date)}',
          key: const Key('measurement_chart_selected_record'),
          style: AppTypography.labelMedium,
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}

class _MetricHistoryPainter extends CustomPainter {
  final List<MeasurementPoint> points;
  final Color color;
  final int selectedIndex;
  const _MetricHistoryPainter(this.points, this.color, this.selectedIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final values = points.map((p) => p.value);
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(1.0, maxValue - minValue);
    final grid = Paint()
      ..color = color.withValues(alpha: .12)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = 16 + (size.height - 32) * i / 3;
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), grid);
    }

    Offset pointAt(int i) => Offset(
      16 + (size.width - 32) * i / (points.length - 1),
      size.height - 16 -
        (points[i].value - minValue) / range * (size.height - 32),
    );
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < points.length; i++) {
      final p = pointAt(i);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);
    for (var i = 0; i < points.length; i++) {
      final p = pointAt(i);
      if (i == selectedIndex) {
        canvas.drawCircle(p, 7, Paint()
          ..color = color.withValues(alpha: .23));
      }
      canvas.drawCircle(p, i == selectedIndex ? 4.6 : 3.4,
        Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _MetricHistoryPainter old) =>
      old.color != color || old.points != points ||
      old.selectedIndex != selectedIndex;
}

/// A tape records full contours, not the size of individual muscles.
String _measureInstructions(MeasurementMetric metric) => switch (metric) {
  MeasurementMetric.neck => 'Mide el cuello por debajo de la laringe sin comprimir la cinta.',
  MeasurementMetric.shoulders => 'Rodea deltoides y espalda alta; no mide trapecios por separado.',
  MeasurementMetric.chest => 'Tórax: rodea pecho y espalda a la altura del pecho, tras exhalar normalmente.',
  MeasurementMetric.leftArm || MeasurementMetric.rightArm => 'Mide a mitad entre hombro y codo con el brazo relajado.',
  MeasurementMetric.leftForearm || MeasurementMetric.rightForearm => 'Mide el contorno máximo del antebrazo, sin contraerlo.',
  MeasurementMetric.leftLeg || MeasurementMetric.rightLeg => 'Mide a mitad del muslo; incluye cuádriceps, isquios y aductores.',
  MeasurementMetric.waist => 'Mide la cintura siempre en el mismo punto, sin apretar la cinta.',
  MeasurementMetric.hips => 'Mide la máxima circunferencia de caderas y glúteos.',
  MeasurementMetric.leftCalf || MeasurementMetric.rightCalf => 'Mide la circunferencia máxima de cada pantorrilla, por separado.',
  MeasurementMetric.calves => 'Dato antiguo general de gemelos, sin distinción de lado.',
  _ => 'Registra bajo condiciones similares; no equivale a tamaño de músculo.',
};
