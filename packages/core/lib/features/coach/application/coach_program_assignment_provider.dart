import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/coach/application/coach_program_installer.dart';
import 'package:core/features/coach/application/coach_program_revision_acceptance_provider.dart';
import 'package:core/features/coach/application/coach_program_payload_builder.dart';
import 'package:core/features/coach/data/coach_program_assignment_service.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum CoachProgramAssignmentOperation {
  idle,
  loading,
  assigning,
  opening,
  accepting,
  checkingRevisionInstall,
  installingRevision,
  archiving,
}

class CoachProgramAssignmentsState {
  final List<CoachProgramAssignmentSummary> assignments;
  final CoachProgramAssignment? selected;
  final CoachProgramAssignmentOperation operation;
  final String? message;
  final bool isError;

  const CoachProgramAssignmentsState({
    this.assignments = const <CoachProgramAssignmentSummary>[],
    this.selected,
    this.operation = CoachProgramAssignmentOperation.idle,
    this.message,
    this.isError = false,
  });

  bool get busy => operation != CoachProgramAssignmentOperation.idle;

  CoachProgramAssignmentsState copyWith({
    List<CoachProgramAssignmentSummary>? assignments,
    CoachProgramAssignment? selected,
    bool clearSelected = false,
    CoachProgramAssignmentOperation? operation,
    String? message,
    bool clearMessage = false,
    bool? isError,
  }) {
    return CoachProgramAssignmentsState(
      assignments: assignments ?? this.assignments,
      selected: clearSelected ? null : (selected ?? this.selected),
      operation: operation ?? this.operation,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

final coachProgramAssignmentServiceProvider =
    Provider<CoachProgramAssignmentService>((ref) {
  return CoachProgramAssignmentService(Supabase.instance.client);
});

final coachProgramInstallerProvider = Provider<CoachProgramInstaller>((ref) {
  return CoachProgramInstaller(
    exerciseRepository: ref.read(exerciseRepositoryProvider),
    routineRepository: ref.read(routineRepositoryProvider),
    programRepository: ref.read(trainingProgramRepositoryProvider),
    metadataBox: Hive.box<dynamic>(HiveBoxes.metadata),
  );
});

final coachProgramAssignmentsProvider = NotifierProvider<
    CoachProgramAssignmentsNotifier,
    CoachProgramAssignmentsState>(CoachProgramAssignmentsNotifier.new);

class CoachProgramAssignmentsNotifier
    extends Notifier<CoachProgramAssignmentsState> {
  late final CoachProgramAssignmentService _service;

  @override
  CoachProgramAssignmentsState build() {
    _service = ref.watch(coachProgramAssignmentServiceProvider);
    return const CoachProgramAssignmentsState();
  }

  Future<bool> refresh() async {
    if (!_requirePermanentAccount() || state.busy) return false;

    state = state.copyWith(
      operation: CoachProgramAssignmentOperation.loading,
      clearMessage: true,
      isError: false,
    );
    try {
      final assignments = await _service.listAssignments();
      state = state.copyWith(
        assignments: assignments,
        operation: CoachProgramAssignmentOperation.idle,
        isError: false,
      );
      return true;
    } on PostgrestException {
      _fail('Las asignaciones de programas aún no están disponibles.');
      return false;
    } catch (_) {
      _fail('No se pudieron cargar los programas asignados.');
      return false;
    }
  }

  Future<String?> assignLocalProgram({
    required String clientUserId,
    required String programId,
    required DateTime startsOn,
  }) async {
    if (!_requirePermanentAccount() || state.busy) return null;

    TrainingProgram? program;
    for (final item in ref.read(trainingProgramListProvider)) {
      if (item.id == programId) {
        program = item;
        break;
      }
    }
    if (program == null) {
      _fail('No se encontró el programa local seleccionado.');
      return null;
    }

    Map<String, dynamic> payload;
    try {
      payload = CoachProgramPayloadBuilder.build(
        program: program,
        routines: ref.read(routineListProvider),
        exercises: ref.read(exerciseListProvider),
        startsOn: startsOn,
      );
    } catch (error) {
      _fail(error.toString().replaceFirst('Bad state: ', ''));
      return null;
    }

    state = state.copyWith(
      operation: CoachProgramAssignmentOperation.assigning,
      clearMessage: true,
      isError: false,
    );

    try {
      final assignmentId = await _service.assignProgram(
        clientUserId: clientUserId,
        programPayload: payload,
      );
      final assignments = await _service.listAssignments();
      state = state.copyWith(
        assignments: assignments,
        operation: CoachProgramAssignmentOperation.idle,
        message: 'Programa asignado al cliente.',
        isError: false,
      );
      return assignmentId;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
      _fail('No se pudo asignar el programa.');
      return null;
    }
  }

  Future<CoachProgramAssignment?> openAssignment(String assignmentId) async {
    if (!_requirePermanentAccount() || state.busy) return null;
    state = state.copyWith(
      operation: CoachProgramAssignmentOperation.opening,
      clearMessage: true,
      isError: false,
    );

    try {
      final assignment = await _service.getAssignment(assignmentId);
      state = state.copyWith(
        selected: assignment,
        operation: CoachProgramAssignmentOperation.idle,
        isError: false,
      );
      return assignment;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
      _fail('No se pudo abrir el programa asignado.');
      return null;
    }
  }

  Future<bool> acceptAndInstall(
    String assignmentId, {
    bool activate = true,
  }) async {
    if (!_requirePermanentAccount() || state.busy) return false;

    state = state.copyWith(
      operation: CoachProgramAssignmentOperation.accepting,
      clearMessage: true,
      isError: false,
    );

    try {
      final assignment = await _service.getAssignment(assignmentId);
      final userId = ref.read(appIdentityProvider).userId;
      if (!assignment.summary.isClient(userId)) {
        _fail('Solo el cliente asignado puede instalar este programa.');
        return false;
      }

      await _service.acceptAssignment(assignmentId);
      await ref.read(coachProgramInstallerProvider).install(
            assignment,
            activate: activate,
          );

      ref.invalidate(exerciseListProvider);
      ref.invalidate(routineListProvider);
      ref.invalidate(trainingProgramListProvider);

      final assignments = await _service.listAssignments();
      state = state.copyWith(
        assignments: assignments,
        selected: assignment,
        operation: CoachProgramAssignmentOperation.idle,
        message: activate
            ? 'Programa aceptado e instalado como activo.'
            : 'Programa aceptado e instalado.',
        isError: false,
      );
      return true;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return false;
    } catch (error) {
      _fail(
        'La asignación fue recibida, pero no se pudo instalar localmente: '
        '${error.toString()}',
      );
      return false;
    }
  }

  Future<CoachProgramRevisionInstallInspection?>
      inspectAcceptedRevisionInstall(String assignmentId) async {
    if (!_requirePermanentAccount() || state.busy) return null;

    state = state.copyWith(
      operation: CoachProgramAssignmentOperation.checkingRevisionInstall,
      clearMessage: true,
      isError: false,
    );

    try {
      final revisionService =
          ref.read(coachProgramRevisionAcceptanceServiceProvider);
      final revisionState = await revisionService.loadState(assignmentId);
      final revisionId = revisionState.acceptedRevisionId;
      final revisionNumber = revisionState.acceptedRevisionNumber;
      if (revisionId == null || revisionNumber == null) {
        _fail('No hay una revisión aceptada para instalar.');
        return null;
      }

      final revision = await revisionService.loadAcceptedRevision(
        assignmentId: assignmentId,
        revisionId: revisionId,
      );
      if (revision.revisionNumber != revisionNumber) {
        _fail('La revisión aceptada cambió; vuelve a intentarlo.');
        return null;
      }

      final inspection = await ref
          .read(coachProgramInstallerProvider)
          .inspectAcceptedRevision(revision);
      state = state.copyWith(
        operation: CoachProgramAssignmentOperation.idle,
        isError: false,
      );
      return inspection;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
      _fail('No se pudo comprobar el estado local de la revisión.');
      return null;
    }
  }

  Future<bool> installAcceptedRevision(
    String assignmentId, {
    bool activate = true,
    bool allowOverwriteCustomized = false,
    String? expectedLocalStateToken,
  }) async {
    if (!_requirePermanentAccount() || state.busy) return false;

    state = state.copyWith(
      operation: CoachProgramAssignmentOperation.installingRevision,
      clearMessage: true,
      isError: false,
    );

    try {
      final revisionService =
          ref.read(coachProgramRevisionAcceptanceServiceProvider);
      final revisionState = await revisionService.loadState(assignmentId);
      final revisionId = revisionState.acceptedRevisionId;
      final revisionNumber = revisionState.acceptedRevisionNumber;
      if (revisionId == null || revisionNumber == null) {
        _fail('No hay una revisión aceptada para instalar.');
        return false;
      }

      final revision = await revisionService.loadAcceptedRevision(
        assignmentId: assignmentId,
        revisionId: revisionId,
      );
      if (revision.revisionNumber != revisionNumber) {
        _fail('La revisión aceptada cambió; vuelve a intentarlo.');
        return false;
      }

      final inspection = await ref
          .read(coachProgramInstallerProvider)
          .inspectAcceptedRevision(revision);
      if (expectedLocalStateToken != null &&
          inspection.localStateToken != expectedLocalStateToken) {
        _fail(
          'El programa local cambió desde la comprobación. '
          'Revísalo de nuevo antes de reemplazarlo.',
        );
        return false;
      }

      await ref.read(coachProgramInstallerProvider).installAcceptedRevision(
            revision,
            activate: activate,
            allowOverwriteCustomized: allowOverwriteCustomized,
            expectedLocalStateToken: expectedLocalStateToken,
          );

      ref.invalidate(exerciseListProvider);
      ref.invalidate(routineListProvider);
      ref.invalidate(trainingProgramListProvider);
      ref.invalidate(coachProgramRevisionStateProvider(assignmentId));

      state = state.copyWith(
        operation: CoachProgramAssignmentOperation.idle,
        message: inspection.upgradesExistingProgram
            ? (activate
                ? 'Revisión $revisionNumber aplicada al programa e instalada como activa.'
                : 'Revisión $revisionNumber aplicada al programa.')
            : (activate
                ? 'Revisión $revisionNumber instalada como programa activo.'
                : 'Revisión $revisionNumber instalada.'),
        isError: false,
      );
      return true;
    } on CoachProgramLocalChangesException {
      _fail(
        'Hay cambios locales sin confirmar. '
        'Revísalos antes de reemplazar el programa.',
      );
      return false;
    } on CoachProgramInstallStateChangedException {
      _fail(
        'El programa local cambió desde la comprobación. '
        'Revísalo de nuevo antes de reemplazarlo.',
      );
      return false;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return false;
    } catch (error) {
      _fail(
        'La revisión sigue aceptada, pero no se pudo instalar localmente: '
        '${error.toString()}',
      );
      return false;
    }
  }

  Future<bool> archiveAssignment(String assignmentId) async {
    if (!_requirePermanentAccount() || state.busy) return false;
    state = state.copyWith(
      operation: CoachProgramAssignmentOperation.archiving,
      clearMessage: true,
      isError: false,
    );
    try {
      await _service.archiveAssignment(assignmentId);
      final assignments = await _service.listAssignments();
      state = state.copyWith(
        assignments: assignments,
        operation: CoachProgramAssignmentOperation.idle,
        clearSelected: state.selected?.summary.id == assignmentId,
        message: 'Programa asignado archivado.',
        isError: false,
      );
      return true;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      _fail('No se pudo archivar el programa.');
      return false;
    }
  }

  bool _requirePermanentAccount() {
    if (ref.read(appIdentityProvider).signedIn) return true;
    _fail('Se necesita una cuenta permanente.');
    return false;
  }

  void _fail(String message) {
    state = state.copyWith(
      operation: CoachProgramAssignmentOperation.idle,
      message: message,
      isError: true,
    );
  }

  String _databaseMessage(PostgrestException error) {
    final raw = error.message.toLowerCase();
    if (raw.contains('assignment permission required')) {
      return 'El cliente no concedió permiso para asignar programas.';
    }
    if (raw.contains('active coach/client relationship required')) {
      return 'La relación con el cliente ya no está activa.';
    }
    if (raw.contains('assigned program not found')) {
      return 'Ese programa asignado ya no está disponible.';
    }
    return 'La función de programas asignados aún no está disponible en el backend activo.';
  }
}
