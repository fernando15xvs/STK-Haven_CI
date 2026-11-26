import 'package:core/domain/models/program_adaptation.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_adaptation_policy.dart';
import 'package:core/features/programs/application/program_week_plan.dart';
import 'package:test/test.dart';

void main() {
  final monday = DateTime(2026,11,30,8);
  final nextMonday = DateTime(2026,12,7,8);
  const ids = ['A','B','C','D'];

  TrainingProgram program(ProgramScheduleMode mode, ProgramSequencePolicy policy, int count) =>
    TrainingProgram(id: 'matrix', name: 'Stoker', routineIds: ids,
      createdAt: monday, startedAt: monday, scheduleMode: mode,
      sequencePolicy: policy, targetSessionsPerWeek: count,
      trainingWeekdays: {for (var i=1;i<=count;i++) i},
      fixedWeekdayRoutineIds: {for (var i=1;i<=count;i++) i:ids[(i-1)%ids.length]},
      weeklySequenceRoutineIds: [for(var i=0;i<count;i++) ids[i%ids.length]]);

  ProgramWeekPlan view(TrainingProgram p, DateTime now) =>
    ProgramWeekPlan.calculate(program:p,routines:const [],now:now);

  for(final mode in ProgramScheduleMode.values) {
    for(final policy in ProgramSequencePolicy.values) {
      if(mode==ProgramScheduleMode.fixed && policy==ProgramSequencePolicy.weekly) continue;
      for(var frequency=1;frequency<=7;frequency++) {
        final count=frequency;
        test('matrix $mode $policy $count slots, forecast and JSON', () {
          final p=program(mode,policy,count);
          final initial=view(p,monday);
          final adapted=ProgramAdaptationPolicy.prepare(p,const [],monday);
          final projected=view(adapted,monday);
          expect(projected.target,count);
          expect(projected.slots.length,count);
          expect(projected.slots.map((s)=>s.id).toSet().length,count);
          expect(projected.slots.map((s)=>s.routineId),initial.slots.map((s)=>s.routineId));
          expect(projected.nextWeekRoutineIds,initial.nextWeekRoutineIds);
          expect(projected.nextSuggestion!.routineId,initial.nextSuggestion!.routineId);
          if(mode==ProgramScheduleMode.flexible) {
            expect(projected.slots.every((s)=>s.date==null),isTrue);
            expect(projected.nextSuggestion!.date,isNull);
          }
          final restored=TrainingProgram.fromJson(adapted.toJson());
          expect(restored.toJson(),adapted.toJson());
          final rolled=ProgramAdaptationPolicy.prepare(restored,const [],nextMonday);
          final actual=view(rolled,nextMonday);
          expect(actual.slots.length,count);
          if(mode!=ProgramScheduleMode.fixed && policy==ProgramSequencePolicy.rolling) {
            // Actual missed sessions survive, unlike the conditional forecast.
            expect(actual.slots.first.id,projected.slots.first.id);
          } else {
            expect(actual.slots.first.id,isNot(projected.slots.first.id));
          }
          expect(rolled.completions,isEmpty);
        });
      }
    }
  }

  for(final mode in ProgramScheduleMode.values) {
    for(final policy in ProgramSequencePolicy.values) {
      if(mode==ProgramScheduleMode.fixed&&policy==ProgramSequencePolicy.weekly)continue;
      test('exceptions survive backup and do not fabricate completion: $mode $policy',(){
        var p=ProgramAdaptationPolicy.prepare(program(mode,policy,5),const [],monday);
        final first=ProgramAdaptationPolicy.current(p).first;
        p=ProgramAdaptationPolicy.omit(p,const [],first.id,monday);
        expect(p.completions,isEmpty);
        p=ProgramAdaptationPolicy.restoreOmitted(p,const [],first.id,monday);
        p=ProgramAdaptationPolicy.pause(p,const [],monday,routineIds:{'A'});
        p=ProgramAdaptationPolicy.setUnavailableDays(p,const [],monday,[monday]);
        p=TrainingProgram.fromJson(p.toJson());
        expect(p.adaptation!.routinePausedAt('A',monday),isTrue);
        expect(view(p,monday).completed,0);
        expect(view(p,monday).nextSuggestion?.routineId,isNot('A'));
        final rolled=ProgramAdaptationPolicy.prepare(p,const [],nextMonday);
        expect(rolled.adaptation!.unavailableDays,isEmpty);
        expect(view(rolled,nextMonday).target,5);
        expect(view(rolled,nextMonday).completed,0);
      });
    }
  }

  test('rotating preview accounts for a deferred position, not all pending rows', () {
    final p=ProgramAdaptationPolicy.prepare(program(ProgramScheduleMode.flexible,
      ProgramSequencePolicy.rolling,5),const [],monday);
    final rows=ProgramAdaptationPolicy.current(p);
    final postponed=ProgramAdaptationPolicy.postpone(p,const [],rows.first.id,monday,nextMonday);
    expect(view(postponed,monday).nextWeekRoutineIds,['A','B','C','D','A']);
    expect(view(postponed,monday).nextSuggestion!.routineId,'B');
  });

  test('recover on an optional free day only changes the selected occurrence', () {
    final p=program(ProgramScheduleMode.continuous,ProgramSequencePolicy.rolling,3);
    final thursday=DateTime(2026,12,3,8);
    final prepared=ProgramAdaptationPolicy.prepare(p,const [],thursday);
    final row=ProgramAdaptationPolicy.current(prepared).first;
    final recovered=ProgramAdaptationPolicy.recover(prepared,const [],row.id,thursday);
    expect(view(recovered,thursday).nextSuggestion!.date,DateTime(2026,12,3));
    expect(recovered.trainingWeekdays,p.trainingWeekdays);
    final bound=ProgramAdaptationPolicy.bind(recovered,const [],'recovered',row.routineId,
      thursday,slotId:row.id);
    expect(bound.adaptation!.bindings['recovered'],row.id);
  });

  test('weekly target prevents program attribution but allows independent extra', () {
    var p=program(ProgramScheduleMode.flexible,ProgramSequencePolicy.rolling,1);
    p=p.recordCompletion(workoutSessionId:'done',routineId:'A',completedAt:monday);
    final prepared=ProgramAdaptationPolicy.prepare(p,const [],monday);
    expect(view(prepared,monday).goalReached,isTrue);
    expect(view(prepared,monday).nextSuggestion,isNull);
    expect(()=>ProgramAdaptationPolicy.bind(prepared,const [],'extra','B',monday),throwsStateError);
    final independent=ProgramAdaptationPolicy.bind(prepared,const [],'extra','B',monday,independent:true);
    expect(independent.adaptation!.bindings['extra'],'');
    expect(independent.completions.length,1);
  });

  test('multi-routine and total pauses survive JSON without mutating catalog', () {
    final p=program(ProgramScheduleMode.flexible,ProgramSequencePolicy.rolling,5);
    final paused=ProgramAdaptationPolicy.pause(p,const [],monday,routineIds:{'A','B'});
    final total=ProgramAdaptationPolicy.pause(paused,const [],monday,until:nextMonday);
    final restored=TrainingProgram.fromJson(total.toJson());
    expect(view(restored,monday).isPaused,isTrue);
    expect(view(restored,monday).nextSuggestion,isNull);
    expect(restored.weekAt(nextMonday),1);
    final resumed=ProgramAdaptationPolicy.resume(restored,nextMonday,routineIds:{'A','B'});
    expect(view(resumed,nextMonday).isPaused,isFalse);
    expect(view(resumed,nextMonday).nextSuggestion,isNotNull);
    expect(resumed.routineIds,ids);
    expect(resumed.adaptation!.occurrences.where((o)=>o.status==PlanOccurrenceStatus.completed),isEmpty);
  });
}
