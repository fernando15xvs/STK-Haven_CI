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
  late final PersonalReminderRepository _repository;
  List<PersonalReminderMessage> _messages = [];
  int _interval = 60;
  bool _enabled = false;
  bool _showMessage = false;
  bool _busy = false;
  bool _dirty = false;
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

  void _reset(PersonalReminderSettings settings) {
    _messages = settings.messages.toList();
    _interval = settings.intervalMinutes;
    _enabled = settings.enabled;
    _showMessage = settings.showMessageInNotification;
    _dirty = false;
  }

  PersonalReminderSettings get _draft => PersonalReminderSettings(
    messages: _messages,
    intervalMinutes: _interval,
    enabled: _enabled,
    showMessageInNotification: _showMessage,
  );

  void _feedback(String value, {bool error = false}) {
    if (!mounted) return;
    setState(() { _notice = value; _error = error; });
  }

  void _update(VoidCallback change) {
    if (_busy) return;
    setState(() {
      change();
      _dirty = true;
      _notice = null;
    });
  }

  Future<void> _editMessage({int? index}) async {
    if (_busy || (index == null &&
        _messages.length >= PersonalReminderSettings.maxMessages)) return;
    final original = index == null ? null : _messages[index];
    final edited = await showDialog<PersonalReminderMessage>(
      context: context,
      builder: (_) => _PersonalReminderEditorDialog(original: original),
    );
    if (edited == null || !mounted) return;
    _update(() {
      if (index == null) {
        _messages.add(edited);
      } else {
        _messages[index] = edited;
      }
    });
  }

  void _move(int index, int direction) {
    final target = index + direction;
    if (target < 0 || target >= _messages.length) return;
    _update(() {
      final item = _messages.removeAt(index);
      _messages.insert(target, item);
    });
  }

  Future<void> _removeMessage(int index) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar mensaje'),
        content: const Text('El mensaje se quitará de la rotación '
            'cuando guardes los cambios.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Quitar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _update(() {
      _messages.removeAt(index);
      if (_messages.isEmpty) _enabled = false;
    });
  }

  Future<void> _save() async {
    if (_busy || kIsWeb) return;
    final candidate = _draft;
    if (!candidate.isValid) {
      _feedback('Añade al menos un mensaje válido para activar los avisos.',
          error: true);
      return;
    }
    setState(() { _busy = true; _notice = null; });
    try {
      if (candidate.enabled &&
          !await PersonalMotivationalReminderService.requestPermission()) {
        _feedback('Activa las notificaciones de STK Haven en el teléfono.',
            error: true);
        return;
      }
      await PersonalMotivationalReminderService.synchronize(candidate);
      await _repository.write(candidate);
      if (mounted) setState(() => _dirty = false);
      _feedback(candidate.enabled
          ? 'Rotación activada: 1 aviso cada ' +
              candidate.intervalMinutes.toString() + ' minutos.'
          : 'Mensajes guardados. Avisos desactivados.');
    } catch (_) {
      // Never leave an outdated sensitive lock-screen preview scheduled.
      try {
        await PersonalMotivationalReminderService.cancel();
        await _repository.write(candidate.copyWith(enabled: false));
      } catch (_) {
        // Show an error rather than pretending cancellation succeeded.
      }
      if (mounted) setState(() { _enabled = false; _dirty = true; });
      _feedback('No pudimos actualizar las notificaciones. '
          'Revisa los permisos del dispositivo.', error: true);
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
      _feedback('Notificaciones pausadas. Puedes reactivarlas cuando quieras.');
    } catch (_) {
      _feedback('No fue posible confirmar la pausa.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(PersonalReminderMessage item) async {
    if (_busy || kIsWeb) return;
    setState(() => _busy = true);
    try {
      if (!await PersonalMotivationalReminderService.requestPermission()) {
        _feedback('Activa las notificaciones en los ajustes del dispositivo.',
            error: true);
        return;
      }
      await PersonalMotivationalReminderService.showPreview(_draft, item);
      _feedback('Notificación de prueba enviada.');
    } catch (_) {
      _feedback('No se pudo mostrar la notificación de prueba.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAll() async {
    if (_busy || kIsWeb) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar todos mis mensajes'),
        content: const Text('Se borrarán de este dispositivo '
            'y se cancelarán todas sus notificaciones.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Borrar todos')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await PersonalMotivationalReminderService.cancel();
      await _repository.clear();
      if (mounted) setState(() => _reset(PersonalReminderSettings()));
      _feedback('Todos los mensajes fueron borrados y los avisos cancelados.');
    } catch (_) {
      _feedback('No se pudo completar el borrado.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis mensajes personales')),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 42),
          children: [
            Card(
              color: colors.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.favorite_outline_rounded,
                        size: 32, color: colors.onPrimaryContainer),
                    const SizedBox(height: 12),
                    Text('Tus palabras, a tu ritmo',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimaryContainer)),
                    const SizedBox(height: 8),
                    Text('Escribe varias frases con su propio título. '
                        'Se mostrarán por turnos, una notificación por intervalo. '
                        'Abre cada tarjeta para leer su texto completo.',
                      style: TextStyle(color: colors.onPrimaryContainer)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Text(
                'Mis mensajes (' + _messages.length.toString() + '/' +
                    PersonalReminderSettings.maxMessages.toString() + ')',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold))),
              OutlinedButton.icon(
                onPressed: _busy ||
                    _messages.length >= PersonalReminderSettings.maxMessages
                    ? null : () => _editMessage(),
                icon: const Icon(Icons.add),
                label: const Text('Añadir'),
              ),
            ]),
            const SizedBox(height: 8),
            if (_messages.isEmpty)
              const Card(child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aún no hay mensajes. Añade el primero '
                    'para comenzar a crear tu lista personal.'),
              )),
            for (var i = 0; i < _messages.length; i++) ...[
              Card(
                key: ValueKey('personal-message-' + i.toString()),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: CircleAvatar(child: Text((i + 1).toString())),
                  title: Text(_messages[i].title, maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Toca para leer el mensaje completo'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(_messages[i].message),
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 2, runSpacing: 2, children: [
                      IconButton(
                        tooltip: 'Mover arriba',
                        onPressed: _busy || i == 0
                            ? null : () => _move(i, -1),
                        icon: const Icon(Icons.arrow_upward)),
                      IconButton(
                        tooltip: 'Mover abajo',
                        onPressed: _busy || i == _messages.length - 1
                            ? null : () => _move(i, 1),
                        icon: const Icon(Icons.arrow_downward)),
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: _busy ? null : () => _editMessage(index: i),
                        icon: const Icon(Icons.edit_outlined)),
                      IconButton(
                        tooltip: 'Probar notificación',
                        onPressed: _busy || kIsWeb
                            ? null : () => _preview(_messages[i]),
                        icon: const Icon(Icons.notifications_outlined)),
                      IconButton(
                        tooltip: 'Eliminar mensaje',
                        onPressed: _busy ? null : () => _removeMessage(i),
                        icon: const Icon(Icons.delete_outline)),
                    ]),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text('Frecuencia de las notificaciones',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 30, label: Text('30 minutos')),
                ButtonSegment(value: 60, label: Text('1 hora')),
              ],
              selected: {_interval},
              onSelectionChanged: _busy ? null
                : (values) => _update(() => _interval = values.first),
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activar mensajes rotativos'),
              subtitle: const Text('Desactivados por defecto. '
                  'Puedes pausarlos cuando quieras.'),
              value: _enabled && !kIsWeb,
              onChanged: _busy || kIsWeb || _messages.isEmpty ? null
                : (value) => _update(() => _enabled = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar título y texto en la notificación'),
              subtitle: const Text('Por privacidad está desactivado. '
                  'Si lo activas, los demás podrían leer tu título '
                  'y un fragmento en la pantalla bloqueada.'),
              value: _showMessage,
              onChanged: _busy ? null
                : (value) => _update(() => _showMessage = value),
            ),
            if (_messages.isNotEmpty)
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Así se verá el primer aviso',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Text(_draft.notificationTitleFor(_messages.first),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_draft.notificationBodyFor(_messages.first)),
                    const SizedBox(height: 6),
                    Text('Los mensajes completos se leen aquí, '
                        'no en la notificación.',
                      style: theme.textTheme.bodySmall),
                  ],
                ),
              )),
            const SizedBox(height: 12),
            if (kIsWeb)
              const Text('Los avisos se programan únicamente en Android e iOS. '
                  'No hay notificaciones periódicas en la web.'),
            const Text('El sistema puede retrasar las alertas por '
                'restricciones de batería. La secuencia se distribuye '
                'por turnos y el ciclo diario vuelve a comenzar cada día.'),
            if (_dirty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Tienes cambios sin guardar.',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(liveRegion: true,
                  child: Text(_notice!, style: TextStyle(
                    color: _error ? colors.error : colors.primary,
                    fontWeight: FontWeight.w600))),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy || kIsWeb ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_enabled ? 'Guardar y activar rotación'
                  : 'Guardar mensajes'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 4, children: [
              OutlinedButton.icon(
                onPressed: _busy || kIsWeb ? null : _pause,
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('Pausar avisos'),
              ),
              TextButton.icon(
                onPressed: _busy || kIsWeb ? null : _deleteAll,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Borrar todos'),
              ),
            ]),
            const SizedBox(height: 12),
            Text('Estos mensajes son personales y permanecen '
                'en este dispositivo. Si recibir tantos avisos '
                'te resulta abrumador, puedes pausarlos.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant)),
          ],
        ),
      ))),
    );
  }
}


