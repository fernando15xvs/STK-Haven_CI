import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Installation-scoped audit receipt, never a verified identity or a
/// server-side authorization. Account-bound receipts belong to phase 3.
class StkMobileLegalReceiptStore {
  StkMobileLegalReceiptStore(this._box);

  static const String _guestIdKey = 'stk_legal_guest_subject_v1';
  static const String _receiptKey = 'stk_legal_guest_receipt_v1';
  final Box<dynamic> _box;

  Future<String> getOrCreateGuestId() async {
    final existing = _box.get(_guestIdKey);
    if (existing is String && existing.trim().isNotEmpty) {
      return existing;
    }
    final newId = const Uuid().v4();
    await _box.put(_guestIdKey, newId);
    return newId;
  }

  /// Saving acceptance is not proof that a signed-in user accepted anything.
  /// A new account must accept for its own UID before server-bound use.
  Future<void> saveGuest(StkLegalAcceptanceReceipt receipt) async {
    final id = await getOrCreateGuestId();
    if (receipt.subjectType != StkLegalSubjectType.guest ||
        receipt.subjectId != id) {
      throw StateError('No se puede asociar otra identidad al recibo.');
    }
    await _box.put(_receiptKey, receipt.toJson());
  }

  StkLegalAcceptanceReceipt? readGuest({
    required StkLegalDocumentSet documents,
    required String guestId,
  }) {
    final raw = _box.get(_receiptKey);
    if (raw is! Map) return null;
    final restored = StkLegalAcceptanceReceipt.fromJson(
      Map<String, dynamic>.from(raw),
    );
    if (restored == null ||
        !restored.isCurrentFor(
          documents: documents,
          subjectType: StkLegalSubjectType.guest,
          subjectId: guestId,
        )) {
      return null;
    }
    return restored;
  }
}
