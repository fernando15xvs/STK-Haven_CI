import '../data/motivation_library.dart';

/// Optional local suggestions, not provider content or automatically played.
class MotivationPlaylistPresets {
  const MotivationPlaylistPresets._();

  static const titles=<String>[
    'Antes de entrenar',
    'Durante el entrenamiento',
    'Concentración',
    'Recuperación',
  ];

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
