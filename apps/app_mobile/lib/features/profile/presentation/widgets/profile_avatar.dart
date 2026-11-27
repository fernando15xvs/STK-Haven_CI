import 'dart:async';
import 'dart:convert';

import 'package:core/domain/models/user_experience_profile.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/layout/mobile_content_frame.dart';

import 'profile_photo_viewer.dart';

/// Decode only when the actual photo changes, not on route transitions,
/// settings updates or unrelated profile writes.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius = 36, this.previewEnabled = false});
  final UserExperienceProfile? profile;
  final double radius;
  final bool previewEnabled;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  final Object _heroTag = Object();
  MemoryImage? _photo;
  ImageProvider<Object>? _thumbnail;
  int? _thumbnailPixels;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _decodePhoto();
  }

  void _decodePhoto() {
    _photo = null;
    _thumbnail = null;
    _thumbnailPixels = null;
    final encoded = widget.profile?.avatarPhotoBase64;
    if (encoded == null || encoded.isEmpty) return;
    try {
      _photo = MemoryImage(base64Decode(encoded));
    } on FormatException {
      // A corrupt legacy profile remains usable with its fallback avatar.
    }
  }

  void _prepareThumbnail() {
    final photo = _photo;
    if (photo == null) return;
    final pixels = (widget.radius * 2 * MediaQuery.devicePixelRatioOf(context) * 1.5)
        .ceil().clamp(1, 768).toInt();
    if (_thumbnail != null && _thumbnailPixels == pixels) return;
    _thumbnailPixels = pixels;
    final thumbnail = ResizeImage(photo, width: pixels, height: pixels,
      policy: ResizeImagePolicy.fit);
    _thumbnail = thumbnail;
    precacheImage(thumbnail, context, onError: (error, stack) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareThumbnail();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.avatarPhotoBase64 != widget.profile?.avatarPhotoBase64) {
      _decodePhoto();
    }
    _prepareThumbnail();
  }

  Future<void> _openPhoto() async {
    final photo = _photo;
    if (photo == null || _opening) return;
    _opening = true;
    try {
      unawaited(precacheImage(photo, context, onError: (error, stack) {}));
      if (!mounted || !identical(photo, _photo)) return;
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final viewer = ProfilePhotoViewer(
        photo: photo, heroTag: reduceMotion ? null : _heroTag,
      );
      final route = PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, __, ___) => viewer,
        transitionDuration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
        reverseTransitionDuration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      );
      await MobileContentFrame.pushDarkMediaRoute(context, route);
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    final thumbnail = _thumbnail;
    final emoji = widget.profile?.avatarEmoji;
    Widget avatar = SizedBox.square(
      dimension: widget.radius * 2,
      child: ClipOval(
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: thumbnail != null
              ? Image(
                  key: ObjectKey(photo),
                  image: thumbnail,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Icon(Icons.person_outline, size: widget.radius),
                )
              : Center(child: emoji == null
                  ? Icon(Icons.person_outline, size: widget.radius)
                  : Text(emoji, style: TextStyle(fontSize: widget.radius * .95))),
        ),
      ),
    );
    if (!widget.previewEnabled || photo == null) return avatar;
    if (!MediaQuery.disableAnimationsOf(context)) {
      avatar = Hero(tag: _heroTag, child: avatar);
    }
    return Semantics(
      button: true, label: 'Ver foto de perfil',
      child: GestureDetector(
        key: const ValueKey('profile_view_avatar'), onTap: _openPhoto, child: avatar,
      ),
    );
  }
}
