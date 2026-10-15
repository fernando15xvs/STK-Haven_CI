import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';
import 'package:core/features/progress/services/measurement_reminder_service.dart';

class MeasurementProgressPanel extends ConsumerStatefulWidget {
  final List<BodyMeasurement> measurements;
  const MeasurementProgressPanel({super.key, required this.measurements});
  @override
  ConsumerState<MeasurementProgressPanel> createState() =>
      _MeasurementProgressPanelState();
}

class _MeasurementProgressPanelState
    extends ConsumerState<MeasurementProgressPanel> {
  MeasurementMetric _metric = MeasurementMetric.leftArm;
  MeasurementReminderSettings? _settings;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await MeasurementReminderService.read();
      if (mounted) setState(() => _settings = settings);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo leer la configuración.');
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MeasurementReminderService.configure(
        _settings!,
        widget.measurements,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recordatorio actualizado')),
        );
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'No se pudo guardar el recordatorio. Inténtalo de nuevo.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _change({bool? enabled, int? months, TimeOfDay? time}) {
    final old = _settings!;
    setState(
      () => _settings = MeasurementReminderSettings(
        enabled: enabled ?? old.enabled,
        months: months ?? old.months,
        hour: time?.hour ?? old.hour,
        minute: time?.minute ?? old.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final due = settings?.dueDate(widget.measurements);
    final progress = MeasurementProgress(widget.measurements, _metric);
    final weightUnit = ref.watch(settingsProvider).weightUnit;
    final unit = _metric == MeasurementMetric.weight
        ? weightUnit.label
        : _metric.unit;
    double display(double v) => _metric == MeasurementMetric.weight
        ? WeightConverter.displayWeight(v, weightUnit)
        : v;
    String signed(double v) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Evolución de tus medidas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                DropdownButton<MeasurementMetric>(
                  isExpanded: true,
                  value: _metric,
                  items: [
                    for (final m in MeasurementMetric.values)
                      DropdownMenuItem(value: m, child: Text(m.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _metric = v);
                  },
                ),
                if (!progress.canCompare)
                  const Text(
                    'Registra esta medida en al menos dos fechas distintas para comparar.',
                  )
                else ...[
                  Text(
                    '${display(progress.points.first.value).toStringAsFixed(1)} → ${display(progress.points.last.value).toStringAsFixed(1)} $unit',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${signed(display(progress.change!))} ${_metric == MeasurementMetric.bodyFat ? 'puntos porcentuales' : unit} · ${signed(progress.changePercent!)}% respecto al inicio',
                  ),
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(progress.points.first.date)} — ${DateFormat('dd/MM/yyyy').format(progress.points.last.date)} · ${progress.points.length} registros',
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label:
                        'Evolución de ${_metric.label}: ${signed(display(progress.change!))} $unit',
                    child: SizedBox(
                      height: 100,
                      child: CustomPaint(
                        painter: _TrendPainter(
                          progress.points,
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Un perímetro mayor no confirma ganancia muscular: también puede variar por grasa, líquidos o la forma de medir. Compara siempre en condiciones similares.',
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Recordar nuevas medidas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (settings == null) ...[
                  if (_error == null)
                    const LinearProgressIndicator()
                  else
                    TextButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                ] else ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activar recordatorio'),
                    value: settings.enabled,
                    onChanged: _saving ? null : (v) => _change(enabled: v),
                  ),
                  DropdownButton<int>(
                    isExpanded: true,
                    value: settings.months,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Cada mes')),
                      DropdownMenuItem(value: 2, child: Text('Cada 2 meses')),
                      DropdownMenuItem(value: 3, child: Text('Cada 3 meses')),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) {
                            if (v != null) _change(months: v);
                          },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      'Hora: ${TimeOfDay(hour: settings.hour, minute: settings.minute).format(context)}',
                    ),
                    onPressed: _saving
                        ? null
                        : () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: settings.hour,
                                minute: settings.minute,
                              ),
                            );
                            if (mounted && time != null) _change(time: time);
                          },
                  ),
                  Text(
                    due == null
                        ? 'Se programará cuando registres tus primeras medidas.'
                        : 'Fecha según tu último registro: ${DateFormat('dd/MM/yyyy HH:mm').format(due)}${due.isBefore(DateTime.now()) ? ' · Pendiente de actualizar' : ''}',
                  ),
                  const Text(
                    'Un aviso por ciclo. Al guardar nuevas medidas, el plazo vuelve a empezar. Si ya venció, al activarlo recibirás un aviso en aproximadamente un minuto.',
                  ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? 'Guardando…' : 'Guardar recordatorio',
                    ),
                  ),
                ],
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<MeasurementPoint> points;
  final Color color;
  _TrendPainter(this.points, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final min = points.map((p) => p.value).reduce(math.min);
    final max = points.map((p) => p.value).reduce(math.max);
    final range = max == min ? 1.0 : max - min;
    final duration = points.last.date
        .difference(points.first.date)
        .inMilliseconds;
    if (duration <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x =
          6 +
          p.date.difference(points.first.date).inMilliseconds /
              duration *
              (size.width - 12);
      final y = max == min
          ? size.height / 2
          : size.height - 6 - (p.value - min) / range * (size.height - 12);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => true;
}
