import 'dart:async';

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

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _opacity = 1.0;
        _yOffset = 0.0;
      });
    });

    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _navegarSiguientePantalla();
    });
  }

  Future<void> _navegarSiguientePantalla() async {
    if (!mounted) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AppRoot(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (reduceMotion) return child;
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final introDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 450);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Tu compañero de entrenamiento',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.grey[400],
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 42),
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
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
                    style: AppTypography.bodySmall.copyWith(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'SLF 2026',
                    style: AppTypography.labelLarge.copyWith(color: Colors.grey[400]),
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
