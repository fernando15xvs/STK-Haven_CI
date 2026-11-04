import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/progress/application/calendar_heatmap_calculator.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/theme/components/metric_tile.dart';
import 'package:gym_tracker/features/progress/presentation/pages/progress_page.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/calendar_heatmap_card.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_consistency_metrics.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_insights_panel.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_volume_headline.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/volume_chart.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _History extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() => const [];
}

class _Exercises extends ExerciseListNotifier {
  @override
  List<Exercise> build() => const [];
}

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

DashboardMetrics _demoMetrics() {
  final today = DateTime.now();
  final first = DateTime(today.year, today.month, today.day);
  return DashboardMetrics(
    totalVolume: 15912,
    volumePercentChange: 14.5,
    volumeChartData: [
      VolumeDataPoint(first.subtract(const Duration(days: 12)), 3000),
      VolumeDataPoint(first.subtract(const Duration(days: 2)), 15912),
    ],
    workoutCount: 2,
    totalSets: 7,
    totalDurationSeconds: 9100,
    prCount: 1,
    activeDays: 2,
    workoutsPerWeek: 1.4,
    averageSessionMinutes: 75.8,
    workoutFrequencyPercentChange: 5,
    calendarHeatmap: CalendarHeatmapSnapshot.fromSessions(
      const [],
      startDate: first.subtract(const Duration(days: 29)),
      endDate: first,
    ),
  );
}

void main() {
  setUpAll(() async => initializeDateFormatting('es'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('Resumen 320px ${brightness.name} text=$scale has one role per section',
          (tester) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final colors = AppColors.from(
          AppearanceSettings(
            accent: AppAccent.emerald,
            oledBlack: brightness == Brightness.dark,
          ),
          brightness,
        );
        await tester.pumpWidget(ProviderScope(
          overrides: [
            progressMetricsProvider.overrideWith((ref) => _demoMetrics()),
            workoutHistoryProvider.overrideWith(_History.new),
            exerciseListProvider.overrideWith(_Exercises.new),
            settingsProvider.overrideWith(_Settings.new),
          ],
          child: MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              fontFamily: 'Outfit',
              extensions: [colors],
            ),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 850),
                  textScaler: TextScaler.linear(scale),
                ),
                child: const ProgressSummaryTab(),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'initial summary layout must fit 320px');

        // These sections are the only owners of summary overview data.
        expect(find.text('VOLUMEN TOTAL'), findsOneWidget);
        expect(find.text('TENDENCIA DE VOLUMEN · 1M'), findsOneWidget);
        expect(find.byType(ProgressVolumeHeadline), findsOneWidget);
        expect(find.byType(VolumeChart), findsOneWidget);
        expect(find.byType(ProgressConsistencyMetrics), findsOneWidget);
        expect(find.text('CONSISTENCIA'), findsOneWidget);

        // Summary no longer duplicates History and independent KPI cards.
        expect(find.text('ENTRENAMIENTOS RECIENTES'), findsNothing);
        expect(find.textContaining('ESTE PERIODO ('), findsNothing);
        expect(find.byType(MetricTile), findsNothing);
        expect(find.text('Récords'), findsNothing);

        // Calendar and verifiable observations remain reachable by scrolling.
        await tester.scrollUntilVisible(
          find.byType(CalendarHeatmapCard),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(CalendarHeatmapCard), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'calendar section must not overflow at 320px');
        await tester.scrollUntilVisible(
          find.byType(ProgressInsightsPanel),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(ProgressInsightsPanel), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
