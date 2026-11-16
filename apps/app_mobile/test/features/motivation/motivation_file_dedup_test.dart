import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/data/motivation_file_dedup.dart';

void main(){
  late Directory dir;
  setUp(() async {
    dir=await Directory.systemTemp.createTemp('stk_motivation_duplicate_');
  });
  tearDown(() async {
    if(await dir.exists())await dir.delete(recursive:true);
  });

  test('byte-identical audio with different filenames is a duplicate',()async{
    final left=File('${dir.path}/song-a.mp3');
    final right=File('${dir.path}/different-name.mp3');
    final body=List<int>.generate(131073,(i)=>i%251);
    await left.writeAsBytes(body);
    await right.writeAsBytes(body);
    expect(await MotivationFileDedup.equalBytes(left,right),isTrue);
    expect(await MotivationFileDedup.matchesAny(right,[left]),isTrue);
  });

  test('single different byte in later chunk is not a duplicate',()async{
    final left=File('${dir.path}/video-a.mp4');
    final right=File('${dir.path}/video-b.mp4');
    final body=List<int>.generate(131073,(i)=>i%251);
    await left.writeAsBytes(body);
    body[130000]=(body[130000]+1)%255;
    await right.writeAsBytes(body);
    expect(await MotivationFileDedup.equalBytes(left,right),isFalse);
    expect(await MotivationFileDedup.matchesAny(right,[left]),isFalse);
  });

  test('nonexistent or different-size paths never match',()async{
    final short=File('${dir.path}/short.wav')..writeAsBytesSync([1]);
    final long=File('${dir.path}/long.wav')..writeAsBytesSync([1,2]);
    final missing=File('${dir.path}/missing.wav');
    expect(await MotivationFileDedup.equalBytes(short,long),isFalse);
    expect(await MotivationFileDedup.matchesAny(missing,[short]),isFalse);
    expect(await MotivationFileDedup.matchesAny(short,[missing]),isFalse);
  });

  test('bulk import rollback never deletes a potentially referenced file',(){
    final source=File(
      'lib/features/motivation/data/motivation_library.dart',
    ).readAsStringSync();
    final begin=source.indexOf('Future<int> importFiles(');
    final end=source.indexOf('Future<void> renameTrack(',begin);
    final import=source.substring(begin,end);
    expect(import,contains('final importedIds=<String>{};'));
    expect(import,contains('final copiedFiles=<File>[];'));
    expect(import,contains('_tracks.removeWhere((track)=>importedIds.contains(track.id));'));
    expect(import,contains('attemptedMetadataSave=true;'));
    expect(import,contains('if(safeToDiscard){'));
    expect(import,contains('await _changed();'));
    expect(import,contains('if(await copied.exists())await copied.delete();'));
    expect(import,contains('Keep the copied files if metadata may still reference them.'));
    expect(import,contains('for(final id in importedVideos){'));
  });

  test('library checks before creating any new media ID',(){
    final source=File(
      'lib/features/motivation/data/motivation_library.dart',
    ).readAsStringSync();
    final duplicateCheck=source.indexOf(
      'MotivationFileDedup.matchesAny(incoming,existing)');
    final createId=source.indexOf('final id=const Uuid().v4();',
      source.indexOf('Future<int> importFiles('));
    expect(duplicateCheck,greaterThan(0));
    expect(createId,greaterThan(duplicateCheck));
    expect(source,contains('if(await MotivationFileDedup.matchesAny(incoming,existing))continue;'));
  });
}
