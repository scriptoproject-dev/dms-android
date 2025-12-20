import 'package:flutter/material.dart';

class RoundedLineIndicator extends Decoration {
  final Color color;
  final double width;
  final double radius;
  final double lengthFactor;

  const RoundedLineIndicator({
    required this.color,
    this.width = 3.0,
    this.radius = 8.0,
    this.lengthFactor = 0.6, // Default to 60% of the tab width
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _RoundedLinePainter(
      color: color,
      width: width,
      radius: radius,
      lengthFactor: lengthFactor,
    );
  }
}

class _RoundedLinePainter extends BoxPainter {
  final Color color;
  final double width;
  final double radius;
  final double lengthFactor;

  _RoundedLinePainter({
    required this.color,
    required this.width,
    required this.radius,
    required this.lengthFactor,
  });

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Calculate width of the line based on lengthFactor
    final double lineWidth = configuration.size!.width * lengthFactor;
    final double xOffset = (configuration.size!.width - lineWidth) / 2;

    final Rect rect = Offset(
          offset.dx + xOffset,
          configuration.size!.height - width,
        ) &
        Size(lineWidth, width);

    final RRect rRect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
    );

    canvas.drawRRect(rRect, paint);
  }
}
