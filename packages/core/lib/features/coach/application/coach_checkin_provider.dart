import 'package:core/core/services/supabase_client_gateway.dart';
import 'package:core/domain/models/coach_checkin.dart';
import 'package:core/features/coach/data/coach_checkin_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:riverpod/riverpod.dart';

class CoachCheckinState {
  final List<CoachCheckin> items;
  final Map<String, List<CoachCheckinComment>> comments;
  final bool busy;
  final String? message;
  final String? clientId;
  final String? relationshipId;
  const CoachCheckinState({this.items = const [], this.comments = const {},
    this.busy = false, this.message, this.clientId, this.relationshipId});
  CoachCheckinState copyWith({List<CoachCheckin>? items,
    Map<String, List<CoachCheckinComment>>? comments, bool? busy,
    String? message, bool clear = false}) => CoachCheckinState(
      items: items ?? this.items, comments: comments ?? this.comments,
      busy: busy ?? this.busy, message: clear ? null : message ?? this.message,
      clientId: clientId, relationshipId: relationshipId);
}
final coachCheckinServiceProvider = Provider((ref) =>
    CoachCheckinService(CoreSupabaseClient.client));
final coachCheckinProvider = NotifierProvider<CoachCheckinNotifier, CoachCheckinState>(
    CoachCheckinNotifier.new);

class CoachCheckinNotifier extends Notifier<CoachCheckinState> {
  late CoachCheckinService _service;
  int _epoch = 0;
  bool _current(int epoch) => ref.mounted && epoch == _epoch;
  bool get _signedIn => ref.read(appIdentityProvider).signedIn;
  @override
  CoachCheckinState build() {
    ref.watch(appIdentityProvider.select((value) => (value.signedIn, value.userId)));
    _epoch++;
    ref.onDispose(() => _epoch++);
    _service = ref.watch(coachCheckinServiceProvider);
    return const CoachCheckinState();
  }
  Future<void> load(String client, {String? relationshipId}) async {
    if (!_signedIn) return;
    final epoch = ++_epoch;
    state = CoachCheckinState(busy: true, clientId: client, relationshipId: relationshipId);
    try {
      final items = await _service.list(client);
      if (!_current(epoch)) return;
      state = state.copyWith(items: List.unmodifiable(items.where((item) =>
        item.clientUserId == client && (relationshipId == null || item.relationshipId == relationshipId))),
        busy: false);
    } catch (_) {
      if (_current(epoch)) state = state.copyWith(busy: false, message: 'No se pudieron cargar los check-ins.');
    }
  }
  Future<bool> create({required String relationshipId, required String clientUserId,
    required int energy, required int recovery, String note = ''}) async {
    if (!_signedIn || state.busy || ref.read(appIdentityProvider).userId != clientUserId) return false;
    final epoch = _epoch;
    state = state.copyWith(busy: true, clear: true);
    try {
      await _service.create(relationshipId: relationshipId, energy: energy, recovery: recovery, note: note);
      if (!_current(epoch)) return false;
      await load(clientUserId, relationshipId: relationshipId);
      if (!ref.mounted) return false;
      return state.clientId == clientUserId && state.relationshipId == relationshipId;
    } catch (_) {
      if (_current(epoch)) state = state.copyWith(busy: false, message: 'No se pudo guardar el check-in.');
      return false;
    }
  }
  Future<void> loadComments(String id) async {
    if (!_signedIn || !state.items.any((item) => item.id == id)) return;
    final epoch = _epoch;
    final remaining = Map<String, List<CoachCheckinComment>>.from(state.comments)..remove(id);
    state = state.copyWith(comments: Map.unmodifiable(remaining));
    try {
      final comments = await _service.comments(id);
      if (!_current(epoch)) return;
      final next = Map<String, List<CoachCheckinComment>>.from(state.comments)..[id] = List.unmodifiable(comments.where((item) => item.checkinId == id));
      state = state.copyWith(comments: Map.unmodifiable(next));
    } catch (_) {
      if (_current(epoch)) state = state.copyWith(message: 'No se pudieron cargar los comentarios.');
    }
  }
  Future<bool> addComment(String id, String body) async {
    if (!_signedIn || state.busy || !state.items.any((item) => item.id == id) || body.trim().isEmpty) return false;
    final epoch = _epoch;
    state = state.copyWith(busy: true);
    try {
      await _service.comment(id, body.trim());
      if (!_current(epoch)) return false;
      await loadComments(id);
      if (!_current(epoch)) return false;
      state = state.copyWith(busy: false);
      return true;
    } catch (_) {
      if (_current(epoch)) state = state.copyWith(busy: false, message: 'No se pudo enviar el comentario.');
      return false;
    }
  }
}
