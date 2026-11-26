import 'package:core/features/coach/domain/smart_coach_engine.dart';
import 'package:flutter/material.dart';

/// Advisory surface only. Never writes programs, nutrition or prescribed loads.
class SmartCoachInsights extends StatelessWidget {
  final List<SmartCoachInsight> insights;
  const SmartCoachInsights({super.key,required this.insights});
  @override Widget build(BuildContext context){
    if(insights.isEmpty)return const SizedBox.shrink();
    return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('STK · Sugerencias para revisar',style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:6),
        const Text('Reglas orientativas basadas en datos registrados. No modifican tu plan.'),
        for(final insight in insights)...[
          const SizedBox(height:12),Text(insight.evidence,style:Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight:FontWeight.w600)),
          const SizedBox(height:4),Text(insight.recommendation),
        ],
      ])));
  }
}
