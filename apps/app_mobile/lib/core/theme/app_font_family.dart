import 'package:core/domain/models/appearance_settings.dart';

/// The family name exactly matches the locally bundled variable TTF in Mobile.
String appFontFamilyName(AppFontFamily font) => switch (font) {
  AppFontFamily.outfit => 'Outfit',
  AppFontFamily.inter => 'Inter',
  AppFontFamily.manrope => 'Manrope',
  AppFontFamily.plusJakartaSans => 'Plus Jakarta Sans',
};
