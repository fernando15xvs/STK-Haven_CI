import 'dart:convert';
import 'dart:typed_data';

import 'package:core/domain/models/user_experience_profile.dart';
import 'package:flutter/material.dart';

/// Private profile thumbnail: falls back to the selected emoji or a neutral icon.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius = 36});

  final UserExperienceProfile? profile;
  final double radius;

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
    return CircleAvatar(
      radius: radius,
      backgroundImage: photo == null ? null : MemoryImage(photo),
      child: photo != null
          ? null
          : emoji == null
              ? Icon(Icons.person_outline, size: radius)
              : Text(emoji, style: TextStyle(fontSize: radius * 0.95)),
    );
  }
}
