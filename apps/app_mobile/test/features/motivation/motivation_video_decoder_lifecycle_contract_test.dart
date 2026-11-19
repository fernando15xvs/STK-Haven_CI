import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final page = File(
    'lib/features/motivation/presentation/motivation_page.dart',
  ).readAsStringSync();

  test('B2 late native MP4 decoder errors expose retry and cancel listeners', () {
    final start=page.indexOf('class _SilentVideoPreviewState');
    final end=page.indexOf('class _MotivationArtwork',start);
    expect(start,greaterThanOrEqualTo(0));
    expect(end,greaterThan(start));
    final video=page.substring(start,end);
    expect(video,contains('c.addListener(_onVideoDecoderChanged);'));
    expect(video,contains('c.value.hasError'));
    expect(video,contains('void _markVideoDecoderFailed(VideoPlayerController c)'));
    final failureStart=video.indexOf('void _markVideoDecoderFailed(');
    final failureEnd=video.indexOf('void _syncVideoLoop()',failureStart);
    final failure=video.substring(failureStart,failureEnd);
    final guard=failure.indexOf('if(!mounted || controller!=c)return;');
    final clear=failure.indexOf('controller=null;');
    final cleanup=failure.indexOf('oldPosition.cancel()');
    final dispose=failure.indexOf('c.dispose().catchError(');
    expect(guard,greaterThanOrEqualTo(0));
    expect(clear,greaterThan(guard));
    expect(cleanup,greaterThan(clear));
    expect(dispose,greaterThan(cleanup));
    expect(failure,contains('oldPlaying.cancel()'));
    expect(failure,contains('_cinemaSource.value=null;'));
    expect(failure,contains('_videoFailed=true;'));
    expect(failure,isNot(contains('_setup()')));
    expect(failure,isNot(contains('audio.play(')));
    expect(video,contains("ValueKey('motivation_video_retry')"));
    expect(video,contains('onPressed:()=>unawaited(_setup())'));
  });

  test('B2 async native MP4 calls handle codec teardown and stale source', () {
    final video=page.substring(
      page.indexOf('class _SilentVideoPreviewState'),
      page.indexOf('class _MotivationArtwork'),
    );
    expect(video,contains('c.play().catchError((Object _)'));
    expect(video,contains('c.pause().catchError((Object _)'));
    expect(video,contains('c.setLooping(loop).catchError((Object _)'));
    expect(video,contains('previous.removeListener(_onVideoDecoderChanged);'));
    expect(video,contains('old.removeListener(_onVideoDecoderChanged);'));
    expect(video,contains('previous.dispose().catchError((Object _)'));
    expect(video,contains('old.dispose().catchError((Object _)'));
    expect(video,contains('if(!mounted || controller!=c || !visible)return;'));
    expect(video,contains('if(widget.playback.playing && !widget.playback.completed)'));
    expect(video.split('VideoPlayerController.file(').length-1,1);
    expect(video,isNot(contains('AudioPlayer(')));
  });

  test('B2 responsive library and cinema keep theme tokens and 200% controls', () {
    expect(page,contains('backgroundColor:colors.background,'));
    // The redesigned library uses compact rows, not elevated nested cards;
    // visual tokens, separators and readable media actions remain.
    expect(page,contains('Divider(height: 1, color: colors.surfaceBorder)'));
    expect(page,contains('contentPadding: const EdgeInsets.symmetric('));
    expect(page,contains("ValueKey('motivation_secondary_filters')"));
    expect(page,contains("ValueKey('motivation_import_responsive_actions')"));
    expect(page,contains('alignment:WrapAlignment.end'));
    expect(page,contains("ValueKey('motivation_playlist_presets_scroll')"));
    expect(page,contains('builder:(ctx)=>SafeArea(child:SingleChildScrollView'));
    expect(page,contains('maxHeight:MediaQuery.sizeOf(pageContext).height*.38'));
    expect(page,contains("ValueKey('motivation_full_track_title')"));
    expect(page,contains('Text(track.title,maxLines:3,overflow:TextOverflow.ellipsis'));
  });

  test('B2 private artwork decoding is bounded and labelled for screen readers', () {
    final artwork=page.substring(
      page.indexOf('class _MotivationArtwork'),
      page.indexOf('class MotivationNowPlayingPage'),
    );
    expect(artwork,contains('fit:BoxFit.cover'));
    expect(artwork,contains('MediaQuery.devicePixelRatioOf(context)'));
    expect(artwork,contains('.ceil().clamp(64,1024).toInt()'));
    expect(artwork,contains('cacheWidth:'));
    expect(artwork,isNot(contains('cacheHeight:')));
    expect(artwork,contains('semanticLabel:track.isVideo?'));
    expect(artwork,isNot(contains('Image.network(')));
    expect(artwork,isNot(contains('Image.memory(')));
  });

  test('B2 audio settings offer Outfit and spoken slider values', () {
    final audio=File(
      'lib/features/motivation/presentation/widgets/'
      'motivation_audio_settings_sheet.dart',
    ).readAsStringSync();
    expect(audio,contains('AppTypography.monoMedium.copyWith('));
    expect(audio,contains('AppTypography.headlineMedium'));
    expect(audio,contains('semanticFormatterCallback: (value) =>'));
    expect(audio,contains('por ciento'));
    expect(audio,contains('veces'));
    expect(audio,contains("Expanded(child: Text('Temporizador de apagado'"));
    expect(audio,isNot(contains('style: TextStyle(color: colors.primary)')));
  });
}
