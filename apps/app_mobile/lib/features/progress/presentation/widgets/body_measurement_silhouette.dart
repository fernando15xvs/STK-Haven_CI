import 'dart:math' as math;

import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';
import 'package:flutter/material.dart';
import 'package:core/core/theme/app_palette.dart';
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

const _front = <_Callout>[
  _Callout(MeasurementMetric.shoulders, 'Hombros', true, .135, Offset(.37,.20)),
  _Callout(MeasurementMetric.chest, 'Pecho', false, .218, Offset(.52,.285)),
  _Callout(MeasurementMetric.rightArm, 'Brazo der.', true, .330, Offset(.24,.345)),
  _Callout(MeasurementMetric.leftArm, 'Brazo izq.', false, .400, Offset(.76,.345)),
  _Callout(MeasurementMetric.waist, 'Cintura', true, .502, Offset(.42,.455)),
  _Callout(MeasurementMetric.hips, 'Caderas', false, .563, Offset(.57,.518)),
  _Callout(MeasurementMetric.rightLeg, 'Pierna der.', true, .682, Offset(.41,.648)),
  _Callout(MeasurementMetric.leftLeg, 'Pierna izq.', false, .750, Offset(.59,.648)),
  _Callout(MeasurementMetric.calves, 'Gemelos', true, .880, Offset(.41,.825)),
];

const _rear = <_Callout>[
  _Callout(MeasurementMetric.shoulders, 'Hombros', false, .135, Offset(.64,.20)),
  _Callout(MeasurementMetric.rightArm, 'Brazo der.', false, .285, Offset(.72,.365)),
  _Callout(MeasurementMetric.leftArm, 'Brazo izq.', true, .365, Offset(.27,.365)),
  _Callout(MeasurementMetric.waist, 'Cintura', false, .470, Offset(.57,.457)),
  _Callout(MeasurementMetric.hips, 'Caderas', true, .548, Offset(.41,.517)),
  _Callout(MeasurementMetric.rightLeg, 'Pierna der.', false, .668, Offset(.60,.67)),
  _Callout(MeasurementMetric.leftLeg, 'Pierna izq.', true, .743, Offset(.40,.67)),
  _Callout(MeasurementMetric.calves, 'Gemelos', true, .866, Offset(.40,.824)),
];

