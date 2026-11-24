import 'package:core/features/coach_pro/application/coach_pro_task_comments_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_task_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachProTaskCommentsScreen extends ConsumerWidget {
  final String relationshipId, taskId;
  const CoachProTaskCommentsScreen({super.key, required this.relationshipId, required this.taskId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(appBar: AppBar(title: const Text('Comentarios de la tarea')),
      body: !identity.signedIn || identity.userId == null
        ? const Center(child: Text('Inicia sesión con una cuenta permanente.'))
        : _Comments(key: ValueKey((identity.userId, relationshipId, taskId)),
            relationshipId: relationshipId, taskId: taskId));
  }
}
class _Comments extends ConsumerStatefulWidget {
  final String relationshipId, taskId;
  const _Comments({super.key, required this.relationshipId, required this.taskId});
  @override
  ConsumerState<_Comments> createState() => _CommentsState();
}
class _CommentsState extends ConsumerState<_Comments> with WidgetsBindingObserver {
  int _offset = 0;
  int _composerVersion = 0;
  CoachProTaskQuery get _query =>
      (relationshipId: widget.relationshipId, taskId: widget.taskId, offset: _offset);
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }
  void _refresh() => ref.invalidate(coachProTaskCommentsProvider(_query));
  @override
  Widget build(BuildContext context) {
    final result = ref.watch(coachProTaskCommentsProvider(_query));
    String date(DateTime value) => MaterialLocalizations.of(context).formatMediumDate(value);
    return SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: result.isLoading ? null : _refresh,
          icon: const Icon(Icons.refresh), label: const Text('Actualizar'))),
        result.when(skipLoadingOnRefresh: false, skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Column(children: [
            const Text('No se pudieron consultar los comentarios. Comprueba la conexión y el permiso para comentar.'),
            TextButton(onPressed: _refresh, child: const Text('Reintentar')),
          ]),
          data: (page) {
            if (page == null) return const Text('Comentarios no disponibles.');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Comentarios compartidos'),
              _CommentComposer(key: ValueKey(_composerVersion), relationshipId: widget.relationshipId, taskId: widget.taskId,
                onFinished: () {
                  setState(() { _offset = 0; _composerVersion++; });
                  ref.invalidate(coachProTaskCommentsProvider(_query));
                }),
              if (page.items.isEmpty) Text(_offset == 0 ? 'Todavía no hay comentarios.'
                : 'Esta página está vacía. Vuelve a la anterior.'),
              for (final item in page.items)
                Card(child: Padding(padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.authorUserId == page.coachUserId ? 'Entrenador' : 'Cliente'),
                    Text(date(item.createdAt.toLocal())),
                    if (item.occurrenceDate != null) Text('Registro del ${date(item.occurrenceDate!)}'),
                    Text(item.body),
                  ]))),
              Text('${page.totalCount} comentarios · Página ${_offset ~/ 25 + 1}'),
              Wrap(spacing: 12, runSpacing: 8, children: [
                OutlinedButton(onPressed: _offset > 0 ? () => setState(() => _offset -= 25) : null,
                  child: const Text('Anterior')),
                OutlinedButton(onPressed: page.items.isNotEmpty &&
                    _offset + 25 < page.totalCount && _offset + 25 <= 10000
                    ? () => setState(() => _offset += 25) : null, child: const Text('Siguiente')),
              ]),
            ]);
          }),
      ]),
    )));
  }
}

class _CommentComposer extends ConsumerStatefulWidget {
  final String relationshipId, taskId;
  final VoidCallback onFinished;
  const _CommentComposer({super.key, required this.relationshipId, required this.taskId, required this.onFinished});
  @override
  ConsumerState<_CommentComposer> createState() => _CommentComposerState();
}
class _CommentComposerState extends ConsumerState<_CommentComposer> {
  final _text = TextEditingController();
  bool _sending = false;
  String? _error;
  @override
  void dispose() { _text.dispose(); super.dispose(); }
  Future<void> _send() async {
    if (_sending) return;
    final body = _text.text.trim();
    if (body.isEmpty || body.runes.length > 2000) {
      setState(() => _error = 'Escribe entre 1 y 2000 caracteres.');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await ref.read(coachProTaskCommentsServiceProvider).add(
        relationshipId: widget.relationshipId, taskId: widget.taskId, body: body);
      if (!mounted) return;
      _text.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comentario enviado.')));
      widget.onFinished();
    } catch (_) {
      if (!mounted) return;
      // A lost response may follow a committed insert. Never retry automatically.
      // Revalidation removes stale protected content and any in-memory draft.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(
        'No se pudo confirmar el envío. Revisa los comentarios antes de volver a enviarlo.')));
      widget.onFinished();
    }
  }
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: _text, enabled: !_sending, minLines: 2, maxLines: 5,
        decoration: InputDecoration(labelText: 'Nuevo comentario',
          helperText: 'Compartido con el cliente. Máximo 2000 caracteres.',
          helperMaxLines: 3, errorText: _error)),
      const SizedBox(height: 8),
      FilledButton(onPressed: _sending ? null : _send,
        child: Text(_sending ? 'Enviando…' : 'Enviar comentario')),
    ]),
  );
}
