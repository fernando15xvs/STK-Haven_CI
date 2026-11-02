import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/data/motivation_library.dart';

void main() {
  test('local metadata keeps MP4 type, mode and stable ID', () {
    final original=MotivationTrack(
      id:'abc',title:'Mi video',fileName:'abc.mp4',
      mode:MotivationMode.gymSad,importedAt:DateTime.utc(2026,11,1));
    final parsed=MotivationTrack.fromJson(original.toJson());
    expect(parsed.isVideo,isTrue);
    expect(parsed.mode,MotivationMode.gymSad);
    expect(parsed.id,'abc');
    expect(parsed.title,'Mi video');
    expect(parsed.copyWith(mode:MotivationMode.hype).mode,
      MotivationMode.hype);
  });
  test('unsafe stored paths cannot escape private media folder', () {
    expect(()=>MotivationTrack.fromJson({
      'id':'evil','title':'Bad','fileName':'../other.mp3',
      'mode':'hype','importedAt':'2026-11-01T00:00:00.000Z',
    }),throwsFormatException);
  });
  test('personal playlist JSON preserves track order', () {
    const list=MotivationPlaylist(id:'list',title:'Entrenar',
      trackIds:['b','a']);
    final parsed=MotivationPlaylist.fromJson(list.toJson());
    expect(parsed.trackIds,['b','a']);
  });
  test('four repeat policies and three modes remain distinct', () {
    expect(MotivationMode.values.length,3);
    expect(MotivationRepeat.values.length,4);
    expect(MotivationRepeat.one.label,'Repetir uno');
    expect(MotivationLibrary.supportedExtensions,contains('mp4'));
  });
}
