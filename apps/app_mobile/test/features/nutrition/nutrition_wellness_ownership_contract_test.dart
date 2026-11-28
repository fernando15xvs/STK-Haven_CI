import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main(){
  test('Home retains daily actions, Nutrition owns settings and reminders',(){
    final water=File('lib/features/home/presentation/widgets/hydration_widget.dart').readAsStringSync();
    final steps=File('lib/features/home/presentation/widgets/daily_steps_widget.dart').readAsStringSync();
    final overview=File('lib/features/nutrition/presentation/widgets/nutrition_overview_sections.dart').readAsStringSync();
    final settings=File('lib/features/nutrition/presentation/widgets/nutrition_wellness_settings.dart').readAsStringSync();
    expect(water,isNot(contains('_showSettings')));
    expect(steps,isNot(contains('_showGoalSettings')));
    expect(water,contains('home_hydration_quick_add'));
    expect(steps,contains('home_steps_connect'));
    expect(overview,contains('nutrition_water_settings'));
    expect(overview,contains('nutrition_steps_settings'));
    expect(settings,contains('hydrationPreferencesProvider.notifier).configure('));
    expect(settings,contains('stepGoalPreferencesProvider.notifier).configure('));
    expect(settings,contains('HydrationReminderService.syncNextReminder('));
    expect(settings,contains('StepGoalReminderService.syncToday('));
    expect(settings,contains('widget.water&&restricted'));
  });
}
