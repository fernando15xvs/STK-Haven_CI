import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/notifications/web_platform_notification_service.dart';

class WebNotificationSettingsPage extends StatefulWidget {
  const WebNotificationSettingsPage({super.key});

  @override
  State<WebNotificationSettingsPage> createState() =>
      _WebNotificationSettingsPageState();
}

class _WebNotificationSettingsPageState
    extends State<WebNotificationSettingsPage> {
  late final WebPlatformNotificationService _service;
  WebPushSupport? _support;
  bool _backendActive = false;
  bool _busy = false;
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _service = WebPlatformNotificationService(Supabase.instance.client);
    _refresh();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      final support = await _service.support();
      final backend = await _service.backendSubscriptionActive();
      if (!mounted) return;
      setState(() {
        _support = support;
        _backendActive = backend;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'No se pudo consultar el estado: $error';
        _error = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _subscribe() async {
    await _run(
      () async {
        await _service.subscribe();
        await _refreshAfterAction();
        return 'Notificaciones Web Push activadas.';
      },
    );
  }

  Future<void> _unsubscribe() async {
    await _run(
      () async {
        await _service.unsubscribe();
        await _refreshAfterAction();
        return 'Notificaciones Web Push desactivadas en este navegador.';
      },
    );
  }

  Future<void> _sendTest() async {
    await _run(
      () async {
        final sent = await _service.sendTestPush();
        return sent > 0
            ? 'Notificación Push enviada a $sent dispositivo(s).'
            : 'No se confirmó ningún envío. Revisa la configuración del servidor.';
      },
    );
  }

  Future<void> _testForegroundNotification() async {
    await _run(
      () async {
        final shown =
            await WebPlatformNotificationService.showForegroundNotification(
          title: 'STK Haven',
          body: 'Prueba local de notificación con la PWA abierta.',
        );
        return shown
            ? 'Notificación local mostrada.'
            : 'El navegador todavía no concedió permiso de notificaciones.';
      },
    );
  }

  Future<void> _testSound() async {
    await _run(
      () async {
        final enabled = await WebPlatformNotificationService.enableAudio();
        if (!enabled) {
          return 'Este navegador no permitió activar el audio.';
        }
        final played = await WebPlatformNotificationService.playAlarmTone();
        return played
            ? 'Sonido de alarma reproducido.'
            : 'No se pudo reproducir el sonido.';
      },
    );
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      final message = await action();
      if (!mounted) return;
      setState(() => _message = message);
    } on FunctionException catch (error) {
      if (!mounted) return;
      final details = error.details?.toString().trim();
      setState(() {
        _message = details?.isNotEmpty == true
            ? details
            : (error.reasonPhrase ?? 'La función Web Push falló.');
        _error = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('Bad state: ', '');
        _error = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshAfterAction() async {
    final support = await _service.support();
    final backend = await _service.backendSubscriptionActive();
    if (!mounted) return;
    setState(() {
      _support = support;
      _backendActive = backend;
    });
  }

  @override
  Widget build(BuildContext context) {
    final support = _support;
    final user = Supabase.instance.client.auth.currentUser;
    final signedIn = user != null && !user.isAnonymous;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones Web/PWA')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Web Push',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Permite recibir avisos desde la PWA incluso cuando '
                          'STK Haven no está en primer plano. En iPhone la PWA '
                          'debe estar añadida a la pantalla de inicio.',
                        ),
                        const SizedBox(height: 14),
                        _StatusRow(
                          label: 'Navegador compatible',
                          ok: support?.supported == true,
                        ),
                        _StatusRow(
                          label: 'Permiso',
                          value: support?.permission ?? 'consultando…',
                          ok: support?.permission == 'granted',
                        ),
                        _StatusRow(
                          label: 'Suscripción en este navegador',
                          ok: support?.subscribed == true,
                        ),
                        _StatusRow(
                          label: 'Suscripción registrada en backend',
                          ok: _backendActive,
                        ),
                        _StatusRow(
                          label: 'PWA en modo instalado/standalone',
                          ok: support?.standalone == true,
                        ),
                        _StatusRow(
                          label: 'VAPID pública incluida en el build',
                          ok: _service.isServerConfigurationPresent,
                        ),
                        _StatusRow(
                          label: 'Cuenta permanente',
                          ok: signedIn,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _busy ||
                                      support?.supported != true ||
                                      !signedIn ||
                                      !_service.isServerConfigurationPresent
                                  ? null
                                  : _subscribe,
                              icon:
                                  const Icon(Icons.notifications_active_outlined),
                              label: const Text('Activar Push'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ||
                                      support?.subscribed != true
                                  ? null
                                  : _unsubscribe,
                              icon: const Icon(Icons.notifications_off_outlined),
                              label: const Text('Desactivar'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  _busy || !_backendActive ? null : _sendTest,
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Enviar Push de prueba'),
                            ),
                            IconButton(
                              tooltip: 'Actualizar estado',
                              onPressed: _busy ? null : _refresh,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        if (!signedIn) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Para Push en segundo plano necesitas iniciar sesión '
                            'con una cuenta permanente. Tus datos locales siguen '
                            'siendo locales hasta que decidas sincronizarlos.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sonido y prueba local',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'El tono propio funciona mientras la aplicación está '
                          'abierta. Las notificaciones Push en segundo plano usan '
                          'el comportamiento de sonido que determine el sistema '
                          'operativo y el navegador.',
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _busy ? null : _testSound,
                              icon: const Icon(Icons.volume_up_outlined),
                              label: const Text('Probar alarma'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ||
                                      support?.permission != 'granted'
                                  ? null
                                  : _testForegroundNotification,
                              icon: const Icon(Icons.notification_add_outlined),
                              label: const Text('Probar notificación local'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: _error
                        ? colors.errorContainer
                        : colors.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _error
                              ? colors.onErrorContainer
                              : colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool ok;
  final String? value;

  const _StatusRow({
    required this.label,
    required this.ok,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.info_outline,
            size: 18,
            color: ok ? colors.primary : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          if (value != null)
            Text(
              value!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
