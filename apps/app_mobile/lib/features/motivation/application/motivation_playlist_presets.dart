import '../data/motivation_library.dart';

/// Optional local suggestions, not provider content or automatically played.
/// Suggestions describe workout moments, never a claim that a workout
/// is underway. No sound starts until the user explicitly presses play.
enum MotivationPlaylistContext {
  warmUp('Antes de entrenar','Hype',MotivationMode.hype),
  session('Durante el entrenamiento','Disciplina / Hype',MotivationMode.discipline),
  focus('Concentración','Disciplina',MotivationMode.discipline),
  recovery('Recuperación','Gym Sad',MotivationMode.gymSad);

  const MotivationPlaylistContext(this.title,this.reason,this.preferredMode);
  final String title;
  final String reason;
  final MotivationMode preferredMode;
}

class MotivationPlaylistPresets {
  const MotivationPlaylistPresets._();

  static const titles=<String>[
    'Antes de entrenar',
    'Durante el entrenamiento',
    'Concentración',
    'Recuperación',
  ];

  /// Prioritize already favorited tracks in the selected local mode.
  /// During a session, both Hype and Disciplina are suitable. The list is
  /// only a preview, never persisted or queued by this pure function.
  static List<MotivationTrack> suggestTracks(
    Iterable<MotivationTrack> available,
    MotivationPlaylistContext context, {
    int limit=12,
  }) {
    if(limit<=0)return const <MotivationTrack>[];
    final matching=available.where((track)=>
      track.mode==context.preferredMode ||
      (context==MotivationPlaylistContext.session &&
        track.mode==MotivationMode.hype)).toList();
    // Stable ranking: favorites first, preserving each group's original order.
    final ranked=[
      ...matching.where((track)=>track.favorite),
      ...matching.where((track)=>!track.favorite),
    ];
    final seen=<String>{};
    return List<MotivationTrack>.unmodifiable([
      for(final track in ranked)
        if(seen.add(track.id))track,
    ].take(limit.clamp(1,24).toInt()));
  }

  static List<String> notYetCreated(Iterable<MotivationPlaylist> existing) {
    final names={
      for(final playlist in existing)playlist.title.trim().toLowerCase(),
    };
    return [
      for(final title in titles)
        if(!names.contains(title.toLowerCase()))title,
    ];
  }
}