class _PersonalReminderEditorDialog extends StatefulWidget {
  final PersonalReminderMessage? original;
  const _PersonalReminderEditorDialog({this.original});

  @override
  State<_PersonalReminderEditorDialog> createState() =>
      _PersonalReminderEditorDialogState();
}

class _PersonalReminderEditorDialogState
    extends State<_PersonalReminderEditorDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _message;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.original?.title ?? '');
    _message = TextEditingController(text: widget.original?.message ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.original == null ? 'Nuevo mensaje' : 'Editar mensaje'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 550),
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              maxLength: PersonalReminderMessage.maxTitleLength,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Por qué quiero seguir adelante',
                prefixIcon: Icon(Icons.title_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (v) => PersonalReminderMessage.validateTitle(v ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _message,
              textCapitalization: TextCapitalization.sentences,
              maxLength: PersonalReminderMessage.maxMessageLength,
              minLines: 5,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Mensaje completo',
                hintText: 'Hoy vuelvo a elegir lo que me hace bien...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  PersonalReminderMessage.validateMessage(v ?? ''),
            ),
          ]),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_key.currentState?.validate() != true) return;
          Navigator.pop(context, PersonalReminderMessage(
            title: _title.text.trim(),
            message: _message.text.trim(),
          ));
        },
        child: Text(widget.original == null ? 'Añadir' : 'Guardar cambios'),
      ),
    ],
  );
}
