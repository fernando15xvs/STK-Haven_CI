import 'dart:async';

import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/presentation/pages/nutrition_intelligence_page.dart';
import 'package:core/features/nutrition/data/nutrition_adult_access_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gym_tracker/features/progress/presentation/pages/body_measurement_page.dart';
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
  late Future<bool> _adultAccess;
  StreamSubscription<AuthState>? _authSubscription;

  Future<bool> _checkAccess() => NutritionAdultAccessService(
    Supabase.instance.client,
  ).hasVerifiedAccess();

  void _refreshAdultAccess() {
    if(!mounted)return;
    setState(() => _adultAccess = _checkAccess());
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
        if(mounted)setState(() => _adultAccess=Future<bool>.value(false));
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
    return FutureBuilder<bool>(
      future: _adultAccess,
      builder: (context, snapshot) => NutritionIntelligencePage(
        // A different account must never inherit the previous account's
        // private nutrition plan or Food Vision results from this widget.
        key: ValueKey('nutrition_account_${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}'),
        photoPicker: _pickPhoto,
        cameraAvailable: true,
        // FutureBuilder can retain the prior result while a new RPC is
        // waiting; only a completed fresh check can unlock numeric nutrition.
        verifiedAdultNutritionAccess:
            snapshot.connectionState == ConnectionState.done &&
            snapshot.data == true,
        onRefreshAdultAccess: _refreshAdultAccess,
        onOpenMeasurements: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BodyMeasurementPage()),
        ),
      ),
    );
  }

  Future<NutritionPhoto?> _pickPhoto(NutritionPhotoSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source == NutritionPhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final mimeType = _mimeType(file.name);
    return NutritionPhoto(
      bytes: bytes,
      mimeType: mimeType,
      name: file.name,
    );
  }

  String _mimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
