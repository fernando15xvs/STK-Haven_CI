import 'package:gym_tracker/core/layout/mobile_content_frame.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:core/domain/models/user_experience_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Private profile thumbnail: falls back to the selected emoji or a neutral icon.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius = 36, this.previewEnabled = false});

  final UserExperienceProfile? profile;
  final double radius;
  final bool previewEnabled;

  @override
  Widget build(BuildContext context) {
    Uint8List? photo;
    final encoded = profile?.avatarPhotoBase64;
    if (encoded != null && encoded.isNotEmpty) {
      try {
        photo = base64Decode(encoded);
      } on FormatException {
        // Older or corrupt local backup: keep the profile usable.
      }
    }
    final emoji = profile?.avatarEmoji;
    final bytes = photo;
    final avatar = SizedBox.square(
      dimension: radius * 2,
      child: ClipOval(child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: bytes != null
          ? Image.memory(bytes, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.person_outline, size: radius))
          : Center(child: emoji == null
              ? Icon(Icons.person_outline, size: radius)
              : Text(emoji, style: TextStyle(fontSize: radius * 0.95))),
      )),
    );
    if (!previewEnabled || bytes == null) return avatar;
    return Semantics(button: true, label: 'Ver foto de perfil', child: GestureDetector(
      key: const ValueKey('profile_view_avatar'),
      onTap: () => Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (viewerContext) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: MobileSystemBars.style(Brightness.dark), child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white,
            systemOverlayStyle: MobileSystemBars.style(Brightness.dark),
            leading: IconButton(tooltip: 'Cerrar foto', icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(viewerContext).pop())),
          body: SafeArea(child: Center(child: InteractiveViewer(
            minScale: 1, maxScale: 5, child: Image.memory(bytes,
              key: const ValueKey('profile_fullscreen_photo'), fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined,color:Colors.white,size:48)),
          ))),
        )),
      )),
      child: avatar,
    ));
  }
}
