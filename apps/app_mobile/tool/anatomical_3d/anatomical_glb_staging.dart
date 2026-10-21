import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// OFFLINE staging decoder for verified, animated glTF 2.0 experiments.
/// This validates bytes and theme material slots. It does NOT rasterize a GLB;
/// a reviewed native/skinned runtime is still required before app integration.
@immutable
class AnatomicalGlbStaging {
  const AnatomicalGlbStaging._({
    required this.id,
    required this.byteLength,
    required this.jointCount,
    required this.animationCount,
    required this.meshCount,
    required this.materialRoles,
  });

  static const stableIds = {
    'ex_bench_press',
    'ex_barbell_row',
    'ex_squat',
  };
  /// Exact region IDs emitted by the CC0 master surface; not inferred anatomy.
  static const masterRegionNames = <String>{
    'pectoralis_major', 'anterior_deltoid', 'posterior_deltoid',
    'triceps_brachii', 'latissimus_dorsi', 'rhomboids',
    'middle_trapezius', 'quadriceps_femoris', 'gluteus_maximus',
    'hamstrings', 'adductor_magnus',
  };

  static const maxByteLength = 850 * 1024;

  final String id;
  final int byteLength, jointCount, animationCount, meshCount;
  final Set<String> materialRoles;

  static AnatomicalGlbStaging parse(Uint8List bytes) {
    if (bytes.length < 28 || bytes.length > maxByteLength) {
      throw const FormatException('3D asset size outside offline budget');
    }
    final header = ByteData.sublistView(bytes);
    if (header.getUint32(0, Endian.little) != 0x46546C67 ||
        header.getUint32(4, Endian.little) != 2 ||
        header.getUint32(8, Endian.little) != bytes.length) {
      throw const FormatException('Invalid glTF 2.0 GLB header');
    }
    final jsonLength = header.getUint32(12, Endian.little);
    if (jsonLength < 2 || jsonLength > bytes.length - 28 ||
        header.getUint32(16, Endian.little) != 0x4E4F534A) {
      throw const FormatException('Missing GLB JSON chunk');
    }
    final binHead = 20 + jsonLength;
    if (binHead + 8 > bytes.length ||
        header.getUint32(binHead + 4, Endian.little) != 0x004E4942 ||
        binHead + 8 + header.getUint32(binHead, Endian.little) !=
            bytes.length) {
      throw const FormatException('Missing embedded GLB binary chunk');
    }
    final decoded = jsonDecode(utf8.decode(bytes.sublist(20, binHead)));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid GLB JSON object');
    }
    final extra = decoded['extras'];
    if (extra is! Map || extra['approved'] != false ||
        extra['enabled'] != false || extra['exerciseId'] is! String ||
        !stableIds.contains(extra['exerciseId'])) {
      throw const FormatException('Unsafe/unknown anatomical model ID');
    }
    final skins = decoded['skins'];
    final meshes = decoded['meshes'];
    final animations = decoded['animations'];
    final materials = decoded['materials'];
    final buffers = decoded['buffers'];
    if (skins is! List || skins.length != 1 ||
        skins.single is! Map || skins.single['joints'] is! List ||
        !{19, 53}.contains((skins.single['joints'] as List).length) ||
        meshes is! List || meshes.length < 2 ||
        animations is! List || animations.length != 1 ||
        animations.single is! Map ||
        animations.single['channels'] is! List ||
        (animations.single['channels'] as List).length < 10 ||
        materials is! List ||
        buffers is! List || buffers.length != 1 ||
        buffers.single is! Map || buffers.single.containsKey('uri')) {
      throw const FormatException('GLB rig or resources incomplete');
    }
    final roles = <String>{};
    for (final entry in materials) {
      if (entry is! Map || entry['name'] is! String ||
          !entry['name'].toString().startsWith('STK_') ||
          entry['extras'] is! Map ||
          entry['extras']['stkMuscleRole'] is! String) {
        throw const FormatException('Unexpected material namespace');
      }
      roles.add(entry['extras']['stkMuscleRole'] as String);
    }
    if (!roles.contains('primary') || !roles.contains('secondary')) {
      throw const FormatException('Missing active muscle material slots');
    }
    return AnatomicalGlbStaging._(
      id: extra['exerciseId'] as String,
      byteLength: bytes.length,
      jointCount: (skins.single['joints'] as List).length,
      animationCount: animations.length,
      meshCount: meshes.length,
      materialRoles: Set.unmodifiable(roles),
    );
  }

  /// Material binding contract for a future MOBILE runtime. This does not
  /// mutate GLB binary data or secretly enable draft assets.
  static Map<String, Color> themeMaterials(BuildContext context) {
    final palette = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return {
      'STK_PRIMARY': palette.primary,
      'STK_SECONDARY': Color.alphaBlend(
        Colors.white.withValues(alpha: dark ? .28 : .20), palette.primary),
      'STK_BODY': dark ? const Color(0xFFC5CBD3) : const Color(0xFF9099A4),
      'STK_MUSCLE': dark ? const Color(0xFFE5E9EE) : const Color(0xFFBBC3CD),
    };
  }

  /// Only the chosen muscles use the user's actual accent (8 light/dark
  /// theme combinations per mode). Does not mutate the CC0 mesh or the GLB.
  /// Unknown labels are ignored rather than becoming arbitrary material IDs.
  static Map<String, Color> themeMasterRegions(BuildContext context, {
    Set<String> highlightedRegions = const <String>{},
  }) {
    final palette = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final result = themeMaterials(context);
    final rest = dark ? const Color(0xFFB7C2CE) : const Color(0xFF86929E);
    final selectedBase = dark
        ? const Color(0xFFE5E9EE) : const Color(0xFFBBC3CD);
    for (final name in masterRegionNames) {
      result['STK_REGION_$name'] = highlightedRegions.contains(name)
          ? Color.alphaBlend(
              palette.primary.withValues(alpha: dark ? .74 : .67),
              selectedBase,
            )
          : rest;
    }
    return result;
  }
}
