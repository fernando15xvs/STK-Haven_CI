import 'package:core/domain/models/coach_client_progress.dart';
import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:core/features/coach_pro/application/coach_pro_nutrition_provider.dart';
import 'package:core/features/coach_pro/application/coach_pro_task_provider.dart';
import 'package:core/features/coach_pro/application/coach_pro_program_provider.dart';
import 'package:core/features/coach_pro/application/coach_pro_program_revision_provider.dart';
import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/features/coach_pro/domain/coach_pro_task_summary.dart';
import 'dart:async';

import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/coach_checkin.dart';
import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/features/coach_pro/application/coach_pro_client_detail_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_client_detail_service.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_client_detail_page.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Identity extends AppIdentityNotifier {
  @override
  AppIdentityState build() => const AppIdentityState(
    sessionKind: AppSessionKind.permanent, userId: 'coach',
  );
  void signOutForTest() => state = const AppIdentityState();
}

CoachProClientDetail _detail({bool permitted = true, String note = 'Nota compartida', bool programs = false, bool tasks = false, bool workouts = false, bool progress = false, bool missingProgress = false, bool nutrition = false}) =>
    CoachProClientDetail(CoachProClientSummary.fromJson({
      'relationship_id': 'rel', 'client_user_id': 'client', 'display_name': 'Ana',
      'relationship_status': 'active', 'permissions': {'view_checkins': permitted, 'assign_programs': programs, 'assign_tasks': tasks, 'view_workouts': workouts, 'view_progress': progress, 'view_nutrition': nutrition},
      'workouts_7d': 99,
    }), nutrition: CoachProSectionPage(totalCount: 26, items: [NutritionGuidanceSummary(
      id: 'plan', relationshipId: 'rel', coachUserId: 'coach', clientUserId: 'client',
      status: NutritionGuidanceStatus.active, currentVersion: 2, title: 'Plan compartido', updatedAt: DateTime(2026))]),
    progress: missingProgress ? null : CoachClientProgress(
      workouts7d: 0,
      workouts30d: 0,
      trainingMinutes7d: 0,
      completedWorkingSets7d: 0,
      volume7d: 0,
      generatedAt: DateTime(2026, 9, 1),
      trendBaselineAvailable: true,
      workoutsPrevious7d: 2,
      trainingMinutesPrevious7d: 90,
      completedWorkingSetsPrevious7d: 18,
      volumePrevious7d: 4200,
      frequencyAdherence: CoachFrequencyAdherence(
        assignmentId: 'assignment',
        assignmentName: 'Programa fuerza',
        startsOn: DateTime(2026, 8, 1),
        endsOn: DateTime(2026, 10, 31),
        scheduledSessions7d: 3,
        completedSessions7d: 0,
        percent7d: 0,
        scheduledSessions30d: 13,
        completedSessions30d: 0,
        percent30d: 0,
      ),
    ),
    workouts: CoachProSectionPage(totalCount: 27, items: [
      CoachSharedWorkoutSummary(workoutId: 'w', startedAt: DateTime(2026, 10, 1),
        routineName: 'Rutina compartida', durationSeconds: 1200, plannedWorkingSets: 10,
        completedWorkingSets: 8, completionPercent: 80, volume: 2400),
    ]), checkins: CoachProCheckinPage(totalCount: 26, items: [
      CoachCheckin.fromJson({'id': 'checkin', 'relationship_id': 'rel',
        'energy': 3, 'recovery': 4, 'note': note, 'created_at': '2026-10-02T00:00:00Z'}),
    ]), programs: CoachProSectionPage(totalCount: 26, items: [
      CoachProgramAssignmentSummary.fromJson({'id': 'p', 'relationship_id': 'rel',
        'name': 'Programa fuerza', 'version': 2, 'status': 'accepted',
        'duration_weeks': 8, 'starts_on': '2026-10-01',
        'created_at': '2026-10-01T00:00:00Z', 'updated_at': '2026-10-02T00:00:00Z'}),
    ]), tasks: CoachProSectionPage(totalCount: 26, items: [
      CoachProTaskSummary.fromJson({'id': 't', 'relationship_id': 'rel',
        'title': 'Tarea movilidad', 'category': 'General', 'status': 'active',
        'starts_on': '2026-10-01', 'updated_at': '2026-10-02T00:00:00Z'}),
    ]));

