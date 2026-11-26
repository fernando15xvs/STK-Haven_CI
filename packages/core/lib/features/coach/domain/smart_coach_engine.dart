import 'package:core/domain/models/coach_client_progress.dart';
import 'package:core/domain/models/coach_exercise_progress.dart';
import 'package:core/domain/models/coach_checkin.dart';

enum SmartCoachKind { insufficient, stale, frequency, volume, progression, plateau, recovery }
class SmartCoachInsight {
  final SmartCoachKind kind;
  final String evidence, recommendation;
  const SmartCoachInsight(this.kind,this.evidence,this.recommendation);
}
/// Rule-based, read-only and intentionally conservative. Only feed data already
/// authorized by the server. Never use these observations as a prescription.
class SmartCoachEngine {
  const SmartCoachEngine._();
  static bool _fresh(DateTime value,DateTime now) =>
      !value.isAfter(now.add(const Duration(minutes:5))) &&
      now.difference(value)<=const Duration(days:3);

  static List<SmartCoachInsight> progress(CoachClientProgress? p,{required DateTime now}){
    if(p==null||!p.available) return const [
      SmartCoachInsight(SmartCoachKind.insufficient,'No hay un resumen disponible.','Registra y sincroniza actividad antes de evaluar cambios.')];
    if(!_fresh(p.generatedAt,now))return const [
      SmartCoachInsight(SmartCoachKind.stale,'El resumen tiene más de tres días o una fecha incoherente.','Actualiza los datos antes de tomar decisiones.')];
    if(!p.trendBaselineAvailable||p.workouts7d==0||p.workoutsPrevious7d==0)return const [
      SmartCoachInsight(SmartCoachKind.insufficient,'No hay actividad comparable en ambas ventanas de siete días.','No asumas inactividad ni estancamiento; comprueba el registro.')];
    final insights=<SmartCoachInsight>[];
    if(p.workouts7d<p.workoutsPrevious7d){
      insights.add(SmartCoachInsight(SmartCoachKind.frequency,'${p.workouts7d} sesiones frente a ${p.workoutsPrevious7d} en la ventana anterior.',
        'Revisa el calendario y el registro antes de cambiar la frecuencia.'));
    }
    if(p.completedWorkingSetsPrevious7d>=10&&p.completedWorkingSets7d>=5&&p.volumePrevious7d.isFinite&&p.volume7d.isFinite&&p.volumePrevious7d>0){
      final change=(p.volume7d-p.volumePrevious7d)/p.volumePrevious7d;
      if(change.abs()>=.30)insights.add(SmartCoachInsight(SmartCoachKind.volume,
        'El volumen registrado cambió ${(change*100).round()}% entre ventanas.',
        'Comprueba ejercicios, rangos y series comparables; no aumentes ni reduzcas cargas automáticamente.'));
    }
    final adherence=p.frequencyAdherence;
    if(adherence!=null&&adherence.scheduledSessions7d>=2&&adherence.percent7d!=null&&adherence.percent7d!<75){
      insights.add(SmartCoachInsight(SmartCoachKind.frequency,
        'Frecuencia registrada: ${adherence.completedSessions7d}/${adherence.scheduledSessions7d}.',
        'Revisa disponibilidad y cumplimiento del plan; el dato no confirma la rutina exacta.'));
    }
    return List.unmodifiable(insights);
  }
  static List<SmartCoachInsight> exercise(CoachExerciseProgressSummary item,{required DateTime now}){
    if(!_fresh(item.generatedAt,now)||item.sessions30d<3||item.sessionsPrevious30d<3||
      item.workingSets30d<6||item.workingSetsPrevious30d<6)return const [];
    final previous=item.bestEstimated1RmPrevious30d,current=item.bestEstimated1Rm30d;
    if(previous==null||current==null||previous<=0||!previous.isFinite||!current.isFinite)return const [];
    final change=(current-previous)/previous;
    if(change>=.05)return [SmartCoachInsight(SmartCoachKind.progression,
      'Mejor e1RM estimado: ${(change*100).round()}% sobre el periodo anterior.',
      'Revisa técnica, RIR y rango de repeticiones antes de considerar una progresión.')];
    if(change.abs()<=.025)return const [SmartCoachInsight(SmartCoachKind.plateau,
      'Dos ventanas comparables con e1RM estimado similar.',
      'Comprueba si el objetivo y las condiciones son comparables; mantener puede ser apropiado.')];
    return const [];
  }
  static List<SmartCoachInsight> recovery(CoachCheckin item,{required DateTime now}){
    if(!_fresh(item.createdAt,now)||item.energy<1||item.energy>5||item.recovery<1||item.recovery>5)return const [];
    if(item.energy<=2||item.recovery<=2)return [SmartCoachInsight(SmartCoachKind.recovery,
      'Check-in registrado: energía ${item.energy}/5, recuperación ${item.recovery}/5.',
      'Conversa sobre descanso y carga percibida antes de ajustar el plan. No es un diagnóstico.')];
    return const [];
  }
}
