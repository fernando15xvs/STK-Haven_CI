import 'dart:async';

import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/onboarding/application/stk_age_eligibility.dart';
import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/sync/presentation/backup_status_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/onboarding/data/stk_mobile_legal_receipt_store.dart';
import 'package:gym_tracker/features/onboarding/data/stk_mobile_optional_consent_store.dart';
import 'package:gym_tracker/features/onboarding/presentation/stk_mobile_legal_config.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/stk_legal_acceptance_panel.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/stk_legal_document_page.dart';

/// Mobile-only privacy controls. Local receipts are not server grants and
/// do not prove a signed-in user's identity to any external API.
class StkMobilePrivacyPage extends ConsumerStatefulWidget {
  const StkMobilePrivacyPage({super.key});

  @override
  ConsumerState<StkMobilePrivacyPage> createState() =>
      _StkMobilePrivacyPageState();
}

class _StkMobilePrivacyPageState extends ConsumerState<StkMobilePrivacyPage> {
  Future<String>? _guestFuture;
  StreamSubscription<AuthState>? _authSubscription;
  bool _saving = false;

  StkLegalDocumentSet get _documents => StkMobileLegalConfig.documents;
  StkMobileLegalReceiptStore get _receipts =>
      StkMobileLegalReceiptStore(Hive.box<dynamic>(HiveBoxes.metadata));
  StkMobileOptionalConsentStore get _consents =>
      StkMobileOptionalConsentStore(Hive.box<dynamic>(HiveBoxes.metadata));

