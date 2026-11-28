import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main(){
  String read(String path)=>File('lib/$path').readAsStringSync();
  test('Entrenar owns tools without duplicate quick-menu entry',(){
    final home=read('features/home/presentation/pages/home_screen.dart');
    final train=read('features/routines/presentation/pages/routines_page.dart');
    final tools=read('features/tools/presentation/training_tools_page.dart');
    expect(home,isNot(contains("label: 'Herramientas'")));
    expect(train,contains("ValueKey('train_open_tools')"));
    expect(train,contains('TrainingToolsPage.show(context)'));
    expect(tools,contains('showModalBottomSheet<void>'));
    expect(tools,contains('ExercisePerformanceMemory.latestForExercise'));
    expect(tools,contains('OneRmCalculator.percentageTable(result).entries'));
    expect(tools,contains('BarbellCalculatorModal.show(context)'));
  });
  test('contextual tools are driven by exercise evidence and never change sets',(){
    final memory=read('features/workout/presentation/widgets/active_workout_memory_overlay.dart');
    final progress=read('features/progress/presentation/pages/focused_exercise_progress_page.dart');
    expect(memory,contains('ExerciseToolAdvisor.forExercise(definition)'));
    expect(memory,contains('TrainingToolReference.forExercise(exercise,memory)'));
    final active=read('features/workout/presentation/active_workout_page_content.dart');
    expect(active,contains('reference.performanceWeight,settings.weightUnit'));
    expect(active,contains("value:'exercise_plates'"));
    expect(active,contains("value:'exercise_timer'"));
    expect(progress,contains('OneRmTool.show(context,exerciseId:exercise.id)'));
  });
  test('free timer has independent OS notification identity and no audio focus request',(){
    final native=read('platform/workout/mobile_workout_notification_service.dart');
    final boot=read('shared/bootstrap/mobile_app_bootstrap.dart');
    expect(native,contains('_trainingTimerId=41922'));
    expect(native,contains('cancel(id:_trainingTimerId)'));
    expect(native,contains('AudioAttributesUsage.notificationEvent'));
    expect(boot,contains('trainingTimerNativeProvider.overrideWithValue'));
    expect(native,isNot(contains('requestAudioFocus(')));
  });
}