/// A single authentic anatomical PNG, side labels and leader-lines.
/// Nothing (including cm values) is baked into the PNG asset.
class BodyMeasurementSilhouette extends StatefulWidget {
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
    final colors = Theme.of(context).colorScheme;
    final accent = AppColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Medidas corporales',
              style: Theme.of(context).textTheme.titleMedium)),
            Tooltip(
              message:'Perímetros registrados; no tamaños individuales de músculos.',
              child: Icon(Icons.info_outline, size: 19,
                color: colors.onSurfaceVariant),
            ),
          ]),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            key: const Key('measurement_view_switch'),
            segments: const [
              ButtonSegment(value:false,label:Text('Frente')),
              ButtonSegment(value:true,label:Text('Espalda')),
            ],
            selected: {_back},
            onSelectionChanged: (values) =>
                setState(() => _back = values.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? accent.primaryFaded : colors.surfaceContainerHighest),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? accent.primary : colors.onSurface),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            key: Key(_back ? 'silhouette_back' : 'silhouette_front'),
            decoration: BoxDecoration(
              color: colors.brightness == Brightness.dark
                ? const Color(0xFF0D121B) : const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: LayoutBuilder(builder: (context, limits) {
              // The anatomical PNG has a 0.4 width/height ratio. Reserve
              // generous outer margins for readable left/right callouts.
              final w = limits.maxWidth;
              final h = math.max(405.0, math.min(570.0, w * 1.43));
              final figureWidth = w * .57;
              final figureHeight = h * .95;
              final figureLeft = (w - figureWidth) / 2;
              final figureTop = (h - figureHeight) / 2;
              final positions = _back ? _rear : _front;
              final ink = accent.primary;
              const labelWidthFactor = .265;
              final badgeWidth = w * labelWidthFactor;
              final labelHeight = 42.0;
              final anchors = [
                for (final c in positions)
                  Offset(figureLeft + c.anchor.dx * figureWidth,
                    figureTop + c.anchor.dy * figureHeight),
              ];
              final ends = [
                for (final c in positions)
                  Offset(c.labelLeft ? badgeWidth+3 : w-badgeWidth-3,
                    c.row*h+labelHeight*.5),
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
                    painter:_LeaderLines(anchors:anchors,ends:ends,color:ink),
                  ))),
                  for(var i=0;i<positions.length;i++)
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
                        color:ink,
                        onPressed:()=>_open(positions[i].metric),
                      ),
                    ),
                  for(var i=0;i<positions.length;i++)
                    Positioned(
                      key: Key('map_${_back?'back':'front'}_${positions[i].metric.name}'),
                      left:anchors[i].dx-16,top:anchors[i].dy-16,
                      width:32,height:32,
                      child:Semantics(
                        button:true,
                        label:'${positions[i].metric.label}, '
                          '${SilhouetteMeasurementData.formatted(
                            SilhouetteMeasurementData.latest(
                              widget.measurements,positions[i].metric))}',
                        child:InkResponse(
                          radius:16,
                          onTap:()=>_open(positions[i].metric),
                          child:Center(child:Container(
                            width:widget.selected==positions[i].metric?13:10,
                            height:widget.selected==positions[i].metric?13:10,
                            decoration:BoxDecoration(
                              shape:BoxShape.circle,
                              color:ink,
                              border:Border.all(color:Colors.white,width:1.6),
                              boxShadow:const [BoxShadow(
                                color:Colors.black38,blurRadius:3)],
                            ),
                          )),
                        ),
                      ),
                    ),
                ]),
              );
            }),
          ),
          const SizedBox(height: 9),
          Text('Toca una etiqueta o un punto para ver su imagen, medida e historial.',
            style:Theme.of(context).textTheme.bodySmall),
          Text('Los valores corresponden a perímetros registrados. '
            'Los gemelos tienen una medida general, no un valor por pierna.',
            style:Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

class _MeasureCalloutBadge extends StatelessWidget {
  final MeasurementMetric metric;
  final String shortName;
  final SilhouetteMeasurement? value;
  final bool selected;
  final Color color;
  final VoidCallback onPressed;
  const _MeasureCalloutBadge({
    super.key,required this.metric,required this.shortName,
    required this.value,required this.selected,required this.color,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final bright = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected ? color : bright?const Color(0xFF1C2635):Colors.white,
      borderRadius:BorderRadius.circular(9),
      child:InkWell(
        borderRadius:BorderRadius.circular(9),onTap:onPressed,
        child:Container(
          decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(9),
            border:Border.all(color:color.withValues(alpha:.55)),
          ),
          padding:const EdgeInsets.symmetric(horizontal:4,vertical:3),
          child:Column(mainAxisAlignment:MainAxisAlignment.center,
            children:[
              Text(shortName,maxLines:1,overflow:TextOverflow.ellipsis,
                style:TextStyle(fontSize:10.0,fontWeight:FontWeight.w500,
                  color:selected?AppColors.of(context).onPrimary:
                    bright?Colors.white:const Color(0xFF192132))),
              const SizedBox(height:2),
              Text(value==null?'—':'${value!.value.toStringAsFixed(1)} cm',
                maxLines:1,style:TextStyle(
                  fontSize:12,fontWeight:FontWeight.w800,
                  color:selected?AppColors.of(context).onPrimary:color)),
            ]),
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
    final records=progress.points.reversed.toList();
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
      _ => throw ArgumentError.value(metric, 'metric'),
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
            'assets/measurement_anatomy/png/detail_$detailKey.png',
            semanticLabel:'Región anatómica destacada: ${metric.label}',
            fit:BoxFit.contain,
          ),
        ),
        const SizedBox(height:12),
        Card(child:Padding(
          padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Medida actual',style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:6),
            Text(SilhouetteMeasurementData.formatted(value),
              key:const Key('measurement_detail_value'),
              style:Theme.of(context).textTheme.headlineMedium),
            if(value!=null)...[
              const SizedBox(height:4),
              Text('Registrado: ${DateFormat('dd/MM/yyyy').format(value.date)}'),
              if(value.previous!=null)
                Text('Anterior: ${value.previous!.toStringAsFixed(1)} cm · '
                  '${value.delta!>0?'+':''}'
                  '${value.delta!.toStringAsFixed(1)} cm',
                  key:const Key('measurement_detail_delta')),
            ] else const Text('Sin registros todavía.'),
          ]),
        )),
        const SizedBox(height:12),
        Card(child:Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Historial',style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:8),
            if(records.length>1)
              SizedBox(height:130,child:CustomPaint(
                key:const Key('measurement_detail_chart'),
                painter:_MetricHistoryPainter(records,AppColors.of(context).primary),
                child:const SizedBox.expand(),
              ))
            else const Text('Registra esta medida en dos fechas para ver su evolución.'),
            const SizedBox(height:10),
            for(final entry in records.take(12))
              ListTile(
                dense:true,contentPadding:EdgeInsets.zero,
                title:Text('${entry.value.toStringAsFixed(1)} cm'),
                subtitle:Text(DateFormat('dd/MM/yyyy')
                  .format(entry.date)),
              ),
          ]),
        )),
        const SizedBox(height:12),
        Text('Se muestra el perímetro que registraste, no el tamaño '
          'individual de un músculo. Más centímetros no siempre implican '
          'ganancia muscular.',
          style:Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _MetricHistoryPainter extends CustomPainter {
  final List<MeasurementPoint> points;
  final Color color;
  const _MetricHistoryPainter(this.points,this.color);
  @override
  void paint(Canvas canvas,Size size){
    if(points.length<2)return;
    final v=points.map((e)=>e.value);
    final minV=v.reduce(math.min),maxV=v.reduce(math.max);
    final range=math.max(1.0,maxV-minV);
    final line=Paint()..color=color..strokeWidth=2.4
      ..strokeCap=StrokeCap.round..style=PaintingStyle.stroke;
    final grid=Paint()..color=color.withValues(alpha:.12)
      ..strokeWidth=1;
    for(var i=0;i<=3;i++){
      final y=14+(size.height-28)*i/3;
      canvas.drawLine(Offset(5,y),Offset(size.width-5,y),grid);
    }
    final path=Path();
    for(var i=0;i<points.length;i++){
      final x=9+(size.width-18)*i/(points.length-1);
      final y=size.height-12-(points[i].value-minV)/range*(size.height-24);
      if(i==0){path.moveTo(x,y);}else{path.lineTo(x,y);}
      canvas.drawCircle(Offset(x,y),3.2,Paint()..color=color);
    }
    canvas.drawPath(path,line);
  }
  @override
  bool shouldRepaint(covariant _MetricHistoryPainter old) =>
    old.color!=color||old.points!=points;
}
