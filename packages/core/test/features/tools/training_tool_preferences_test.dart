import 'package:core/features/tools/application/training_tool_preferences.dart';
import 'package:core/features/tools/application/training_timer.dart';
import 'package:test/test.dart';
import '../../support/in_memory_core_preferences.dart';

void main(){
  test('plate settings persist separately by unit and can reset',()async{
    final store=InMemoryCorePreferenceStore();
    final prefs=TrainingToolPreferences(store);
    final kg=PlatePreferences(barWeight:15,limited:true,
      stock:{for(final p in PlatePreferences.plates(false))p:p==20?6:0});
    expect(await prefs.savePlates(false,kg),isTrue);
    final reopened=TrainingToolPreferences(store);
    expect(reopened.loadPlates(false).barWeight,15);
    expect(reopened.loadPlates(false).stock[20],6);
    expect(reopened.loadPlates(true).barWeight,45);
    expect(reopened.loadPlates(true).limited,isFalse);
    expect(await reopened.savePlates(false,PlatePreferences.defaults(false)),isTrue);
    expect(reopened.loadPlates(false).barWeight,20);
    expect(reopened.loadPlates(false).limited,isFalse);
  });
  test('malformed preferences are safe',()async{
    final store=InMemoryCorePreferenceStore({TrainingToolPreferences.plateKey(false):'{bad'});
    final prefs=TrainingToolPreferences(store);
    expect(prefs.loadPlates(false).barWeight,20);
    expect(await TrainingToolPreferences(null).savePlates(false,PlatePreferences.defaults(false)),isFalse);
  });
  test('restores running, paused, expired and stopwatch states from disk',()async{
    final prefs=TrainingToolPreferences(InMemoryCorePreferenceStore());
    final start=DateTime.utc(2026,11,27,12);
    final timer=TrainingTimerState(duration:90,startedAt:start);
    expect(await prefs.write(TrainingToolPreferences.timerKey,timer.toJson()),isTrue);
    final raw=prefs.read(TrainingToolPreferences.timerKey);
    final restored=TrainingTimerState.restore(raw,start.add(const Duration(seconds:30)));
    expect(restored.running,isTrue);
    expect(restored.displayAt(start.add(const Duration(seconds:30))),60);
    final expired=TrainingTimerState.restore(raw,start.add(const Duration(minutes:3)));
    expect(expired.running,isFalse);
    expect(expired.displayAt(start),0);
    final paused=TrainingTimerState.restore(restored.pause(start.add(const Duration(seconds:30))).toJson(),
      start.add(const Duration(minutes:4)));
    expect(paused.running,isFalse);
    expect(paused.displayAt(start),60);
    final watch=TrainingTimerState.restore(TrainingTimerState(stopwatch:true,startedAt:start).toJson(),
      start.add(const Duration(minutes:4)));
    expect(watch.displayAt(start.add(const Duration(minutes:4))),240);
    expect(TrainingTimerState.restore({'duration':-1},start).duration,90);
  });
}
