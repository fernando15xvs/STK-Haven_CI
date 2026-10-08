import 'dart:async';

import 'package:core/core/services/coach_pro_local_reminder_service.dart';
import 'package:core/features/coach_pro/application/coach_pro_checkin_cadence_provider.dart';
import 'package:core/features/coach_pro/application/coach_pro_reminder_consent_provider.dart';
import 'package:core/features/coach_pro/domain/coach_pro_checkin_cadence.dart';
import 'package:core/features/coach_pro/domain/coach_pro_reminder_consent.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Only the client can opt in; this screen never accepts a coach-as-client flag.
class CoachProReminderSettingsPage extends ConsumerWidget {
  final String relationshipId;
  const CoachProReminderSettingsPage({
    super.key, required this.relationshipId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recordatorios voluntarios')),
      body: !identity.signedIn || identity.userId == null
          ? const Center(child: Text('Inicia sesión con una cuenta permanente.'))
          : _Reminders(key: ValueKey(identity.userId),
              userId: identity.userId!, relationshipId: relationshipId),
    );
  }
}

class _Reminders extends ConsumerStatefulWidget {
  final String userId, relationshipId;
  const _Reminders({
    super.key, required this.userId, required this.relationshipId,
  });
  @override
  ConsumerState<_Reminders> createState() => _RemindersState();
}

class _RemindersState extends ConsumerState<_Reminders>
    with WidgetsBindingObserver {
  bool _busy = false;
  int? _hour;
  CoachProReminderConsentQuery get _query =>
      (userId: widget.userId, relationshipId: widget.relationshipId);
  CoachProCheckinCadenceQuery get _cadenceQuery =>
      (userId: widget.userId, relationshipId: widget.relationshipId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _reload();
  }

  void _reload() {
    ref.invalidate(coachProCheckinCadenceProvider(_cadenceQuery));
    ref.invalidate(coachProReminderConsentProvider(_query));
  }

  Future<void> _toggle(
    bool enabled,
    CoachProCheckinCadence cadence,
    CoachProReminderConsent consent,
  ) async {
    if (_busy || kIsWeb || cadence.status !=
        CoachProCheckinCadenceStatus.accepted) return;
    if (ref.read(appIdentityProvider).userId != widget.userId) return;
    setState(() => _busy = true);
    try {
      if (enabled && !await CoachProLocalReminderService.requestPermission()) {
        throw StateError('Permission denied');
      }
      if (!enabled) await CoachProLocalReminderService.cancel();
      final service = ref.read(coachProReminderConsentServiceProvider);
      await service.set(
        relationshipId: widget.relationshipId,
        enabled: enabled,
        hourLocal: _hour ?? consent.hourLocal,
        expectedCadenceRevision: enabled ? cadence.revision : null,
      );
      if (!mounted || ref.read(appIdentityProvider).userId != widget.userId) {
        await CoachProLocalReminderService.cancel();
        return;
      }
      final updated = await service.get(widget.relationshipId);
      if (!mounted || ref.read(appIdentityProvider).userId != widget.userId) {
        await CoachProLocalReminderService.cancel();
        return;
      }
      try {
        await CoachProLocalReminderService.synchronize(updated);
      } catch (_) {
        await CoachProLocalReminderService.cancel();
        if (enabled) {
          await service.set(
            relationshipId: widget.relationshipId,
            enabled: false, hourLocal: consent.hourLocal,
            expectedCadenceRevision: null,
          );
        }
        rethrow;
      }
      if (mounted) {
        setState(() => _hour = null);
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(enabled
              ? 'Recordatorios locales activados. Puedes desactivarlos cuando quieras.'
              : 'Recordatorios desactivados.'),
        ));
      }
    } catch (_) {
      if (mounted && ref.read(appIdentityProvider).userId == widget.userId) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo cambiar el recordatorio. '
              'Comprueba permisos, conexión y configuración del dispositivo.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cadence = ref.watch(coachProCheckinCadenceProvider(_cadenceQuery));
    final consent = ref.watch(coachProReminderConsentProvider(_query));
    // Reconcile on page open and foreground return. No automatic OS permission
    // prompts: those happen ONLY after the user enables the switch.
    ref.listen(coachProReminderConsentProvider(_query), (_, next) {
      final current = next.valueOrNull;
      if (current != null) {
        unawaited(CoachProLocalReminderService.synchronize(current)
            .catchError((Object _) => CoachProLocalReminderService.cancel()));
      }
    });
    return SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Solo si tú quieres',
          style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Aceptar una frecuencia de check-ins NO activa avisos. '
          'Estos recordatorios son locales en tu teléfono y no son obligatorios. '
          'Puedes desactivarlos en cualquier momento.'),
        const SizedBox(height: 12),
        const Text('En la pantalla bloqueada solo aparecerá STK Haven y '
          'un mensaje genérico: nunca nombres, tareas, datos de salud ni '
          'comentarios del entrenador.'),
        const SizedBox(height: 12),
        if (kIsWeb)
          const Text('Los recordatorios de Coach Pro se configuran '
            'en Android o iOS. No se envían notificaciones web.'),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: _busy ? null : _reload,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar permisos'),
        )),
        cadence.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('No se pudo verificar el consentimiento '
            'de check-ins. Ningún recordatorio nuevo será programado.'),
          data: (schedule) {
            if (schedule == null ||
                schedule.status != CoachProCheckinCadenceStatus.accepted) {
              return const Text('Primero debes aceptar una frecuencia '
                'de check-ins para configurar recordatorios.');
            }
            return consent.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text('No se pudo verificar tu permiso '
                'de notificaciones. Actualiza e inténtalo nuevamente.'),
              data: (choice) {
                if (choice == null) return const Text('Sesión no disponible.');
                final hour = _hour ?? choice.hourLocal;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Días aceptados: ' +
                      (schedule.weekdays.toList()..sort())
                        .map((d) => const [
                          'Lunes','Martes','Miércoles','Jueves',
                          'Viernes','Sábado','Domingo'][d - 1]).join(', ')),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Text('Hora local'),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: hour,
                        items: [
                          for (var h = 7; h <= 22; h++)
                            DropdownMenuItem(
                              value: h,
                              child: Text(h.toString().padLeft(2,'0') + ':00'),
                            )
                        ],
                        onChanged: _busy || choice.enabled ? null
                          : (h) { if (h != null) setState(() => _hour = h); },
                      ),
                    ]),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Avisos locales voluntarios'),
                      subtitle: Text(choice.enabled
                        ? 'Activos a las ' + hour.toString().padLeft(2,'0') +
                          ':00, según los días aceptados.'
                        : 'Desactivados por defecto.'),
                      value: choice.enabled && !kIsWeb,
                      onChanged: _busy || kIsWeb ? null
                        : (value) => _toggle(value, schedule, choice),
                    ),
                    if (choice.enabled)
                      const Text('Para cambiar la hora, desactiva los avisos '
                        'y vuelve a activarlos con la hora elegida.'),
                  ],
                );
              },
            );
          },
        ),
      ]),
    )));
  }
}
