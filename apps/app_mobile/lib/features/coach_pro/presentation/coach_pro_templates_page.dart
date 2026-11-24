import 'package:core/features/coach_pro/application/coach_pro_template_provider.dart';
import 'package:core/features/coach_pro/domain/coach_pro_template.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Templates are a private coach library; every action is reauthorized via RPC.
class CoachProTemplatesPage extends ConsumerStatefulWidget {
  final String? relationshipId;
  const CoachProTemplatesPage({super.key, this.relationshipId});

  @override
  ConsumerState<CoachProTemplatesPage> createState() => _TemplatesState();
}

class _TemplatesState extends ConsumerState<CoachProTemplatesPage>
    with WidgetsBindingObserver {
  int _offset = 0;
  bool _busy = false;

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
    if (state == AppLifecycleState.resumed && mounted) {
      final user = ref.read(appIdentityProvider).userId;
      if (user != null) _refresh(user);
    }
  }

  void _refresh(String user) => ref.invalidate(
        coachProTemplatePageProvider((userId: user, offset: _offset)),
      );

  Future<void> _action(CoachProTemplateSummary item, String user,
      {required bool archive}) async {
    if (_busy || (!archive && widget.relationshipId == null)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(archive ? 'Archivar plantilla' : 'Asignar copia'),
        content: Text(archive
            ? 'Se ocultará la plantilla, pero no se modificarán los programas ya asignados.'
            : 'Se creará un programa independiente con inicio hoy. El cliente deberá aceptarlo antes de instalarlo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true || !mounted ||
        ref.read(appIdentityProvider).userId != user) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(coachProTemplateServiceProvider);
      if (archive) {
        await service.archive(item.id);
      } else {
        await service.assign(
          templateId: item.id, relationshipId: widget.relationshipId!);
      }
      if (!mounted || ref.read(appIdentityProvider).userId != user) return;
      if (archive) {
        setState(() => _offset = 0);
        _refresh(user);
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted && ref.read(appIdentityProvider).userId == user) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo completar la operación. Revisa tu conexión, '
              'tu plan y los permisos del cliente.'),
        ));
        _refresh(user);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(appIdentityProvider);
    final user = identity.userId;
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca de plantillas')),
      body: !identity.signedIn || user == null
          ? const Center(child: Text('Inicia sesión con una cuenta permanente.'))
          : _body(context, user),
    );
  }

  Widget _body(BuildContext context, String user) {
    final result = ref.watch(coachProTemplatePageProvider(
      (userId: user, offset: _offset),
    ));
    return SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Plantillas reutilizables',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Guarda una revisión como plantilla desde su historial. '
            'No se guardan notas privadas ni datos del cliente.'),
        const SizedBox(height: 8),
        if (widget.relationshipId != null)
          const Text('Selecciona una plantilla para asignar una copia a este cliente.'),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: _busy || result.isLoading ? null : () => _refresh(user),
          icon: const Icon(Icons.refresh), label: const Text('Actualizar'),
        )),
        result.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Column(children: [
            const Text('No se pudo cargar la biblioteca. Comprueba tu acceso Coach Pro.'),
            TextButton(onPressed: () => _refresh(user),
                child: const Text('Reintentar')),
          ]),
          data: (page) {
            if (page == null) return const Text('Biblioteca no disponible.');
            if (page.items.isEmpty && _offset == 0) {
              return const Text('Aún no hay plantillas. Abre una revisión '
                  'de programa y elige Guardar como plantilla.');
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final item in page.items)
                Card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                    Text(item.durationWeeks.toString() + ' semanas · ' +
                        item.routineCount.toString() + ' rutinas'),
                    Wrap(spacing: 8, children: [
                      if (widget.relationshipId != null)
                        FilledButton(
                          onPressed: _busy ? null
                              : () => _action(item, user, archive: false),
                          child: const Text('Asignar copia')),
                      TextButton(
                        onPressed: _busy ? null
                            : () => _action(item, user, archive: true),
                        child: const Text('Archivar')),
                    ]),
                  ]),
                )),
              Text('Total: ' + page.totalCount.toString()),
              Wrap(spacing: 8, children: [
                OutlinedButton(
                  onPressed: _busy || _offset == 0 ? null
                      : () => setState(() => _offset -= 25),
                  child: const Text('Anterior')),
                OutlinedButton(
                  onPressed: _busy || page.items.isEmpty ||
                          _offset + 25 >= page.totalCount ? null
                      : () => setState(() => _offset += 25),
                  child: const Text('Siguiente')),
              ]),
            ]);
          },
        ),
      ]),
    )));
  }
}
