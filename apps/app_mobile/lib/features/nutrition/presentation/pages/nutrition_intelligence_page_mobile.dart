import 'dart:async';

import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';
import 'package:core/features/nutrition/application/food_vision_mobile_image_guard.dart';
import 'package:core/features/nutrition/data/stk_nutrition_intent_repository.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:core/features/nutrition/presentation/pages/nutrition_intelligence_page.dart';
import 'package:core/features/nutrition/data/nutrition_adult_access_service.dart';
import 'package:core/features/nutrition/data/stk_nutrition_server_capabilities.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:gym_tracker/features/progress/presentation/pages/body_measurement_page.dart';
import 'package:gym_tracker/features/onboarding/data/stk_mobile_legal_receipt_store.dart';
import 'package:gym_tracker/features/onboarding/data/stk_mobile_optional_consent_store.dart';
import 'package:gym_tracker/features/onboarding/presentation/stk_mobile_legal_config.dart';
import 'package:gym_tracker/features/profile/presentation/pages/stk_mobile_privacy_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NutritionIntelligencePageMobile extends StatefulWidget {
  const NutritionIntelligencePageMobile({super.key});

  @override
  State<NutritionIntelligencePageMobile> createState() =>
      _NutritionIntelligencePageMobileState();
}

class _NutritionIntelligencePageMobileState
    extends State<NutritionIntelligencePageMobile>
    with WidgetsBindingObserver {
  late Future<NutritionAdultCheck> _adultAccess;
  // Owner of the RPC result. A previous account cannot donate a successful
  // check even for one frame before the auth stream emits its next event.
  String? _accessOwnerId;
  // In-memory only: a relogin under the same UID is a new authorization scope.
  String? _accessOwnerToken;
  StreamSubscription<AuthState>? _authSubscription;
  Future<void> _intentWriteTail = Future<void>.value();

  /// Serialize rapid taps. A late write is always scoped to the original UID.
  Future<void> _saveNutritionIntent(
      StkNutritionIntent intent, String? ownerId, String? ownerToken) {
    final operation = _intentWriteTail.then((_) async {
      if (!mounted ||
          Supabase.instance.client.auth.currentUser?.id != ownerId ||
          Supabase.instance.client.auth.currentSession?.accessToken != ownerToken) {
        throw StateError('La sesión cambió durante la selección.');
      }
      await StkNutritionIntentRepository(
        Hive.box<dynamic>(HiveBoxes.metadata), ownerId: ownerId,
      ).save(intent);
      if (!mounted ||
          Supabase.instance.client.auth.currentUser?.id != ownerId ||
          Supabase.instance.client.auth.currentSession?.accessToken != ownerToken) {
        throw StateError('La sesión cambió durante la selección.');
      }
    });
    // Keep the queue usable after a failed storage write; return the original
    // operation so the chooser can display an error rather than fake success.
    _intentWriteTail = operation.then((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<NutritionAdultCheck> _checkAccess() {
    final client = Supabase.instance.client;
    _accessOwnerId = client.auth.currentUser?.id;
    _accessOwnerToken = client.auth.currentSession?.accessToken;
    return NutritionAdultAccessService(client).checkStatus();
  }

  void _refreshAdultAccess() {
    if(!mounted)return;
    setState(() => _adultAccess = _checkAccess());
  }

  /// A legacy account keeps its entire Hive/on-device history. The legal
  /// screen requests a new server receipt only after approved publication;
  /// opening the screen never grants adult nutrition by itself.
  Future<void> _openExistingUserLegalReview() async {
    if (!mounted || !StkMobileLegalConfig.enabled ||
        !StkMobileLegalConfig.documents.canCollectAcceptance) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const StkMobilePrivacyPage(),
      ),
    );
    if (mounted) _refreshAdultAccess();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _adultAccess = _checkAccess();
    // Switching accounts or refreshing an expired token must not keep an
    // old user's nutrition grant on screen.
    _authSubscription=Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _refreshAdultAccess(),
      onError:(Object error,StackTrace stackTrace){
        if (mounted) {
          setState(() => _adultAccess =
              Future<NutritionAdultCheck>.value(NutritionAdultCheck.unavailable));
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed)_refreshAdultAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NutritionAdultCheck>(
      future: _adultAccess,
      builder: (context, snapshot) {
        // FutureBuilder may retain an old successful result while a new
        // account/session RPC is pending. Never reuse that grant.
        final currentUid = Supabase.instance.client.auth.currentUser?.id;
        final currentToken = Supabase.instance.client.auth.currentSession?.accessToken;
        final status = currentUid != _accessOwnerId ||
                currentToken != _accessOwnerToken
            ? (currentUid == null
                ? NutritionAdultCheck.signedOut
                : NutritionAdultCheck.checking)
            : snapshot.connectionState == ConnectionState.done
                ? (snapshot.data ?? NutritionAdultCheck.unavailable)
                : NutritionAdultCheck.checking;
        return NutritionIntelligencePage(
        // A different account must never inherit the previous account's
        // private nutrition plan or Food Vision results from this widget.
        key: ValueKey('nutrition_account_${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}'),
        photoPicker: _pickPhoto,
        showAgeAwareGoals: true,
        mobileCompactLayout: true,
        initialStkNutritionIntent: StkNutritionIntentRepository(
          Hive.box<dynamic>(HiveBoxes.metadata), ownerId: currentUid,
        ).read(),
        onSaveStkNutritionIntent: (intent) =>
            _saveNutritionIntent(intent, currentUid, currentToken),
        // The 15+ release gate includes a fresh check BEFORE every image
        // request, including reanalysis after revoking a previous consent.
        // Even legacy users must opt in per photo before anything leaves
        // their phone. Permanent preference storage is only available with
        // approved/published policies; no consent is silently assumed.
        requestPhotoAnalysisConsent: _requestPhotoConsent,
        cameraAvailable: true,
        // FutureBuilder can retain the prior result while a new RPC is
        // waiting; only a completed fresh check can unlock numeric nutrition.
        verifiedAdultNutritionAccess: status.allowsNumeric,
        mobileAdultCheck: status,
        onRefreshAdultAccess: _refreshAdultAccess,
        legalReviewAvailable: StkMobileLegalConfig.enabled &&
            StkMobileLegalConfig.documents.canCollectAcceptance,
        onOpenLegalAndPrivacy: () => unawaited(_openExistingUserLegalReview()),
        onOpenMeasurements: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BodyMeasurementPage()),
        ),
      );
      },
    );
  }

  Future<bool> _requestPhotoConsent() async {
    if (!mounted) return false;
    final docs = StkMobileLegalConfig.documents;
    if (!StkMobileLegalConfig.enabled) {
      return _requestOneTimePhotoConsent();
    }
    if (!docs.canCollectAcceptance) return false;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final tokenAtStart = Supabase.instance.client.auth.currentSession?.accessToken;
    bool samePhotoConsentSession() =>
        uid == Supabase.instance.client.auth.currentUser?.id &&
        tokenAtStart == Supabase.instance.client.auth.currentSession?.accessToken;
    final store = StkMobileLegalReceiptStore(
      Hive.box<dynamic>(HiveBoxes.metadata),
    );
    final consentStore = StkMobileOptionalConsentStore(
      Hive.box<dynamic>(HiveBoxes.metadata),
    );
    final type = uid == null
        ? StkLegalSubjectType.guest
        : StkLegalSubjectType.authenticated;
    final id = uid ?? await store.getOrCreateGuestId();
    if (!mounted || !samePhotoConsentSession()) {
      return false;
    }
    final receipt = uid == null
        ? store.readGuest(documents: docs, guestId: id)
        : store.readAuthenticated(documents: docs, activeUserId: uid);
    if (receipt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Revisa los Términos y la Privacidad en Perfil antes de enviar fotos.',
        ),
      ));
      return false;
    }
    // A restored Hive receipt is not remotely authoritative. A withdrawal
    // from another phone must block every new photo, even when a prior local
    // optional-consent toggle was still true on this device.
    if (uid != null) {
      try {
        final response = await Supabase.instance.client
            .rpc('stk_get_nutrition_capabilities')
            .timeout(const Duration(seconds: 12));
        if (!mounted || !samePhotoConsentSession()) return false;
        final capabilities = StkNutritionServerCapabilities.parse(response);
        if (capabilities?.legalCurrent != true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
              'Tu aceptación legal ya no está vigente. Revísala en Perfil.',
            ),
          ));
          return false;
        }
      } catch (_) {
        // Missing migration, offline, timeout or revoked session fail closed.
        return false;
      }
    }
    if (consentStore.isGranted(
      purpose: StkOptionalConsentPurpose.foodVisionAi,
      documents: docs,
      subjectType: type,
      subjectId: id,
      activeUserId: uid,
    )) return true;

    final allowed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Analizar fotografía con IA'),
        content: const Text(
          'Para reconocer alimentos, enviaremos la fotografía que elijas '
          'a nuestro proveedor de IA. La estimación puede contener errores. '
          'Puedes retirar este permiso en Perfil > Legal y privacidad. '
          'Evita incluir rostros, documentos o información privada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No enviar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Permitir análisis'),
          ),
        ],
      ),
    );
    if (allowed != true || !mounted || !samePhotoConsentSession()) {
      return false;
    }
    try {
      await consentStore.setGranted(
        purpose: StkOptionalConsentPurpose.foodVisionAi,
        documents: docs,
        subjectType: type,
        subjectId: id,
        activeUserId: uid,
        granted: true,
        legalReceipt: receipt,
        now: DateTime.now(),
      );
      if (!samePhotoConsentSession()) return false;
      return consentStore.isGranted(
        purpose: StkOptionalConsentPurpose.foodVisionAi,
        documents: docs,
        subjectType: type,
        subjectId: id,
        activeUserId: Supabase.instance.client.auth.currentUser?.id,
      );
    } catch (_) {
      return false;
    }
  }

  /// Legacy users may continue educational Food Vision scans without
  /// accepting legal DRAFTS. Every upload needs a fresh, explicit opt-in.
  /// This per-request choice never creates a durable permission or
  /// authorizes adult numeric nutrition.
  Future<bool> _requestOneTimePhotoConsent() async {
    if (!mounted) return false;
    final openingUser = Supabase.instance.client.auth.currentUser?.id;
    final openingToken = Supabase.instance.client.auth.currentSession?.accessToken;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enviar fotografía para análisis con IA'),
        content: const Text(
          'STK Haven enviará esta fotografía al servicio de IA para '
          'identificar alimentos y ofrecer una estimación aproximada. '
          'Evita fotografiar rostros, documentos o datos privados. '
          'Este permiso vale sólo para esta fotografía y puedes '
          'elegir no enviarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No enviar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enviar esta foto'),
          ),
        ],
      ),
    );
    return approved == true &&
        mounted &&
        openingUser == Supabase.instance.client.auth.currentUser?.id &&
        openingToken == Supabase.instance.client.auth.currentSession?.accessToken;
  }

  Future<NutritionPhoto?> _pickPhoto(NutritionPhotoSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source == NutritionPhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // Smaller uploads reduce mobile data use and remote image-token costs.
      imageQuality: 78,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    // Do not advertise a HEIC or renamed file as JPEG by extension.
    // The core preflight rejects unknown magic bytes before preview/upload.
    final mimeType = FoodVisionMobileImageGuard.detectMimeType(bytes) ??
        'application/octet-stream';
    return NutritionPhoto(
      bytes: bytes,
      mimeType: mimeType,
      name: file.name,
    );
  }
}
