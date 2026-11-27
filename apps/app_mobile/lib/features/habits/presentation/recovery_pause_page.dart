import 'package:flutter/material.dart';
import 'package:core/features/habits/application/guided_habit_plan.dart';
import 'guided_habit_page.dart';

class RecoveryPausePage extends StatelessWidget {
  const RecoveryPausePage({super.key});
  @override Widget build(BuildContext context)=>const GuidedHabitPage(kind:GuidedHabitKind.personalPause);
}
