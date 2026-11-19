import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/application/motivation_display_title.dart';
import 'package:gym_tracker/features/motivation/data/motivation_library.dart';

MotivationTrack track(String title, {bool video = false}) =>
    MotivationTrack(
      id: 'unchanged-media-id',
      title: title,
      fileName: video ? 'unchanged.mp4' : 'unchanged.mp3',
      mode: MotivationMode.discipline,
      importedAt: DateTime.utc(2026, 11, 18),
    );

void main() {
  test('M09 technical IDs show human fallback for audio and video', () {
    expect(MotivationDisplayTitle.of(track('v14044g50000dadr')),
        'Audio sin título');
    expect(MotivationDisplayTitle.of(
        track('v14044g50000dadr', video: true)), 'Video sin título');
    expect(MotivationDisplayTitle.of(track(
        '25a7bc84-7092-4dca-9c59-6e47e2b49239')), 'Audio sin título');
    expect(MotivationDisplayTitle.of(
        track('VID_20261118234502', video: true)), 'Video sin título');
    expect(MotivationDisplayTitle.of(track('')), 'Audio sin título');
  });

  test('human names remain readable without modifying metadata', () {
    for (final title in [
      'Upper A - Motivación',
      'Disciplina 2026',
      'Gym Sad',
      'Mi audio número 1',
      'Una frase con un título largo pero legible',
      'Track_01',
    ]) {
      final original = track(title);
      expect(MotivationDisplayTitle.of(original), title);
      expect(original.title, title);
      expect(original.id, 'unchanged-media-id');
      expect(original.fileName, 'unchanged.mp3');
    }
  });

  test('presentation has no persistence, network or playback side effects', () {
    final saved = track('v14044g50000dadr');
    final previousJson = saved.toJson();
    expect(MotivationDisplayTitle.of(saved), 'Audio sin título');
    expect(saved.toJson(), previousJson);
    expect(MotivationDisplayTitle.forName('       ', isVideo: true),
        'Video sin título');
  });
}
