import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/progress/services/measurement_reminder_service.dart';
import 'package:flutter/material.dart';

/// One control surface shared by Notifications and the measurement entry form.
/// Keeps the existing persisted schedule and iOS/Android permission handling.
class MeasurementReminderControls extends StatefulWidget {
  final List<BodyMeasurement> measurements;
  final bool compact;
  const MeasurementReminderControls({
    super.key,
    required this.measurements,
    this.compact = false,
  });

  @override
  State<MeasurementReminderControls> createState() =>
      _MeasurementReminderControlsState();
}

class _MeasurementReminderControlsState
    extends State<MeasurementReminderControls> {
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
      final value = await MeasurementReminderService.read();
      if (mounted) setState(() { _settings = value; _error = null; });
    } catch (_) {
      if (mounted) setState(() =>
        _error = 'No se pudo consultar el recordatorio de medidas.');
    }
  }

  Future<void> _update(MeasurementReminderSettings next) async {
    final previous = _settings;
    setState(() { _settings = next; _saving = true; _error = null; });
    try {
      await MeasurementReminderService.configure(next, widget.measurements);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _settings = previous;
        _error = e is StateError
            ? e.message.toString()
            : 'No se pudo actualizar el recordatorio. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _change({bool? enabled, int? months, TimeOfDay? time}) {
    final old = _settings;
    if (old == null || _saving) return;
    _update(MeasurementReminderSettings(
      enabled: enabled ?? old.enabled,
      months: months ?? old.months,
      hour: time?.hour ?? old.hour,
      minute: time?.minute ?? old.minute,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final style = Theme.of(context).textTheme;
    final due = settings?.dueDate(widget.measurements);
    return Column(
      key: const Key('measurement_reminder_controls'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.compact)
          Text('Recordatorio de medidas', style: style.titleSmall),
        if (settings == null)
          if (_error == null)
            const LinearProgressIndicator()
          else
            TextButton(onPressed: _load, child: const Text('Reintentar')),
        if (settings != null) ...[
          SwitchListTile.adaptive(
            key: const Key('measurement_reminder_toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Recordarme registrar nuevas medidas'),
            subtitle: const Text('Un aviso por ciclo. También puedes '
                'cambiarlo en Perfil → Notificaciones.'),
            value: settings.enabled,
            onChanged: _saving ? null : (enabled) => _change(enabled: enabled),
          ),
          if (settings.enabled || !widget.compact) ...[
            Row(children: [
              const Expanded(child: Text('Frecuencia')),
              DropdownButton<int>(
                key: const Key('measurement_reminder_frequency'),
                value: settings.months,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Cada mes')),
                  DropdownMenuItem(value: 2, child: Text('Cada 2 meses')),
                  DropdownMenuItem(value: 3, child: Text('Cada 3 meses')),
                ],
                onChanged: _saving ? null : (m) {
                  if (m != null) _change(months: m);
                },
              ),
            ]),
            ListTile(
              key: const Key('measurement_reminder_time'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Hora del recordatorio'),
              trailing: Text(TimeOfDay(
                hour: settings.hour, minute: settings.minute,
              ).format(context)),
              onTap: _saving ? null : () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: settings.hour, minute: settings.minute),
                );
                if (time != null && mounted) _change(time: time);
              },
            ),
          ],
          if (due != null && settings.enabled)
            Text('Próximo aviso según tu último registro: '
              '${MaterialLocalizations.of(context).formatMediumDate(due)}',
              style: style.bodySmall),
          if (_saving)
            const LinearProgressIndicator(),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!, style:
                style.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
          ),
      ],
    );
  }
}
