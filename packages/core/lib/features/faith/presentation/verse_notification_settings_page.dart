import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/presentation/providers/settings_provider.dart';
import '../data/verse_schedule_repository.dart';
import '../domain/verse_notification_schedule.dart';
import '../services/verse_notification_service.dart';

class VerseNotificationSettingsPage extends ConsumerStatefulWidget {
  const VerseNotificationSettingsPage({super.key});

  @override
  ConsumerState<VerseNotificationSettingsPage> createState() =>
      _VerseSettingsState();
}

class _VerseSettingsState extends ConsumerState<VerseNotificationSettingsPage>
    with WidgetsBindingObserver {
  VerseScheduleMode _mode = VerseScheduleMode.times;
  int _interval = 120, _start = 480, _end = 1200;
  List<int> _times = [480];
  bool _enabled = false, _loading = true, _busy = false;
  String _status = 'Comprobando los avisos…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _diagnose();
  }

  Future<void> _load() async {
    try {
      final saved = await VerseScheduleRepository.read();
      if (!mounted) return;
      setState(() {
        _mode = saved.mode;
        _interval = saved.intervalMinutes;
        _start = saved.startMinute;
        _end = saved.endMinute;
        _times = List.of(saved.times);
        _enabled = ref.read(settingsProvider).dailyVerseNotifications;
        _loading = false;
      });
      await _diagnose();
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _enabled = ref.read(settingsProvider).dailyVerseNotifications;
          _status =
              'No se pudieron leer tus horarios. Elige otros y guárdalos.';
        });
    }
  }

  Future<void> _diagnose() async {
    try {
      final permission = await VerseNotificationService.permissionEnabled();
      final count = await VerseNotificationService.pendingDailyReminderCount();
      final saved = await VerseScheduleRepository.read();
      if (!mounted) return;
      final enabled = ref.read(settingsProvider).dailyVerseNotifications;
      setState(
        () => _status = !permission
            ? 'Permiso bloqueado: revisa Ajustes del teléfono → Notificaciones → STK Haven. Activa también los avisos.'
            : !enabled
            ? 'Avisos desactivados. La prueba no activa los horarios.'
            : count != saved.minutes.length
            ? 'Programación incompleta: $count de ${saved.minutes.length} avisos. Pulsa Guardar para repararla.'
            : '$count avisos programados. Si no llegan, revisa Concentración/No molestar y el resumen de notificaciones del teléfono.',
      );
    } catch (_) {
      if (mounted)
        setState(
          () => _status =
              'No se pudo comprobar la programación. Vuelve a guardar o prueba el aviso.',
        );
    }
  }

  VerseNotificationSchedule get _schedule => VerseNotificationSchedule(
    mode: _mode,
    intervalMinutes: _interval,
    startMinute: _start,
    endMinute: _end,
    times: _times,
  );

  Future<void> _save() async {
    setState(() => _busy = true);
    VerseNotificationSchedule? previous;
    try {
      if (!_enabled) {
        await ref
            .read(settingsProvider.notifier)
            .setDailyVerseNotifications(false);
        await _diagnose();
        if (mounted) _message('Avisos desactivados.');
        return;
      }
      _schedule.minutes;
      // Preserve consent in SettingsNotifier; storing hours never opts in.
      try {
        previous = await VerseScheduleRepository.read();
      } catch (_) {
        /* Repair corrupt preferences. */
      }
      await VerseScheduleRepository.save(_schedule);
      if (!mounted) return;
      await ref
          .read(settingsProvider.notifier)
          .setDailyVerseNotifications(_enabled);
      if (!mounted) return;
      final effective = ref.read(settingsProvider).dailyVerseNotifications;
      setState(() => _enabled = effective);
      _message(
        effective
            ? 'Horarios guardados y avisos programados.'
            : 'Avisos desactivados.',
      );
      await _diagnose();
    } catch (error) {
      if (previous != null) {
        try {
          await VerseScheduleRepository.save(previous);
        } catch (_) {
          /* Report below. */
        }
      }
      if (mounted) {
        final message = error is FormatException
            ? error.message
            : error is StateError
            ? error.message.toString()
            : 'No se pudieron programar los avisos. Comprueba los permisos y vuelve a intentarlo.';
        setState(() => _status = message);
        _message(message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<int?> _pick(int value) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60),
    );
    return time == null ? null : time.hour * 60 + time.minute;
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      await VerseNotificationService.schedulePreview();
      if (mounted)
        _message(
          'Prueba programada para dentro de 30 segundos. Bloquea el teléfono; en Android puede demorarse por el ahorro de batería.',
        );
    } catch (error) {
      if (mounted)
        _message(
          error is StateError
              ? error.message.toString()
              : 'No se pudo programar la prueba. Revisa los permisos del teléfono.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Versículos durante el día')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Recibe versículos variados, independientes del versículo del día.',
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recibir versículos'),
                value: _enabled,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _enabled = value),
              ),
              DropdownButtonFormField<VerseScheduleMode>(
                initialValue: _mode,
                decoration: const InputDecoration(
                  labelText: 'Cuándo recibirlos',
                ),
                items: const [
                  DropdownMenuItem(
                    value: VerseScheduleMode.interval,
                    child: Text('Cada cierto tiempo'),
                  ),
                  DropdownMenuItem(
                    value: VerseScheduleMode.times,
                    child: Text('A horas específicas'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _mode = value!),
              ),
              const SizedBox(height: 16),
              if (_mode == VerseScheduleMode.interval) ...[
                DropdownButtonFormField<int>(
                  initialValue: _interval,
                  decoration: const InputDecoration(labelText: 'Frecuencia'),
                  items: VerseNotificationSchedule.intervals
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value < 60
                                ? 'Cada $value minutos'
                                : 'Cada ${value ~/ 60} ${value == 60 ? 'hora' : 'horas'}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _interval = value!),
                ),
                ListTile(
                  title: const Text('Desde'),
                  trailing: Text(
                    VerseNotificationSchedule.formatMinute(_start),
                  ),
                  onTap: _busy
                      ? null
                      : () async {
                          final v = await _pick(_start);
                          if (v != null && mounted) setState(() => _start = v);
                        },
                ),
                ListTile(
                  title: const Text('Hasta'),
                  trailing: Text(VerseNotificationSchedule.formatMinute(_end)),
                  onTap: _busy
                      ? null
                      : () async {
                          final v = await _pick(_end);
                          if (v != null && mounted) setState(() => _end = v);
                        },
                ),
                const Text(
                  'Solo recibirás avisos dentro de este horario, cada día.',
                ),
              ] else ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (final time in _times)
                      InputChip(
                        label: Text(
                          VerseNotificationSchedule.formatMinute(time),
                        ),
                        onDeleted: _busy
                            ? null
                            : () => setState(() => _times.remove(time)),
                      ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir hora'),
                  onPressed: _busy || _times.length >= 48
                      ? null
                      : () async {
                          final value = await _pick(720);
                          if (value != null && mounted)
                            setState(
                              () =>
                                  _times = {..._times, value}.toList()..sort(),
                            );
                        },
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Cada horario muestra un versículo distinto. La selección se renueva al abrir la app o guardar; si no la abres, se repite la selección guardada. Funciona sin conexión una vez descargada la Biblia.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Preparando…' : 'Guardar'),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_status),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _test,
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Probar aviso en 30 segundos'),
              ),
              TextButton(
                onPressed: _busy ? null : _diagnose,
                child: const Text('Comprobar programación'),
              ),
            ],
          ),
  );
}
