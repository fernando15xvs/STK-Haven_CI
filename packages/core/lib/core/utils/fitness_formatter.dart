import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/personal_record.dart';
import 'package:core/domain/models/progression_suggestion.dart';
import 'package:core/domain/models/settings_state.dart';

/// Centralises ALL user-facing formatting of physical quantities.
class FitnessFormatter {
  FitnessFormatter._();

  static String formatWeight(double weightKg, WeightUnit unit) {
    return WeightConverter.formatWeight(weightKg, unit);
  }

  static String formatVolume(double volumeKg, WeightUnit unit) {
    final converted = WeightConverter.displayWeight(volumeKg, unit);
    final label = unit.label;
    if (converted >= 1000) {
      return '${(converted / 1000).toStringAsFixed(1)}k $label';
    }
    return '${converted.toStringAsFixed(0)} $label';
  }

  static String formatProgressionTarget(
    double suggestedWeightKg,
    int repsMin,
    int repsMax,
    WeightUnit unit,
  ) {
    final displayValue = WeightConverter.displayWeight(suggestedWeightKg, unit);
    final weightStr = displayValue % 1 == 0
        ? '${displayValue.toInt()}'
        : displayValue.toStringAsFixed(1);
    final repsStr = repsMin == repsMax ? '$repsMin' : '$repsMin-$repsMax';
    return '$weightStr ${unit.label} × $repsStr';
  }

  static String progressionTitle(ProgressionSuggestion suggestion) {
    if (suggestion.reason == ProgressionReason.differentRepContext) {
      return 'Contexto distinto entre rutinas';
    }
    return switch (suggestion.type) {
      ProgressionType.increase => 'Progresión gradual disponible',
      ProgressionType.maintain => 'Mantén la referencia',
      ProgressionType.deload => 'Ajuste opcional de descarga',
      ProgressionType.insufficientData => 'Registra más datos',
    };
  }

  static String progressionExplanation(ProgressionSuggestion suggestion) {
    return switch (suggestion.reason) {
      ProgressionReason.consistentTopRange =>
        'Dos sesiones comparables alcanzaron el rango alto con margen suficiente.',
      ProgressionReason.confirmTopRange =>
        'Alcanzaste el rango alto una vez; confírmalo con ejecución estable antes de cambiar la carga.',
      ProgressionReason.buildRepetitions =>
        'Mantén la carga y prioriza repeticiones controladas dentro del rango.',
      ProgressionReason.incompleteWorkSets =>
        'Faltan series de trabajo completadas para calcular una referencia fiable.',
      ProgressionReason.missingRir =>
        'Falta el RIR de alguna serie; no se propone aumentar la carga.',
      ProgressionReason.effortTooHigh =>
        'El esfuerzo quedó muy cerca del límite; mantén la carga y prioriza control.',
      ProgressionReason.recoveryCaution =>
        'El check-in sugiere moderar la exigencia; no se propone aumentar la carga.',
      ProgressionReason.invalidLoad =>
        'La carga registrada no permite calcular un incremento fiable.',
      ProgressionReason.plateau =>
        'Varias sesiones sin cambio sugieren valorar una descarga temporal.',
      ProgressionReason.differentRepContext =>
        'La última ejecución usa un rango de repeticiones distinto. Se conserva la carga como referencia y se usa e1RM/RIR como contexto, sin copiar una progresión automática.',
    };
  }

  static String progressionEvidence(ProgressionSuggestion suggestion) {
    final sourceParts = <String>[];
    final sourceDate = suggestion.sourcePerformedAt;
    if (sourceDate != null) {
      sourceParts.add('Última vez: ${_shortDate(sourceDate)}');
    }
    final routine = suggestion.sourceRoutineName?.trim();
    if (routine != null && routine.isNotEmpty) sourceParts.add(routine);

    if (suggestion.differentContext) {
      sourceParts.add('Contexto distinto');
      if (suggestion.sourceRepsMin != null && suggestion.sourceRepsMax != null) {
        final min = suggestion.sourceRepsMin!;
        final max = suggestion.sourceRepsMax!;
        sourceParts.add(min == max ? '$min reps' : '$min-$max reps');
      }
      if (suggestion.sourceEstimated1RmKg != null) {
        sourceParts.add('e1RM/RIR considerado');
      }
      return sourceParts.join(' · ');
    }

    if (sourceParts.isNotEmpty) {
      if (suggestion.evidenceSessions > 1) {
        sourceParts.add('${suggestion.evidenceSessions} sesiones comparables');
      }
      return sourceParts.join(' · ');
    }

    if (suggestion.evidenceSessions <= 1) {
      return 'Basado en la sesión más reciente';
    }
    return 'Basado en ${suggestion.evidenceSessions} sesiones comparables';
  }

  static String _shortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  static const String progressionSafetyNote =
      'Referencia opcional: la técnica, el control y entrenar sin molestias tienen prioridad.';

  static String formatPRValue(double valueKg, PRType type, WeightUnit unit) {
    switch (type) {
      case PRType.maxWeight:
      case PRType.estimated1RM:
        return formatWeight(valueKg, unit);
      case PRType.bestSetVolume:
        return _formatSetVolume(valueKg, unit);
    }
  }

  static String _formatSetVolume(double volumeKg, WeightUnit unit) {
    final converted = WeightConverter.displayWeight(volumeKg, unit);
    final label = unit.label;
    if (converted % 1 == 0) {
      return '${converted.toInt()} $label·reps';
    }
    return '${converted.toStringAsFixed(1)} $label·reps';
  }
}