  @override
  void initState() {
    super.initState();
    _guestFuture = _receipts.getOrCreateGuestId();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  StkLegalAcceptanceReceipt? _receiptFor(
    StkLegalSubjectType type,
    String id,
    String? uid,
  ) => type == StkLegalSubjectType.authenticated
      ? _receipts.readAuthenticated(
          documents: _documents, activeUserId: uid,
        )
      : _receipts.readGuest(documents: _documents, guestId: id);

  Future<void> _openReview(
    StkLegalSubjectType type,
    String id,
    String? uid,
  ) async {
    if (_saving || !_documents.canCollectAcceptance) return;
    final profile = ref.read(userExperienceProfileProvider).value;
    final storedDate = profile?.eligibilityBirthDate ?? profile?.dateOfBirth;
    // An existing user must be able to correct their declared birth date.
    // Never overwrite the existing profile before explicit acceptance.
    final today = DateTime.now();
    final dob = await showDatePicker(
      context: context,
      helpText: 'Confirma tu fecha de nacimiento real',
      initialDate: storedDate ?? DateTime(
        today.year - 18, today.month, today.day,
      ),
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (!mounted || dob == null) return;
    final birthDate = dob;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (reviewContext) => Scaffold(
        appBar: AppBar(title: const Text('Revisar condiciones')),
        body: StkLegalAcceptancePanel(
          birthDate: birthDate,
          documents: _documents,
          subjectType: type,
          subjectId: id,
          locale: 'es-PE',
          acceptanceSource: 'legal_settings',
          onViewTerms: () => _viewDocument(
            'Términos y Condiciones', _documents.termsUrl,
          ),
          onViewPrivacy: () => _viewDocument(
            'Política de Privacidad', _documents.privacyUrl,
          ),
          onAccepted: (receipt) => unawaited(_saveReview(
            reviewContext, receipt, birthDate, uid,
          )),
          onDecline: () => Navigator.of(reviewContext).pop(),
        ),
      ),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _saveReview(
    BuildContext reviewContext,
    StkLegalAcceptanceReceipt receipt,
    DateTime birthDate,
    String? openingUid,
  ) async {
    if (_saving) return;
    if (!StkAgeEligibility.canBeginNewAccount(
      birthDate: birthDate, today: DateTime.now(),
    )) {
      _showError('La edad declarada no cumple el mínimo de 15 años.');
      return;
    }
    setState(() => _saving = true);
    try {
      // Recheck the live auth state after the user has read the documents.
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != openingUid) {
        throw StateError('La cuenta cambió. Revisa las condiciones otra vez.');
      }
      if (receipt.subjectType == StkLegalSubjectType.authenticated) {
        await _receipts.saveAuthenticated(
          receipt, activeUserId: uid,
        );
      } else {
        if (uid != null || receipt.subjectId !=
            await _receipts.getOrCreateGuestId()) {
          throw StateError('El perfil cambió durante la aceptación.');
        }
        await _receipts.saveGuest(receipt);
      }
      if (uid != Supabase.instance.client.auth.currentUser?.id) {
        throw StateError('La sesión cambió.');
      }
      final current = ref.read(userExperienceProfileProvider).value;
      if (current != null) {
        await ref.read(userExperienceProfileProvider.notifier).updateProfile(
          current.copyWith(eligibilityBirthDate: birthDate),
        );
      }
      if (reviewContext.mounted) Navigator.of(reviewContext).pop();
    } catch (_) {
      _showError('No se pudo guardar la aceptación. Inténtalo otra vez.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _viewDocument(String title, String url) {
    if (!_documents.canCollectAcceptance) return;
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => StkLegalDocumentPage(
        title: title, httpsUrl: url,
      ),
    ));
  }

  Future<void> _toggle(
    StkOptionalConsentPurpose purpose,
    bool granted,
    StkLegalSubjectType type,
    String id,
    String? uid,
    StkLegalAcceptanceReceipt? receipt,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (Supabase.instance.client.auth.currentUser?.id != uid) {
        throw StateError('La cuenta activa cambió.');
      }
      await _consents.setGranted(
        purpose: purpose,
        documents: _documents,
        subjectType: type,
        subjectId: id,
        activeUserId: Supabase.instance.client.auth.currentUser?.id,
        granted: granted,
        legalReceipt: receipt,
        now: DateTime.now(),
      );
      if (mounted) setState(() {});
    } catch (_) {
      _showError('No se pudo modificar el permiso para esta cuenta.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revokeAll(
    StkLegalSubjectType type,
    String id,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _consents.revokeAll(
        documents: _documents,
        subjectType: type,
        subjectId: id,
        activeUserId: Supabase.instance.client.auth.currentUser?.id,
        now: DateTime.now(),
      );
    } catch (_) {
      _showError('No se pudo retirar los permisos.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _content(
    StkLegalSubjectType type,
    String id,
    String? uid,
  ) {
    final colors = AppColors.of(context);
    final approved = _documents.canCollectAcceptance;
    final receipt = _receiptFor(type, id, uid);
    final accepted = receipt != null;

    Widget consentRow(
      StkOptionalConsentPurpose purpose,
      String label,
      String explanation,
    ) {
      final checked = _consents.isGranted(
        purpose: purpose,
        documents: _documents,
        subjectType: type,
        subjectId: id,
        activeUserId: uid,
      );
      return SwitchListTile.adaptive(
        key: ValueKey('stk_optional_${purpose.name}'),
        title: Text(label, style: AppTypography.bodyMedium),
        subtitle: Text(explanation,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary)),
        value: checked,
        // Revocation remains possible if a document has expired.
        onChanged: _saving || (!accepted && !checked)
            ? null
            : (value) => unawaited(_toggle(
                purpose, value, type, id, uid, receipt,
              )),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Tus datos y tu privacidad', style: AppTypography.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Aquí puedes consultar las condiciones y gestionar permisos '
          'opcionales. La edad declarada no es una verificación de identidad.',
          style: AppTypography.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!approved) ...[
          const ListTile(
            key: ValueKey('stk_legal_drafts_unavailable'),
            leading: Icon(Icons.info_outline),
            title: Text('Documentos legales pendientes de publicación'),
            subtitle: Text(
              'La aceptación del nuevo modelo 15+ no está activada. '
              'El acceso actual a tu historial no cambia.',
            ),
          ),
        ] else ...[
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Términos y Condiciones'),
            subtitle: Text('Versión ${_documents.termsVersion}'),
            onTap: () => _viewDocument(
              'Términos y Condiciones', _documents.termsUrl,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Política de Privacidad'),
            subtitle: Text('Versión ${_documents.privacyVersion}'),
            onTap: () => _viewDocument(
              'Política de Privacidad', _documents.privacyUrl,
            ),
          ),
          ListTile(
            key: const ValueKey('stk_legal_acceptance_status'),
            leading: Icon(accepted
                ? Icons.verified_outlined : Icons.info_outline),
            title: Text(accepted
                ? 'Condiciones aceptadas'
                : 'Condiciones pendientes de aceptación'),
            subtitle: Text(accepted
                ? 'Registro local de ${receipt.acceptedAtUtc.toLocal()}'
                : 'Puedes revisarlas sin repetir tu entrenamiento.'),
          ),
          OutlinedButton(
            key: const ValueKey('stk_legal_review_button'),
            onPressed: _saving ? null : () =>
                unawaited(_openReview(type, id, uid)),
            child: Text(accepted
                ? 'Revisar nuevamente' : 'Revisar y aceptar'),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Permisos opcionales', style: AppTypography.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        if (!approved)
          Text('Los permisos de la nueva política se habilitarán después '
            'de la publicación y revisión legal.',
            style: AppTypography.bodySmall),
        consentRow(
          StkOptionalConsentPurpose.foodVisionAi,
          'Análisis de fotografías con IA',
          'Autoriza el envío voluntario de fotos para reconocer alimentos. '
          'Se puede retirar antes de nuevos análisis.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'No solicitamos aquí permisos para funciones todavía '
          'no publicadas. Otros tratamientos opcionales tendrán '
          'su propia explicación y aceptación si se incorporan.',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          key: const ValueKey('stk_revoke_optional_consents'),
          onPressed: _saving ? null : () =>
              unawaited(_revokeAll(type, id)),
          icon: const Icon(Icons.shield_outlined),
          label: const Text('Retirar todos los permisos opcionales'),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Datos y copias', style: AppTypography.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          title: const Text('Exportación y sincronización'),
          subtitle: const Text('Gestiona copias, acceso y datos locales.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const BackupStatusPage()),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Una aceptación registrada en este dispositivo no demuestra '
          'mayoría de edad verificada ni sustituye el consentimiento '
          'requerido por el servidor para operaciones restringidas.',
          style: AppTypography.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(title: const Text('Legal y privacidad')),
      body: SafeArea(
        child: uid != null
            ? _content(StkLegalSubjectType.authenticated, uid, uid)
            : FutureBuilder<String>(
                future: _guestFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('No se pudieron cargar los permisos.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _content(
                    StkLegalSubjectType.guest,
                    snapshot.data!,
                    null,
                  );
                },
              ),
      ),
    );
  }
}
