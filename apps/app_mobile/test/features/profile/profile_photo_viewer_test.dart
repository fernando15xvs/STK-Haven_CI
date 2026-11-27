import 'package:core/domain/models/user_experience_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/layout/mobile_content_frame.dart';
import 'package:gym_tracker/features/profile/presentation/widgets/profile_avatar.dart';

const png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=';

Widget _root({bool reduceMotion = false}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: const EdgeInsets.only(top: 44, bottom: 34),
      viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
      disableAnimations: reduceMotion,
    ),
    child: MobileContentFrame(child: child!),
  ),
  home: const _ProfileHarness(),
);

class _ProfileHarness extends StatefulWidget {
  const _ProfileHarness();
  @override
  State<_ProfileHarness> createState() => _ProfileHarnessState();
}
class _ProfileHarnessState extends State<_ProfileHarness> {
  var _name = 'Inicial';
  bool _showPhoto = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ProfileAvatar(profile: UserExperienceProfile(
        avatarPhotoBase64: _showPhoto ? png : null,
      ), previewEnabled: true, radius: 54),
      TextButton(onPressed: () async {
        await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) =>
          Scaffold(appBar: AppBar(title: const Text('Ajustes')))));
        if (mounted) setState(() => _name = 'Actualizado');
      }, child: const Text('Ajustes')),
      Text(_name),
      TextButton(onPressed: () => setState(() => _showPhoto = false),
        child: const Text('Quitar foto')),
    ])),
  );
}

void main() {
  testWidgets('avatar retains the exact provider across settings and rebuild', (tester) async {
    await tester.pumpWidget(_root());
    await tester.pumpAndSettle();
    final before = tester.widget<Image>(find.byType(Image)).image;
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Actualizado'), findsOneWidget);
    final after = tester.widget<Image>(find.byType(Image));
    expect(identical(before, after.image), isTrue);
    expect(after.gaplessPlayback, isTrue);
    await tester.tap(find.text('Quitar foto'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for(final reduceMotion in [false, true]) {
    testWidgets('private viewer fills viewport, colors status band, zooms and closes (reduce motion: $reduceMotion)', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_root(reduceMotion: reduceMotion));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile_view_avatar')));
      await tester.pumpAndSettle();
      final photo = find.byKey(const ValueKey('profile_fullscreen_photo'));
      expect(photo, findsOneWidget);
      expect(tester.getSize(photo), const Size(390, 800));
      expect(tester.widget<Image>(photo).fit, BoxFit.contain);
      final status = find.byKey(const ValueKey('mobile_dark_media_status_area'));
      expect(tester.getRect(status).height, 44);
      expect(tester.widget<ColoredBox>(status).color, Colors.black);
      final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      final center = tester.getCenter(photo);
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), closeTo(2.5, .01));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), closeTo(1, .01));
      await tester.tap(find.byTooltip('Cerrar foto'));
      await tester.pumpAndSettle();
      expect(photo, findsNothing);
      expect(status, findsNothing);
      expect(find.byKey(const ValueKey('profile_view_avatar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('one finger downward gesture closes at base zoom', (tester) async {
    await tester.pumpWidget(_root(reduceMotion: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile_view_avatar')));
    await tester.pumpAndSettle();
    final viewer = find.byType(InteractiveViewer);
    await tester.timedDrag(viewer, const Offset(0, 180), const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(viewer, findsNothing);
    expect(find.byKey(const ValueKey('mobile_dark_media_status_area')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
