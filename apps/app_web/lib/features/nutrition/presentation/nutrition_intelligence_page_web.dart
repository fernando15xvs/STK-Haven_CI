import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/presentation/pages/nutrition_intelligence_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NutritionIntelligencePageWeb extends StatelessWidget {
  const NutritionIntelligencePageWeb({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final adultAccess =
        user?.appMetadata['adult_nutrition_access'] == true;
    return NutritionIntelligencePage(
      photoPicker: _pickPhoto,
      cameraAvailable: false,
      verifiedAdultNutritionAccess: adultAccess,
    );
  }

  Future<NutritionPhoto?> _pickPhoto(NutritionPhotoSource source) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return null;

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
