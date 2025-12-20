import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/colors.dart';

class CelebrationPopup {
  /// Shows celebration for first-line compliance + helpful yes
  static void showWellDone(BuildContext context) {
    _showPopup(
      context: context,
      leftIcon: Icons.celebration,
      rightIcon: Icons.celebration,
      leftIconColor: Colors.orange,
      rightIconColor: Colors.pink,
      message: "Well done! You're helping fight antimicrobial resistance.",
      showIcons: true,
      showConfetti: true,
    );
  }

  /// Shows thank you for all other cases (line 2/3, no_abx, or not helpful)
  static void showThankYou(BuildContext context) {
    _showPopup(
      context: context,
      message: "Thank you for your response.",
      showIcons: false,
      showConfetti: false,
    );
  }

  static void _showPopup({
    required BuildContext context,
    IconData? leftIcon,
    IconData? rightIcon,
    Color? leftIconColor,
    Color? rightIconColor,
    required String message,
    required bool showIcons,
    required bool showConfetti,
  }) {
    // Close previous bottom sheets only
    bool canPop = true;
    while (canPop) {
      if (ModalRoute.of(context)?.isCurrent == false) {
        Navigator.pop(context);
      } else {
        canPop = false;
      }
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        // Automatically close after duration
        Future.delayed(const Duration(seconds: 3), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          // Navigate to HomeScreen
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
        });

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Confetti overlay
              if (showConfetti) const ConfettiOverlay(),

              // Main content
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    border: showIcons
                        ? null
                        : Border.all(color: primaryColor, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Show icons only for showWellDone
                      if (showIcons) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _AnimatedIcon(
                              icon: leftIcon!,
                              color: leftIconColor!,
                              delay: 0,
                            ),
                            _AnimatedIcon(
                              icon: rightIcon!,
                              color: rightIconColor!,
                              delay: 100,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: showIcons ? 18 : 16,
                          fontWeight:
                              showIcons ? FontWeight.normal : FontWeight.w500,
                          fontStyle:
                              showIcons ? FontStyle.italic : FontStyle.normal,
                          color: showIcons ? Colors.black87 : primaryColor,
                        ),
                      ),
                      if (showIcons) const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
        );
      },
    );
  }
}

// Animated icon widget with bounce effect
class _AnimatedIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final int delay;

  const _AnimatedIcon({
    required this.icon,
    required this.color,
    required this.delay,
  });

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);

    _rotationAnimation = Tween<double>(
      begin: -0.2,
      end: 0.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Icon(
              widget.icon,
              color: widget.color,
              size: 48,
            ),
          ),
        );
      },
    );
  }
}

// Confetti overlay widget
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({Key? key}) : super(key: key);

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<ConfettiParticle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // Generate confetti particles
    _particles = List.generate(50, (index) {
      return ConfettiParticle(
        color: _getRandomColor(),
        startX: _random.nextDouble(),
        startY: -0.1,
        endY: 1.2,
        rotation: _random.nextDouble() * 2 * pi,
        size: _random.nextDouble() * 8 + 4,
        drift: (_random.nextDouble() - 0.5) * 0.3,
        delay: _random.nextDouble() * 0.3,
      );
    });

    _controller.forward();
  }

  Color _getRandomColor() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
          ),
          child: Container(),
        );
      },
    );
  }
}

// Confetti particle data class
class ConfettiParticle {
  final Color color;
  final double startX;
  final double startY;
  final double endY;
  final double rotation;
  final double size;
  final double drift;
  final double delay;

  ConfettiParticle({
    required this.color,
    required this.startX,
    required this.startY,
    required this.endY,
    required this.rotation,
    required this.size,
    required this.drift,
    required this.delay,
  });
}

// Custom painter for confetti
class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      // Calculate adjusted progress with delay
      double adjustedProgress = (progress - particle.delay).clamp(0.0, 1.0);

      if (adjustedProgress <= 0) continue;

      // Calculate position with easing
      double easedProgress = _easeOutCubic(adjustedProgress);
      double y =
          particle.startY + (particle.endY - particle.startY) * easedProgress;
      double x = particle.startX + particle.drift * easedProgress;

      // Calculate rotation
      double rotation = particle.rotation * adjustedProgress * 4;

      // Calculate opacity (fade out near the end)
      double opacity =
          adjustedProgress < 0.8 ? 1.0 : (1.0 - adjustedProgress) * 5;

      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(rotation);

      // Draw confetti as rectangles
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: particle.size,
        height: particle.size * 1.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );

      canvas.restore();
    }
  }

  double _easeOutCubic(double t) {
    return 1 - pow(1 - t, 3).toDouble();
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
