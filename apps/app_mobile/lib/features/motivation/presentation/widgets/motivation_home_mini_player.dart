import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

import '../../application/motivation_playback.dart';
import '../motivation_page.dart';

/// A dock-adjacent playback control, never an OverlayEntry or Stack.
/// The shell reserves real layout space above its bottom navigation dock,
/// so workout rest controls and Finish buttons are never covered.
class MotivationHomeMiniPlayer extends StatelessWidget {
  const MotivationHomeMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player=MotivationPlayback.instance;
    return AnimatedBuilder(
      animation:player,
      builder:(context,_) {
        final track=player.currentTrack;
        if(track==null || player.completed)return const SizedBox.shrink();

        final colors=AppColors.of(context);
        return Padding(
          key:const ValueKey('motivation_shell_mini_player'),
          padding:const EdgeInsets.fromLTRB(16,0,16,6),
          child:Material(
            color:colors.surface,
            borderRadius:AppRadius.md_,
            child:Container(
              constraints:const BoxConstraints(minHeight:56),
              decoration:BoxDecoration(
                border:Border.all(color:colors.surfaceBorder),
                borderRadius:AppRadius.md_,
              ),
              child:Row(children:[
                const SizedBox(width:12),
                Icon(track.isVideo?Icons.movie_outlined:
                  Icons.music_note_rounded,
                  color:colors.primary),
                const SizedBox(width:6),
                Expanded(child:Semantics(
                  button:true,
                  label:'Abrir reproductor STK Motivation',
                  child:InkWell(
                    key:const ValueKey('motivation_shell_open_player'),
                    onTap:()=>Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:(_)=>const MotivationNowPlayingPage())),
                    child:Padding(
                      padding:const EdgeInsets.symmetric(vertical:8,horizontal:4),
                      child:Column(
                        crossAxisAlignment:CrossAxisAlignment.start,
                        mainAxisSize:MainAxisSize.min,
                        children:[
                          Text(track.title,
                            maxLines:1,overflow:TextOverflow.ellipsis,
                            style:AppTypography.bodyMedium),
                          Text(player.playing?'Reproduciendo':'En pausa',
                            maxLines:1,overflow:TextOverflow.ellipsis,
                            style:AppTypography.bodySmall.copyWith(
                              color:colors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                )),
                IconButton(
                  key:const ValueKey('motivation_shell_toggle'),
                  tooltip:player.playing?'Pausar STK Motivation':
                    'Reanudar STK Motivation',
                  onPressed:()=>unawaited(player.togglePlay()),
                  icon:Icon(player.playing?Icons.pause_rounded:
                    Icons.play_arrow_rounded),
                ),
                const SizedBox(width:4),
              ]),
            ),
          ),
        );
      },
    );
  }
}
