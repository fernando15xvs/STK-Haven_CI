import 'dart:async';

import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_root.dart';
import '../core/theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  double _opacity = 0.0;
  double _yOffset = 18.0;
  Timer? _introTimer;
  Timer? _navigationTimer;
  bool _bibleInitializationScheduled = false;

  @override
  void initState() {
    super.initState();

    _introTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _opacity = 1.0;
        _yOffset = 0.0;
      });
    });

    _navigationTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _navegarSiguientePantalla();
    });
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _navigationTimer?.cancel();
    super.dispose();
  }

  void _navegarSiguientePantalla() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AppRoot(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (reduceMotion) return child;
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final faithEnabled =
        ref.watch(userExperienceProfileProvider).value?.faithEnabled == true;
    if (faithEnabled && !_bibleInitializationScheduled) {
      _bibleInitializationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(userExperienceProfileProvider).value?.faithEnabled ==
                true) {
          unawaited(ref.read(bibleInitProvider.notifier).initialize());
        }
      });
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final introDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 450);

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: Stack(
        children: [
          Center(
            child: AnimatedContainer(
              duration: introDuration,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _yOffset, 0),
              child: AnimatedOpacity(
                duration: introDuration,
                opacity: _opacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: FractionallySizedBox(
                        widthFactor: 0.82,
                        child: Image.asset('assets/imagenes/slf_logo.png'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'STK Haven',
                      style: AppTypography.displaySmall.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.of(context).textPrimary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Tu compañero de entrenamiento',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.of(context).textSecondary,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 42),
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.of(context).primary,
                        strokeWidth: 2.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: introDuration,
              opacity: _opacity,
              child: Column(
                children: [
                  Text(
                    'Versión 1.0.0',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'SLF 2026',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
