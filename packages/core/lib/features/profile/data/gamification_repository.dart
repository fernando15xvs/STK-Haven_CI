import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/domain/models/gamification_state.dart';

class GamificationRepository {
  final Box _box;
  static const String _stateKey = 'gamification_state';

  GamificationRepository(this._box);

  GamificationState getGamificationState() {
    final Map<dynamic, dynamic>? rawData = _box.get(_stateKey);
    if (rawData == null) {
      return _getInitialState();
    }
    
    final Map<String, dynamic> json = Map<String, dynamic>.from(rawData);
    return GamificationState.fromJson(json);
  }

  Future<void> saveGamificationState(GamificationState state) async {
    await _box.put(_stateKey, state.toJson());
  }

  GamificationState _getInitialState() {
    // Initial achievements that users can unlock
    return const GamificationState(
      achievements: [
        Achievement(
          id: 'first_workout',
          title: 'Primer Paso',
          description: 'Completa tu primer entrenamiento.',
        ),
        Achievement(
          id: 'volume_1000',
          title: 'Levantador de Pesas',
          description: 'Levanta 1000 kg de volumen total acumulado.',
        ),
        Achievement(
          id: 'streak_3',
          title: 'Constante',
          description: 'Completa entrenamientos en 3 días diferentes seguidos.',
        ),
        Achievement(
          id: 'first_pr',
          title: 'Rompiendo Límites',
          description: 'Logra tu primer Récord Personal (PR).',
        ),
      ],
    );
  }
}
