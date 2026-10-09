import 'package:core/core/services/personal_motivational_reminder_service.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/profile/data/personal_reminder_repository.dart';
import 'package:core/features/profile/domain/personal_reminder_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PersonalReminderPage extends StatefulWidget {
  const PersonalReminderPage({super.key});

  @override
  State<PersonalReminderPage> createState() => _PersonalReminderPageState();
}

class _PersonalReminderPageState extends State<PersonalReminderPage> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  late final PersonalReminderRepository _repository;
  int _interval = 60;
  bool _enabled = false;
  bool _showMessage = false;
  bool _busy = false;
  String? _notice;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _repository = PersonalReminderRepository(
      Hive.box(HiveBoxes.personalReminders),
    );
    _reset(_repository.read());
  }

  void _reset(PersonalReminderSettings s) {
    _message.text = s.message;
    _interval = s.intervalMinutes;
    _enabled = s.enabled;
    _showMessage = s.showMessageInNotification;
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  PersonalReminderSettings get _draft => PersonalReminderSettings(
    message: _message.text,
    intervalMinutes: _interval,
    enabled: _enabled,
    showMessageInNotification: _showMessage,
  );

  void _feedback(String message, {bool error = false}) {
    if (mounted) setState(() { _notice = message; _error = error; });
  }

  Future<void> _save() async {
    if (_busy || kIsWeb || _form.currentState?.validate() != true) return;
    final candidate = _draft;
    if (!candidate.isValid) return;
    setState(() { _busy = true; _notice = null; });
    try {
      if (candidate.enabled &&
          !await PersonalMotivationalReminderService.requestPermission()) {
        _feedback('Permite las notificaciones de STK Haven en tu teléfono.',
          error: true);
        return;
      }
      await PersonalMotivationalReminderService.synchronize(candidate);
      await _repository.write(candidate);
      _feedback(candidate.enabled
          ? 'Guardado. Avisos cada ' + candidate.intervalMinutes.toString() +
              ' minutos.'
          : 'Mensaje guardado. Los recordatorios están pausados.');
    } catch (_) {
      // Never retain a possibly outdated lock-screen message on failure.
      try {
        await PersonalMotivationalReminderService.cancel();
        await _repository.write(candidate.copyWith(enabled: false));
      } catch (_) {}
      if (mounted) setState(() => _enabled = false);
      _feedback('No se pudo programar el aviso. Revisa los permisos '
        'y vuelve a intentarlo.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pause() async {
    if (_busy || kIsWeb) return;
    setState(() => _busy = true);
    try {
      await PersonalMotivationalReminderService.cancel();
      await _repository.write(_repository.read().copyWith(enabled: false));
      if (mounted) setState(() => _enabled = false);
      _feedback('Recordatorios pausados. Tu mensaje sigue guardado.');
    } catch (_) {
      _feedback('No fue posible confirmar la pausa.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    if (_busy || kIsWeb || _form.currentState?.validate() != true) return;
    setState(() => _busy = true);
    try {
      if (!await PersonalMotivationalReminderService.requestPermission()) {
        _feedback('Activa las notificaciones en el sistema.', error: true);
        return;
      }
      await PersonalMotivationalReminderService.showPreview(_draft);
      _feedback('Notificación de prueba enviada a este dispositivo.');
    } catch (_) {
      _feedback('No se pudo enviar la notificación de prueba.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy || kIsWeb) return;
    final ok = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar mensaje personal'),
        content: const Text('Se eliminará del dispositivo y se cancelarán '
            'sus notificaciones.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Borrar')),
        ],
      ));
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await PersonalMotivationalReminderService.cancel();
      await _repository.clear();
      if (!mounted) return;
      setState(() => _reset(const PersonalReminderSettings()));
      _feedback('Mensaje borrado y avisos cancelados.');
    } catch (_) {
      _feedback('No se pudo borrar el mensaje o cancelar el aviso.',
        error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi mensaje personal')),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: colors.primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                  child: Padding(padding: const EdgeInsets.all(22),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.favorite_outline_rounded, size: 34,
                          color: colors.onPrimaryContainer),
                        const SizedBox(height: 12),
                        Text('Una frase que te dé fuerza',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.onPrimaryContainer)),
                        const SizedBox(height: 8),
                        Text('Escribe algo importante para ti y recíbelo '
                          'de forma periódica, incluso cuando la app esté cerrada.',
                          style: TextStyle(color: colors.onPrimaryContainer)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _message,
                  enabled: !_busy,
                  maxLines: 5, minLines: 3,
                  maxLength: PersonalReminderSettings.maxMessageLength,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() => _notice = null),
                  validator: (s) =>
                    PersonalReminderSettings.validateMessage(s ?? ''),
                  decoration: const InputDecoration(
                    labelText: 'Mi mensaje',
                    hintText: 'Hoy elijo cuidarme, paso a paso.',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    helperText: 'Guardado solo en este dispositivo.',
                  ),
                ),
                const SizedBox(height: 12),
                Text('Frecuencia', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 30, label: Text('30 minutos')),
                    ButtonSegment(value: 60, label: Text('1 hora')),
                  ],
                  selected: {_interval},
                  onSelectionChanged: _busy ? null
                      : (v) => setState(() => _interval = v.first),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activar recordatorios'),
                  subtitle: const Text('Puedes pausarlos cuando quieras.'),
                  value: _enabled && !kIsWeb,
                  onChanged: _busy || kIsWeb ? null
                      : (v) => setState(() => _enabled = v),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar mi frase en la notificación'),
                  subtitle: const Text('Desactivado por privacidad. '
                    'Al activarlo, otras personas podrían leer tu texto '
                    'en la pantalla bloqueada.'),
                  value: _showMessage,
                  onChanged: _busy ? null
                      : (v) => setState(() => _showMessage = v),
                ),
                Card(child: Padding(padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.visibility_outlined),
                        const SizedBox(width: 10),
                        Text('Vista previa',
                            style: theme.textTheme.titleMedium),
                      ]),
                      const SizedBox(height: 10),
                      Text(_showMessage && _message.text.trim().isNotEmpty
                          ? _draft.notificationBody
                          : PersonalReminderSettings.safeNotificationBody),
                    ],
                  ),
                )),
                if (kIsWeb)
                  const Padding(padding: EdgeInsets.only(top: 12),
                    child: Text('Los avisos periódicos están disponibles '
                      'en Android e iOS, no en la versión web.')),
                const SizedBox(height: 12),
                const Text('El sistema puede retrasar los avisos por ahorro '
                  'de batería. No se sincronizan ni se envían a otros usuarios.'),
                if (_notice != null) ...[
                  const SizedBox(height: 12),
                  Semantics(liveRegion: true, child: Text(_notice!,
                    style: TextStyle(
                      color: _error ? colors.error : colors.primary,
                      fontWeight: FontWeight.w600))),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy || kIsWeb ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_enabled ? 'Guardar y activar' : 'Guardar mensaje'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  OutlinedButton.icon(onPressed: _busy || kIsWeb ? null : _test,
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Enviar prueba')),
                  TextButton.icon(onPressed: _busy || kIsWeb ? null : _pause,
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Pausar')),
                  TextButton.icon(onPressed: _busy || kIsWeb ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Borrar mensaje')),
                ]),
                const SizedBox(height: 12),
                Text('Un recordatorio es una ayuda, no una obligación. '
                  'Si te agobia recibir tantos avisos, puedes pausarlos.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ))),
    );
  }
}
