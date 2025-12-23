import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_io/io.dart';
import 'dart:math' as math;
import 'folder_homepage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    // Rotation Animation for Border
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Pulse/Breathing Animation (Looping)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Fade In Animation (One-time)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _startApp();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _startApp() async {
    // 3 saniye bekle
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Windows'ta pencereyi tam ekran yap
    if (!kIsWeb && Platform.isWindows) {
      // Restore system UI overlays
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );

      // Set window style for Main App
      await windowManager.setAsFrameless(); // Maintain frameless look
      await windowManager.setHasShadow(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);

      // Enforce Main App constraints
      await windowManager.setResizable(false);
      await windowManager.setAlwaysOnTop(false);

      // Finally, go fullscreen
      await windowManager.setFullScreen(true);
      await windowManager.focus();
    }

    if (!mounted) return;

    // Ana sayfaya geç
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const FolderHomePage(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: FadeTransition(
          opacity: _fadeController,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 0.95).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: SizedBox(
              width: 450,
              height: 450,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Optimized Glowing Border
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: OptimizedBorderPainter(
                          animationValue: _rotationController.value,
                        ),
                        size: const Size(450, 450),
                      );
                    },
                  ),
                  // Logo
                  Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      filterQuality:
                          FilterQuality.medium, // Better performance than high
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OptimizedBorderPainter extends CustomPainter {
  final double animationValue;

  OptimizedBorderPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Logo is roughly square within the stack, let's draw a nice rounded rect or circle.
    // Assuming circularish logo or wanting a circular glow for "tech" feel.
    // If we want a rect, we can use RRect.

    // Let's go with a Rounded Rectangle that roughly matches the logo containment
    final side = size.width * 0.85;
    final rect = Rect.fromCenter(center: center, width: side, height: side);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(40));

    // 1. Static Glow (Much cheaper than blur mask filter on every frame)
    // Actually, drawing a shadow with elevation is cheap.
    // Or we can just draw a thick stroke with low opacity.

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15.0
      ..color = Colors.blue
          .withOpacity(0.15) // Static glow color
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        20,
      ); // Static blur is okay if not animating path metrics

    canvas.drawRRect(rrect, glowPaint);

    // 2. Rotating Gradient Border
    // We rotate the shader transform instead of calculating path metrics
    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: const [
          Colors.transparent,
          Colors.cyan,
          Colors.blue,
          Colors.purple,
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        transform: GradientRotation(animationValue * 2 * math.pi),
      ).createShader(rect);

    canvas.drawRRect(rrect, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant OptimizedBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
