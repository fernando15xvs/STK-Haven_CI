import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

import '../../application/motivation_playback.dart';

/// Advanced settings only affect STK Motivation, never other apps or timers.
class MotivationAudioSettingsSheet extends StatefulWidget {
  const MotivationAudioSettingsSheet({super.key});

  @override
  State<MotivationAudioSettingsSheet> createState() =>
      _MotivationAudioSettingsSheetState();
}

class _MotivationAudioSettingsSheetState
    extends State<MotivationAudioSettingsSheet> {
  final playback = MotivationPlayback.instance;
  late double volume = playback.volume;
  late double speed = playback.speed;

  @override
  void initState() {
    super.initState();
    unawaited(playback.loadAudioPreferences().then((_) {
      if (mounted) setState(() {
        volume = playback.volume;
        speed = playback.speed;
      });
    }));
  }

  String _remaining(Duration time) {
    final total = (time.inSeconds + 59) ~/ 60;
    final hours = total ~/ 60;
    final minutes = total % 60;
    return hours > 0 ? '${hours}h ${minutes}min' : '${total} min';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Ajustes de audio',
                      style: AppTypography.headlineLarge),
                ),
                IconButton(
                  tooltip: 'Cerrar ajustes',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text('Solo cambia el reproductor STK Motivation.',
                style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary)),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.volume_up_outlined),
                const SizedBox(width: 8),
                const Expanded(child: Text('Volumen')),
                Text('${(volume * 100).round()} %'),
              ],
            ),
            Slider(
              key: const ValueKey('motivation_volume'),
              min: 0,
              max: 1,
              value: volume,
              onChanged: (v) => setState(() => volume = v),
              onChangeEnd: (v) => unawaited(playback.setVolume(v)),
            ),
            Row(
              children: [
                const Icon(Icons.speed),
                const SizedBox(width: 8),
                const Expanded(child: Text('Velocidad')),
                Text('${speed.toStringAsFixed(2)}×'),
              ],
            ),
            Slider(
              key: const ValueKey('motivation_speed'),
              min: 0.75,
              max: 1.5,
              divisions: 15,
              value: speed,
              onChanged: (v) => setState(() => speed = v),
              onChangeEnd: (v) => unawaited(playback.setSpeed(v)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    speed = 1;
                    volume = 1;
                  });
                  unawaited(playback.setSpeed(1));
                  unawaited(playback.setVolume(1));
                },
                child: const Text('Restaurar audio normal'),
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.bedtime_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Text('Temporizador de apagado',
                    style: AppTypography.headlineMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Detiene los audios de STK Motivation al cumplirse el tiempo, '
              'aunque cambies de pantalla. No modifica los descansos.',
              style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: playback.sleepTimer,
              builder: (context, _) {
                final timer = playback.sleepTimer;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (timer.active)
                      Text('Se detendrá en ${_remaining(timer.remaining)}',
                          key: const ValueKey('motivation_sleep_remaining'),
                          style: TextStyle(color: colors.primary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final minutes in const [5, 10, 15, 30, 45, 60])
                          ActionChip(
                            label: Text('${minutes} min'),
                            onPressed: playback.currentTrack == null
                                ? null
                                : () => playback.setSleepTimer(
                                      Duration(minutes: minutes)),
                          ),
                        if (timer.active)
                          InputChip(
                            label: const Text('Cancelar temporizador'),
                            onPressed: playback.cancelSleepTimer,
                          ),
                      ],
                    ),
                    if (playback.currentTrack == null)
                      const Text('Primero reproduce un archivo para activar '
                          'el temporizador.'),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Nota: el sistema puede suspender procesos en segundo plano. '
              'Verifica el apagado con la pantalla bloqueada en tu dispositivo.',
              style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
