import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Installation-scoped, non-authoritative legal receipt registry.
/// This does not establish account ownership on the backend, nor adulthood.
/// Restoring Hive data cannot grant nutrition privileges.
class StkMobileLegalReceiptStore {
  StkMobileLegalReceiptStore(this._box);

  static const String _guestIdKey = 'stk_legal_guest_subject_v1';
  static const String _receiptKey = 'stk_legal_guest_receipt_v1';
  static const String _accountPrefix = 'stk_legal_account_receipt_v1:';
  final Box<dynamic> _box;

  Future<String> getOrCreateGuestId() async {
    final existing = _box.get(_guestIdKey);
    if (existing is String && existing.trim().isNotEmpty) return existing;
    final id = const Uuid().v4();
    await _box.put(_guestIdKey, id);
    return id;
  }

  /// A guest receipt can NEVER be promoted to a signed-in UID.
  Future<void> saveGuest(StkLegalAcceptanceReceipt receipt) async {
    final id = await getOrCreateGuestId();
    if (receipt.subjectType != StkLegalSubjectType.guest ||
        receipt.subjectId != id) {
      throw StateError('La aceptación corresponde a otra identidad.');
    }
    await _box.put(_receiptKey, receipt.toJson());
  }

  StkLegalAcceptanceReceipt? readGuest({
    required StkLegalDocumentSet documents,
    required String guestId,
  }) => _read(
    _receiptKey,
    documents: documents,
    subjectType: StkLegalSubjectType.guest,
    subjectId: guestId,
  );

  /// Account receipts MUST be explicitly accepted by the current UID;
  /// never derive currentUserId from editable JWT user_metadata or profiles.
  Future<void> saveAuthenticated(
    StkLegalAcceptanceReceipt receipt, {
    required String? activeUserId,
  }) async {
    if (activeUserId == null || activeUserId.trim().isEmpty ||
        receipt.subjectType != StkLegalSubjectType.authenticated ||
        receipt.subjectId != activeUserId) {
      throw StateError('La aceptación no corresponde a la cuenta activa.');
    }
    await _box.put(_accountKey(activeUserId), receipt.toJson());
  }

  StkLegalAcceptanceReceipt? readAuthenticated({
    required StkLegalDocumentSet documents,
    required String? activeUserId,
  }) {
    if (activeUserId == null || activeUserId.trim().isEmpty) return null;
    return _read(
      _accountKey(activeUserId),
      documents: documents,
      subjectType: StkLegalSubjectType.authenticated,
      subjectId: activeUserId,
    );
  }

  /// Local deletion for privacy requests. Deleting locally does not revoke
  /// legal proof held elsewhere and does not delete a remote account.
  Future<void> clearLocalReceipt({
    required StkLegalSubjectType subjectType,
    required String subjectId,
    required String? activeUserId,
  }) async {
    if (subjectType == StkLegalSubjectType.authenticated) {
      if (activeUserId == null || activeUserId != subjectId) {
        throw StateError('No puedes modificar los datos de otra cuenta.');
      }
      await _box.delete(_accountKey(subjectId));
      return;
    }
    final guestId = await getOrCreateGuestId();
    if (guestId != subjectId || activeUserId != null) {
      throw StateError('No se permite borrar datos de otra identidad.');
    }
    await _box.delete(_receiptKey);
  }

  StkLegalAcceptanceReceipt? _read(
    String key, {
    required StkLegalDocumentSet documents,
    required StkLegalSubjectType subjectType,
    required String subjectId,
  }) {
    final raw = _box.get(key);
    if (raw is! Map) return null;
    try {
      final restored = StkLegalAcceptanceReceipt.fromJson(
        Map<String, dynamic>.from(raw),
      );
      return restored?.isCurrentFor(
        documents: documents,
        subjectType: subjectType,
        subjectId: subjectId,
      ) == true ? restored : null;
    } catch (_) {
      // Damaged or foreign backup data never establishes acceptance.
      return null;
    }
  }

  String _accountKey(String id) => '$_accountPrefix${Uri.encodeComponent(id)}';
}
