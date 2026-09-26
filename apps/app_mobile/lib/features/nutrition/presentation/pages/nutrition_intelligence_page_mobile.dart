import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/presentation/pages/nutrition_intelligence_page.dart';
import 'package:core/features/nutrition/data/nutrition_adult_access_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NutritionIntelligencePageMobile extends StatefulWidget {
  const NutritionIntelligencePageMobile({super.key});

  @override
  State<NutritionIntelligencePageMobile> createState() =>
      _NutritionIntelligencePageMobileState();
}

class _NutritionIntelligencePageMobileState
    extends State<NutritionIntelligencePageMobile> {
  late final Future<bool> _adultAccess;

  @override
  void initState() {
    super.initState();
    _adultAccess = NutritionAdultAccessService(
      Supabase.instance.client,
    ).hasVerifiedAccess();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _adultAccess,
      builder: (context, snapshot) => NutritionIntelligencePage(
        photoPicker: _pickPhoto,
        cameraAvailable: true,
        verifiedAdultNutritionAccess: snapshot.data == true,
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
