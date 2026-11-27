import 'package:flutter/material.dart';
import 'package:core/features/habits/application/guided_habit_plan.dart';
import 'guided_habit_page.dart';

class WindDownPage extends StatelessWidget {
  final bool breathingOnly;
  const WindDownPage({super.key,this.breathingOnly=false});
  @override Widget build(BuildContext context)=>GuidedHabitPage(
    kind:breathingOnly?GuidedHabitKind.breathing:GuidedHabitKind.night);
}
