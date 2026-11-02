import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/motivation/application/motivation_playback.dart';
import 'package:gym_tracker/features/motivation/presentation/motivation_page.dart';

/// Compact playback controls that can be mounted in several mobile routes.
///
/// The AudioPlayer belongs to MotivationPlayback, not to this widget:
/// navigating between routines, an active workout and the library must never
/// create a second player, restart a track, or affect workout/rest timers.
class MotivationMiniPlayer extends StatelessWidget {
  const MotivationMiniPlayer({
    super.key,
    this.showLauncherWhenEmpty = false,
  });

  /// A small library entry when no media has been selected yet.
  final bool showLauncherWhenEmpty;

  void _openLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MotivationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playback = MotivationPlayback.instance;

    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final track = playback.currentTrack;
        if (track == null) {
          if (!showLauncherWhenEmpty) {
            return const SizedBox.shrink(
              key: ValueKey('motivation_mini_player_hidden'),
            );
          }
          return Padding(
            key: const ValueKey('motivation_mini_player_launcher'),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(Icons.headphones_outlined,
                    size: 18, color: AppColors.of(context).primary),
                label: const Text('STK Motivation'),
                tooltip: 'Abrir mis audios y videos',
                onPressed: () => _openLibrary(context),
              ),
            ),
          );
        }

        final colors = AppColors.of(context);
        final accent = colors.primary;
        return Padding(
          key: const ValueKey('motivation_mini_player'),
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Material(
            color: colors.surfaceHigh,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: colors.surfaceBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 58,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          key: const ValueKey('motivation_mini_player_open'),
                          onTap: () => _openLibrary(context),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 4),
                            child: Row(
                              children: [
                                Icon(
                                  track.isVideo
                                      ? Icons.movie_outlined
                                      : Icons.headphones_outlined,
                                  size: 22,
                                  color: accent,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.headlineSmall,
                                      ),
                                      Text(
                                        'STK Motivation · ${track.mode.label}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('motivation_mini_player_previous'),
                        tooltip: 'Audio anterior',
                        onPressed: () => unawaited(playback.previous()),
                        icon: const Icon(Icons.skip_previous_rounded),
                        color: colors.textPrimary,
                      ),
                      IconButton(
                        key: const ValueKey('motivation_mini_player_toggle'),
                        tooltip: playback.playing ? 'Pausar audio' : 'Reproducir audio',
                        onPressed: () => unawaited(playback.togglePlay()),
                        icon: Icon(
                          playback.playing
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded,
                          size: 30,
                          color: accent,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('motivation_mini_player_next'),
                        tooltip: 'Siguiente audio',
                        onPressed: () => unawaited(playback.next()),
                        icon: const Icon(Icons.skip_next_rounded),
                        color: colors.textPrimary,
                      ),
                      const SizedBox(width: 2),
                    ],
                  ),
                ),
                // Passive progress indication only: never controls rest times,
                // workout timers, or the audio session of another app.
                StreamBuilder<Duration>(
                  stream: playback.audio.positionStream,
                  builder: (context, snapshot) {
                    final duration = playback.duration;
                    final value = snapshot.data ?? playback.position;
                    final fraction = duration == null ||
                            duration.inMilliseconds <= 0
                        ? 0.0
                        : (value.inMilliseconds / duration.inMilliseconds)
                            .clamp(0.0, 1.0)
                            .toDouble();
                    return LinearProgressIndicator(
                      minHeight: 2,
                      value: fraction,
                      backgroundColor: colors.surfaceBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
