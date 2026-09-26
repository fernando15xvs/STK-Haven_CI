import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/presentation/pages/nutrition_intelligence_page.dart';
import 'package:core/features/nutrition/data/nutrition_adult_access_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NutritionIntelligencePageWeb extends StatefulWidget {
  const NutritionIntelligencePageWeb({super.key});

  @override
  State<NutritionIntelligencePageWeb> createState() =>
      _NutritionIntelligencePageWebState();
}

class _NutritionIntelligencePageWebState
    extends State<NutritionIntelligencePageWeb> {
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
        cameraAvailable: false,
        verifiedAdultNutritionAccess: snapshot.data == true,
      ),
    );
  }

  Future<NutritionPhoto?> _pickPhoto(NutritionPhotoSource source) async {
    final file = await FilePicker.pickFile(
      type: FileType.image,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();

    return NutritionPhoto(
      bytes: bytes,
      mimeType: _mimeType(file.extension),
      name: file.name,
    );
  }

  String _mimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
