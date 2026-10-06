import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrainingPreferencesPage extends ConsumerWidget {
  const TrainingPreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Entrenamiento y unidades')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'Unidades y progresión',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Unidad de peso'),
                subtitle: const Text(
                  'Se usa en entrenamientos, progresión y registros.',
                ),
                trailing: DropdownButton<WeightUnit>(
                  value: settings.weightUnit,
                  items: WeightUnit.values
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit.label.toUpperCase()),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (unit) {
                    if (unit != null) notifier.setWeightUnit(unit);
                  },
                ),
              ),
              const Divider(height: 1),
              Builder(
                builder: (context) {
                  final unit = settings.weightUnit;
                  final options = unit == WeightUnit.kg
                      ? const [1.25, 2.5, 5.0]
                      : const [2.5, 5.0, 10.0];
                  final current = WeightConverter.displayWeight(
                    settings.defaultIncrement,
                    unit,
                  );
                  final selected = options.reduce(
                    (a, b) => (a - current).abs() < (b - current).abs()
                        ? a
                        : b,
                  );

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incremento por defecto'),
                    subtitle: const Text(
                      'Sugerencia de aumento en los motores de progresión.',
                    ),
                    trailing: DropdownButton<double>(
                      value: selected,
                      items: options
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                '${value % 1 == 0 ? value.toInt() : value} '
                                '${unit.label}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          notifier.setDefaultIncrement(value, unit);
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Registro y memoria',
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Registrar RIR'),
                subtitle: const Text(
                  'Muestra RIR en series de trabajo y lo usa como evidencia de progresión.',
                ),
                value: settings.isRirEnabled,
                onChanged: notifier.setRirEnabled,
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Precargar última ejecución'),
                subtitle: const Text(
                  'Copia peso, reps y RIR desde Exercise Memory; conserva objetivos y descansos de la rutina actual.',
                ),
                value: settings.prefillExerciseMemoryByDefault,
                onChanged: notifier.setPrefillExerciseMemoryByDefault,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Descanso y feedback',
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Descanso automático'),
                subtitle: const Text(
                  'Inicia el temporizador correspondiente al completar trabajo válido.',
                ),
                value: settings.autoRestEnabled,
                onChanged: notifier.setAutoRestEnabled,
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vibración'),
                subtitle: Text(
                  kIsWeb
                      ? 'La preferencia se conserva para Android/iOS.'
                      : 'Feedback al registrar series/lados y en el aviso de descanso.',
                ),
                value: settings.vibrationEnabled,
                onChanged: kIsWeb ? null : notifier.setVibrationEnabled,
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sonido al terminar descanso'),
                subtitle: Text(
                  kIsWeb
                      ? 'La preferencia se conserva para Android/iOS.'
                      : 'Controla el sonido del aviso del temporizador.',
                ),
                value: settings.timerSoundEnabled,
                onChanged: kIsWeb ? null : notifier.updateTimerSound,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Unilateral Pro · predeterminados',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Descanso entre lados por defecto'),
                subtitle: const Text(
                  'Se aplica al añadir un ejercicio unilateral nuevo. '
                  'Cada ejercicio puede sobrescribirlo.',
                ),
                trailing: DropdownButton<int>(
                  value: settings.unilateralSideRestSeconds,
                  items: const [0, 30, 45, 60, 90, 120, 180]
                      .map(
                        (seconds) => DropdownMenuItem(
                          value: seconds,
                          child: Text(
                            seconds == 0 ? 'Cambio directo' : '${seconds}s',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (seconds) {
                    if (seconds != null) {
                      notifier.setUnilateralSideRestSeconds(seconds);
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mismo peso para ambos lados'),
                subtitle: const Text(
                  'El segundo lado hereda la carga del primero; reps y RIR siguen siendo independientes.',
                ),
                value: settings.unilateralSameWeightByDefault,
                onChanged: notifier.setUnilateralSameWeightByDefault,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lado inicial por defecto'),
                subtitle: const Text(
                  'Guía visual para ejercicios nuevos; cada ejercicio puede '
                  'elegir Izquierda, Derecha o Automático.',
                ),
                trailing: DropdownButton<PreferredWorkoutSide>(
                  value: settings.preferredUnilateralStartSide,
                  items: PreferredWorkoutSide.values
                      .map(
                        (side) => DropdownMenuItem(
                          value: side,
                          child: Text(side.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (side) {
                    if (side != null) {
                      notifier.setPreferredUnilateralStartSide(side);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        ),
      );
}
