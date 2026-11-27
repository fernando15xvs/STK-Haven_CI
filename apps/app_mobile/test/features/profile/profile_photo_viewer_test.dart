import 'package:core/domain/models/user_experience_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/profile/presentation/widgets/profile_avatar.dart';

void main(){
  testWidgets('photo opens private zoom viewer and closes without editing',(tester)async{
    const png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=';
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Center(
      child:ProfileAvatar(profile:UserExperienceProfile(avatarPhotoBase64:png),previewEnabled:true,radius:54)))));
    await tester.tap(find.byKey(const ValueKey('profile_view_avatar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile_fullscreen_photo')),findsOneWidget);
    expect(find.byType(InteractiveViewer),findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar foto'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile_fullscreen_photo')),findsNothing);
    expect(tester.takeException(),isNull);
  });
}
