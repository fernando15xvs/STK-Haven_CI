import 'package:core/features/coach_pro/application/coach_pro_checkin_cadence_provider.dart';
import 'package:core/features/coach_pro/domain/coach_pro_checkin_cadence.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachProCheckinCadencePage extends ConsumerWidget {
  final String relationshipId;
  final bool asCoach;
  const CoachProCheckinCadencePage({
    super.key, required this.relationshipId, required this.asCoach,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Frecuencia de check-ins')),
      body: !identity.signedIn || identity.userId == null
          ? const Center(child: Text('Inicia sesión con una cuenta permanente.'))
          : _CadenceEditor(key: ValueKey(identity.userId),
              userId: identity.userId!, relationshipId: relationshipId,
              asCoach: asCoach),
    );
  }
}

class _CadenceEditor extends ConsumerStatefulWidget {
  final String userId, relationshipId;
  final bool asCoach;
  const _CadenceEditor({super.key, required this.userId,
      required this.relationshipId, required this.asCoach});

  @override
  ConsumerState<_CadenceEditor> createState() => _CadenceEditorState();
}

class _CadenceEditorState extends ConsumerState<_CadenceEditor>
    with WidgetsBindingObserver {
  Set<int>? _draft;
  bool _busy = false;

  CoachProCheckinCadenceQuery get _query =>
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
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }

  void _refresh() {
    setState(() => _draft = null);
    ref.invalidate(coachProCheckinCadenceProvider(_query));
  }

  Future<void> _perform({
    required Set<int> days,
    required CoachProCheckinCadence? current,
    bool? accept,
  }) async {
    if (_busy) return;
    final identity = ref.read(appIdentityProvider);
    if (!identity.signedIn || identity.userId != widget.userId) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(coachProCheckinCadenceServiceProvider);
      if (widget.asCoach) {
        await service.propose(
          relationshipId: widget.relationshipId,
          weekdays: days,
          expectedRevision: current?.revision,
        );
      } else if (current != null && accept != null) {
        await service.respond(
          relationshipId: widget.relationshipId,
          expectedRevision: current.revision,
          accept: accept,
        );
      }
      if (!mounted || ref.read(appIdentityProvider).userId != widget.userId) {
        return;
      }
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.asCoach
            ? 'Propuesta enviada. El cliente decide si la acepta.'
            : accept == true
                ? 'Frecuencia aceptada. Tus check-ins siguen siendo voluntarios.'
                : 'Frecuencia rechazada o desactivada.'),
      ));
    } catch (_) {
      if (mounted && ref.read(appIdentityProvider).userId == widget.userId) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo guardar. Comprueba tus permisos y '
              'vuelve a cargar la propuesta antes de intentarlo otra vez.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final response = ref.watch(coachProCheckinCadenceProvider(_query));
    return SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Frecuencia orientativa',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text('Esta preferencia no programa avisos automáticos, '
              'no obliga a registrar un check-in y no interpreta '
              'información de salud. El cliente puede rechazarla.'),
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: _busy || response.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
          )),
          response.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Column(children: [
              const Text('No se pudo consultar la frecuencia. '
                  'Revisa la conexión, tu plan y los permisos vigentes.'),
              TextButton(onPressed: _refresh, child: const Text('Reintentar')),
            ]),
            data: (current) {
              const dayNames = <int, String>{
                1: 'Lunes', 2: 'Martes', 3: 'Miércoles', 4: 'Jueves',
                5: 'Viernes', 6: 'Sábado', 7: 'Domingo',
              };
              final selected = _draft ?? current?.weekdays ?? {1, 3};
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(current == null
                    ? 'Sin propuesta configurada.'
                    : 'Estado: ' + _status(current.status)),
                const SizedBox(height: 8),
                if (!widget.asCoach && current != null)
                  Text('Días propuestos: ' +
                      current.weekdays.map((d) => dayNames[d]).join(', ')),
                if (widget.asCoach) ...[
                  const SizedBox(height: 12),
                  const Text('Elige entre 1 y 3 días por semana. '
                      'Cada cambio requiere una nueva aceptación del cliente.'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final day in dayNames.entries)
                      FilterChip(
                        label: Text(day.value),
                        selected: selected.contains(day.key),
                        onSelected: _busy || (!selected.contains(day.key) &&
                                selected.length >= 3)
                            ? null
                            : (value) => setState(() {
                                _draft = {...selected};
                                if (value) {
                                  _draft!.add(day.key);
                                } else {
                                  _draft!.remove(day.key);
                                }
                              }),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy || selected.isEmpty
                        ? null : () => _perform(days: selected, current: current),
                    child: const Text('Enviar propuesta'),
                  ),
                ] else if (current?.status ==
                    CoachProCheckinCadenceStatus.proposed) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null
                        : () => _perform(days: current!.weekdays,
                            current: current, accept: true),
                    child: const Text('Aceptar frecuencia'),
                  ),
                  TextButton(
                    onPressed: _busy ? null
                        : () => _perform(days: current!.weekdays,
                            current: current, accept: false),
                    child: const Text('Rechazar'),
                  ),
                ] else if (current?.status ==
                    CoachProCheckinCadenceStatus.accepted) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy ? null
                        : () => _perform(days: current!.weekdays,
                            current: current, accept: false),
                    child: const Text('Desactivar frecuencia'),
                  ),
                ],
              ]);
            },
          ),
        ],
      ),
    )));
  }

  String _status(CoachProCheckinCadenceStatus status) => switch (status) {
    CoachProCheckinCadenceStatus.proposed => 'Esperando aceptación',
    CoachProCheckinCadenceStatus.accepted => 'Aceptada por el cliente',
    CoachProCheckinCadenceStatus.declined => 'Rechazada o desactivada',
  };
}
