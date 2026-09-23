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
      appBar: AppBar(title: const Text('Preferencias de entrenamiento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  'Inicia el timer correspondiente al completar trabajo válido.',
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
                      : 'Controla el sonido del aviso programado del timer.',
                ),
                value: settings.timerSoundEnabled,
                onChanged: kIsWeb ? null : notifier.updateTimerSound,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Unilateral Pro',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Descanso entre lados'),
                subtitle: const Text(
                  'Independiente del descanso posterior a la serie completa.',
                ),
                trailing: DropdownButton<int>(
                  value: settings.unilateralSideRestSeconds,
                  items: const [0, 30, 45, 60, 90, 120, 180]
                      .map(
                        (seconds) => DropdownMenuItem(
                          value: seconds,
                          child: Text(
                            seconds == 0 ? 'Sin descanso' : '${seconds}s',
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
                title: const Text('Lado inicial preferido'),
                subtitle: const Text('Guía visual; no bloquea el otro lado.'),
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
          const SizedBox(height: 14),
          _Section(
            title: 'Rendimiento y accesibilidad',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Modo rendimiento'),
                subtitle: Text(_performanceDescription(settings.performanceMode)),
                trailing: DropdownButton<PerformanceMode>(
                  value: settings.performanceMode,
                  items: PerformanceMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (mode) {
                    if (mode != null) notifier.setPerformanceMode(mode);
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reducir movimiento'),
                subtitle: const Text(
                  'Reduce transiciones y efectos sin cambiar cálculos ni datos.',
                ),
                value: settings.reduceMotion,
                onChanged: notifier.setReduceMotion,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _performanceDescription(PerformanceMode mode) => switch (mode) {
        PerformanceMode.automatic =>
          'Equilibra efectos visuales con las preferencias del sistema.',
        PerformanceMode.quality =>
          'Prioriza presentación visual cuando el dispositivo puede sostenerla.',
        PerformanceMode.savings =>
          'Reduce animaciones, blur y coste gráfico antes de reducir funcionalidad.',
      };
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