Future<ProviderContainer> _mount(WidgetTester tester, {
  double width = 390, double scale = 1,
  required Future<CoachProClientDetail?> Function(CoachProClientDetailQuery) load,
}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    appIdentityProvider.overrideWith(_Identity.new),
    coachProTaskPageProvider.overrideWith((ref, query) async => null),
    coachProNutritionProvider.overrideWith((ref, query) async {
      expect(query.planId, 'plan'); expect(query.version, 2); expect(query.relationshipId, 'rel');
      return null;
    }),
    coachProProgramPageProvider.overrideWith((ref, query) async => null),
    coachProProgramRevisionHistoryProvider.overrideWith((ref, query) async => null),
    coachProClientDetailProvider.overrideWith((ref, query) => load(query)),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container,
    child: MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!), home: const CoachProClientDetailPage(relationshipId: 'rel')),
  ));
  await tester.pump();
  return container;
}

void main() {
  testWidgets('nutrition list loads lazily, paginates and opens the selected version', (tester) async {
    final queries = <CoachProClientDetailQuery>[];
    await _mount(tester, load: (q) async { queries.add(q); return _detail(nutrition: true); });
    expect(find.text('Plan compartido'), findsNothing);
    await tester.tap(find.text('Alimentación')); await tester.pumpAndSettle();
    expect(queries.last.section, CoachProClientSection.nutrition);
    expect(find.text('Plan compartido'), findsOneWidget);
    await tester.ensureVisible(find.text('Siguiente')); await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente')); await tester.pumpAndSettle();
    expect(queries.last.offset, 25);
    await tester.ensureVisible(find.text('Ver orientación')); await tester.pumpAndSettle();
    await tester.tap(find.text('Ver orientación')); await tester.pumpAndSettle();
    expect(find.text('Orientación no disponible.'), findsOneWidget);
  });
  testWidgets('nutrition consent masks an injected list independently of other permissions', (tester) async {
    await _mount(tester, width: 320, scale: 1.8, load: (_) async => _detail(progress: true, workouts: true));
    await tester.tap(find.text('Alimentación')); await tester.pumpAndSettle();
    expect(find.text('Plan compartido'), findsNothing);
    expect(find.text('Orientación alimentaria: no compartida en esta relación.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('progress snapshot at $width displays recorded zero and missing RIR with period context', (tester) async {
      final queries = <CoachProClientDetailQuery>[];
      await _mount(tester, width: width, load: (q) async { queries.add(q); return _detail(progress: true); });
      expect(find.textContaining('Instantánea generada:'), findsNothing);
      await tester.tap(find.text('Progreso')); await tester.pumpAndSettle();
      expect(queries.last.section, CoachProClientSection.progress);
      expect(find.text('Minutos de entrenamiento en 7 días: 0'), findsOneWidget);
      expect(find.text('RIR medio en 7 días: Sin datos'), findsOneWidget);
      expect(find.textContaining('Instantánea generada:'), findsOneWidget);
      expect(find.textContaining('corresponden a esa instantánea'), findsOneWidget);
      expect(find.text('Tendencia reciente'), findsOneWidget);
      expect(find.text('Entrenos: -2 vs. los 7 días anteriores'), findsOneWidget);
      expect(find.text('Adherencia de frecuencia'), findsOneWidget);
      expect(find.textContaining('Programa fuerza · 7 días: 0% (0/3)'), findsOneWidget);
      expect(find.textContaining('no confirma que se haya realizado la rutina exacta'), findsOneWidget);
      expect(find.text('Siguiente'), findsNothing); expect(find.text('Rutina compartida'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('progress explains when trend or adherence baseline is unavailable', (tester) async {
    await _mount(
      tester,
      load: (_) async => CoachProClientDetail(
        CoachProClientSummary.fromJson({
          'relationship_id': 'rel',
          'client_user_id': 'client',
          'display_name': 'Ana',
          'relationship_status': 'active',
          'permissions': {'view_progress': true},
        }),
        progress: CoachClientProgress(
          workouts7d: 2,
          workouts30d: 8,
          trainingMinutes7d: 100,
          completedWorkingSets7d: 20,
          volume7d: 5000,
          generatedAt: DateTime(2026, 10, 7),
        ),
      ),
    );
    await tester.tap(find.text('Progreso'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Aún no hay una ventana anterior comparable'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Requiere un programa aceptado'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress distinguishes denied permission from missing snapshot and redacts on refresh', (tester) async {
    bool permitted = false, missing = false, refresh = false;
    final pending = Completer<CoachProClientDetail?>();
    await _mount(tester, width: 320, scale: 1.8,
      load: (_) => refresh ? pending.future : Future.value(_detail(progress: permitted, missingProgress: missing)));
    await tester.tap(find.text('Progreso')); await tester.pumpAndSettle();
    expect(find.text('Progreso: no compartido en esta relación.'), findsOneWidget);
    expect(find.textContaining('Instantánea generada:'), findsNothing);
    permitted = true; missing = true;
    await tester.tap(find.text('Actualizar')); await tester.pumpAndSettle();
    expect(find.text('Todavía no hay una instantánea de progreso compartida.'), findsOneWidget);
    expect(find.text('Minutos de entrenamiento en 7 días: 0'), findsNothing);
    missing = false; await tester.tap(find.text('Actualizar')); await tester.pumpAndSettle();
    expect(find.text('Minutos de entrenamiento en 7 días: 0'), findsOneWidget);
    refresh = true; await tester.tap(find.text('Actualizar')); await tester.pump();
    expect(find.text('Minutos de entrenamiento en 7 días: 0'), findsNothing);
    pending.completeError(StateError('private detail')); await tester.pumpAndSettle();
    expect(find.textContaining('private detail'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget); expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('workout summaries at $width paginate only on selection', (tester) async {
      final queries = <CoachProClientDetailQuery>[];
      await _mount(tester, width: width, load: (q) async { queries.add(q); return _detail(workouts: true); });
      expect(find.text('Rutina compartida'), findsNothing);
      await tester.tap(find.text('Entrenamientos')); await tester.pumpAndSettle();
      expect(queries.last.section, CoachProClientSection.workouts);
      expect(find.text('Rutina compartida'), findsOneWidget);
      expect(find.text('RIR medio: Sin datos'), findsOneWidget);
      expect(find.textContaining('No es el historial completo'), findsOneWidget);
      await tester.ensureVisible(find.text('Siguiente')); await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente')); await tester.pumpAndSettle();
      expect(queries.last.offset, 25); expect(find.text('Rutina compartida'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('workout permission masks injected payload and refresh redacts prior page', (tester) async {
    bool permitted = false, refreshing = false;
    final pending = Completer<CoachProClientDetail?>();
    final container = await _mount(tester, width: 320, scale: 1.8,
      load: (_) => refreshing ? pending.future : Future.value(_detail(workouts: permitted)));
    await tester.tap(find.text('Entrenamientos')); await tester.pumpAndSettle();
    expect(find.text('Rutina compartida'), findsNothing);
    expect(find.text('Entrenamientos: no compartidos en esta relación.'), findsOneWidget);
    permitted = true; await tester.tap(find.text('Actualizar')); await tester.pumpAndSettle();
    expect(find.text('Rutina compartida'), findsOneWidget);
    refreshing = true; await tester.tap(find.text('Actualizar')); await tester.pump();
    expect(find.text('Rutina compartida'), findsNothing);
    pending.completeError(StateError('private data')); await tester.pumpAndSettle();
    expect(find.textContaining('private data'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    await tester.pumpAndSettle(); expect(find.text('Rutina compartida'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('detail at $width respects permission and loads selected page', (tester) async {
      final queries = <CoachProClientDetailQuery>[];
      await _mount(tester, width: width, load: (query) async {
        queries.add(query); return _detail();
      });
      expect(find.text('Ana'), findsOneWidget);
      expect(find.textContaining('99'), findsNothing);
      expect(find.text('Nota compartida'), findsNothing);
      await tester.tap(find.text('Check-ins'));
      await tester.pumpAndSettle();
      expect(find.text('Nota compartida'), findsOneWidget);
      await tester.ensureVisible(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(queries.last.offset, 25);
      expect(queries.last.relationshipId, 'rel');
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 1440.0]) {
    for (final section in [CoachProClientSection.programs, CoachProClientSection.tasks]) {
      testWidgets('$section at $width paginates and section changes reset offset', (tester) async {
        final queries = <CoachProClientDetailQuery>[];
        await _mount(tester, width: width, load: (query) async {
          queries.add(query); return _detail(programs: true, tasks: true);
        });
        final programs = section == CoachProClientSection.programs;
        await tester.tap(find.text(programs ? 'Programas' : 'Tareas'));
        await tester.pumpAndSettle();
        expect(find.text(programs ? 'Programa fuerza' : 'Tarea movilidad'), findsOneWidget);
        expect(find.text(programs ? 'Tarea movilidad' : 'Programa fuerza'), findsNothing);
        await tester.ensureVisible(find.text('Siguiente'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        expect(queries.last.offset, 25);
        expect(queries.last.section, section);
        await tester.ensureVisible(find.text(programs ? 'Tareas' : 'Programas'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(programs ? 'Tareas' : 'Programas'));
        await tester.pumpAndSettle();
        expect(queries.last.offset, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('independent permissions mask even an injected section payload', (tester) async {
    await _mount(tester, width: 320, scale: 1.8,
      load: (_) async => _detail(programs: false, tasks: true));
    await tester.tap(find.text('Programas'));
    await tester.pumpAndSettle();
    expect(find.text('Programas: no compartidos en esta relación.'), findsOneWidget);
    expect(find.text('Programa fuerza'), findsNothing);
    await tester.tap(find.text('Tareas'));
    await tester.pumpAndSettle();
    expect(find.text('Tarea movilidad'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('late program response cannot replace a selected task section', (tester) async {
    final pending = Completer<CoachProClientDetail?>();
    await _mount(tester, load: (query) => query.section == CoachProClientSection.programs
        ? pending.future : Future.value(_detail(programs: true, tasks: true)));
    await tester.tap(find.text('Programas'));
    await tester.pump();
    await tester.tap(find.text('Tareas'));
    await tester.pumpAndSettle();
    pending.complete(_detail(programs: true, tasks: true));
    await tester.pumpAndSettle();
    expect(find.text('Tarea movilidad'), findsOneWidget);
    expect(find.text('Programa fuerza'), findsNothing);
  });

  testWidgets('program card opens versioned professional detail', (tester) async {
    await _mount(tester, load: (_) async => _detail(programs: true));
    await tester.tap(find.text('Programas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver rutinas'));
    await tester.pumpAndSettle();
    expect(find.text('Programa asignado'), findsOneWidget);
    expect(find.text('Programa no disponible.'), findsOneWidget);
  });

  testWidgets('program card opens immutable revision history', (tester) async {
    await _mount(tester, load: (_) async => _detail(programs: true));
    await tester.tap(find.text('Programas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Historial de revisiones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historial de revisiones'));
    await tester.pumpAndSettle();
    expect(find.text('Historial de revisiones'), findsOneWidget);
    expect(find.text('Historial no disponible.'), findsOneWidget);
  });

  testWidgets('task card opens professional history', (tester) async {
    await _mount(tester, load: (_) async => _detail(tasks: true));
    await tester.tap(find.text('Tareas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver historial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver historial'));
    await tester.pumpAndSettle();
    expect(find.text('Tarea asignada'), findsOneWidget);
    expect(find.text('Tarea no disponible.'), findsOneWidget);
  });

  testWidgets('missing permission cannot render check-in payload, including large text', (tester) async {
    await _mount(tester, width: 320, scale: 1.8,
      load: (_) async => _detail(permitted: false));
    await tester.tap(find.text('Check-ins'));
    await tester.pumpAndSettle();
    expect(find.text('Check-ins: no compartidos en esta relación.'), findsOneWidget);
    expect(find.text('Nota compartida'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('refresh clears old content while loading and on error', (tester) async {
    var refresh = false;
    final pending = Completer<CoachProClientDetail?>();
    await _mount(tester, load: (_) => refresh ? pending.future : Future.value(_detail()));
    refresh = true;
    await tester.tap(find.text('Actualizar'));
    await tester.pump();
    expect(find.text('Ana'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('private backend detail'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsNothing);
    expect(find.textContaining('private backend detail'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
  });
  testWidgets('sign-out removes shared notes and prevents further navigation', (tester) async {
    final container = await _mount(tester, load: (_) async => _detail());
    await tester.tap(find.text('Check-ins'));
    await tester.pumpAndSettle();
    expect(find.text('Nota compartida'), findsOneWidget);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    await tester.pumpAndSettle();
    expect(find.text('Nota compartida'), findsNothing);
    expect(find.text('Siguiente'), findsNothing);
    expect(find.textContaining('cuenta permanente'), findsOneWidget);
  });
  testWidgets('unavailable relationship has no stale summary', (tester) async {
    await _mount(tester, load: (_) async => null);
    expect(find.text('La relación no está disponible.'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
  });
}
