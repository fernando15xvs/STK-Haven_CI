import 'package:core/features/onboarding/application/stk_age_eligibility.dart';
import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Ready-to-integrate final onboarding step.
///
/// The current legal documents are drafts. A caller must supply an approved,
/// published document set and real document-open actions before displaying
/// this as a binding agreement. This widget never grants nutrition access.
class StkLegalAcceptancePanel extends StatefulWidget {
  const StkLegalAcceptancePanel({
    super.key,
    required this.birthDate,
    required this.documents,
    required this.subjectType,
    required this.subjectId,
    required this.locale,
    required this.onViewTerms,
    required this.onViewPrivacy,
    required this.onAccepted,
    required this.onDecline,
    this.today,
    this.acceptanceSource = 'onboarding',
  });

  final DateTime? birthDate;
  final DateTime? today;
  /// 'legal_settings' is used for existing accounts reviewing updated terms.
  final String acceptanceSource;
  final StkLegalDocumentSet documents;
  final StkLegalSubjectType subjectType;
  final String subjectId;
  final String locale;
  final VoidCallback onViewTerms;
  final VoidCallback onViewPrivacy;
  final ValueChanged<StkLegalAcceptanceReceipt> onAccepted;
  final VoidCallback onDecline;

  @override
  State<StkLegalAcceptancePanel> createState() =>
      _StkLegalAcceptancePanelState();
}

class _StkLegalAcceptancePanelState extends State<StkLegalAcceptancePanel> {
  bool _ageConfirmed = false;
  bool _termsAccepted = false;

  bool get _eligible => StkAgeEligibility.canBeginNewAccount(
    birthDate: widget.birthDate,
    today: widget.today ?? DateTime.now(),
  );

  bool get _canContinue =>
      widget.documents.canCollectAcceptance &&
      _eligible &&
      _ageConfirmed &&
      _termsAccepted;

  void _accept() {
    if (!_canContinue || widget.birthDate == null) return;
    final receipt = StkLegalAcceptanceReceipt.record(
      documents: widget.documents,
      birthDate: widget.birthDate!,
      now: widget.today ?? DateTime.now(),
      confirmedMinimumAge: _ageConfirmed,
      acceptedTerms: _termsAccepted,
      // Privacy policy is visibly presented in the same step.
      privacyNoticeShown: true,
      subjectType: widget.subjectType,
      subjectId: widget.subjectId,
      locale: widget.locale,
      source: widget.acceptanceSource,
    );
    if (receipt != null) widget.onAccepted(receipt);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Antes de comenzar', style: AppTypography.headlineLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Queremos que STK Haven sea una experiencia segura y '
            'transparente. Lee estas condiciones antes de continuar.',
            style: AppTypography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'STK Haven está disponible para personas de 15 años o más.',
            style: AppTypography.bodyMedium,
          ),
          if (!_eligible) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.birthDate == null
                  ? 'Indica tu fecha de nacimiento para continuar.'
                  : 'Esta versión de STK Haven requiere 15 años cumplidos.',
              key: const ValueKey('stk_legal_age_error'),
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            key: const ValueKey('stk_terms_link'),
            onPressed: widget.onViewTerms,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Leer Términos y Condiciones completos'),
          ),
          TextButton.icon(
            key: const ValueKey('stk_privacy_link'),
            onPressed: widget.onViewPrivacy,
            icon: const Icon(Icons.privacy_tip_outlined),
            label: const Text('Leer Política de Privacidad completa'),
          ),
          const SizedBox(height: AppSpacing.sm),
          CheckboxListTile(
            key: const ValueKey('stk_confirm_15_plus'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Confirmo que tengo al menos 15 años y que mi fecha '
              'de nacimiento es correcta.',
            ),
            value: _ageConfirmed,
            onChanged: _eligible
                ? (value) => setState(() => _ageConfirmed = value ?? false)
                : null,
          ),
          CheckboxListTile(
            key: const ValueKey('stk_accept_terms'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'He leído y acepto los Términos y Condiciones de STK Haven.',
            ),
            value: _termsAccepted,
            onChanged: widget.documents.canCollectAcceptance
                ? (value) => setState(() => _termsAccepted = value ?? false)
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Food Vision muestra estimaciones aproximadas y no sustituye '
            'asesoramiento nutricional profesional. La Política de '
            'Privacidad explica el tratamiento de tus datos.',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (!widget.documents.canCollectAcceptance) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Los documentos legales aún no están publicados. '
              'No puedes aceptar esta versión.',
              key: const ValueKey('stk_legal_unpublished'),
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            key: const ValueKey('stk_legal_continue'),
            onPressed: _canContinue ? _accept : null,
            child: const Text('Aceptar y continuar'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            key: const ValueKey('stk_legal_decline'),
            onPressed: widget.onDecline,
            child: const Text('No aceptar / Salir'),
          ),
        ],
      ),
    );
  }
}
