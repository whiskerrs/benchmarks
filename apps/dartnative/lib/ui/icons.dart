import 'package:dartnative/dartnative.dart';

/// The line icons drawn in the design, as vector paths on a 24x24 grid
/// (stroke 1.75, round caps and joins, as in the SVGs).
enum AppIcon { home, search, cart, back, minus, plus, alert }

class AppIconView extends StatelessWidget {
  const AppIconView(
    this.icon, {
    super.key,
    this.size = 24,
    this.color = const Color(0xFF1C1B19),
    this.strokeWidth = 1.75,
  });

  final AppIcon icon;
  final double size;
  final Color color;

  /// Stroke width in the 24-unit design grid.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _IconPainter(icon, color, strokeWidth),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.icon, this.color, this.strokeWidth);

  final AppIcon icon;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint(
      color: color,
      style: PaintingStyle.stroke,
      strokeWidth: strokeWidth * s,
      strokeCap: StrokeCap.round,
      strokeJoin: StrokeJoin.round,
    );
    final p = Path();
    void m(double x, double y) => p.moveTo(x * s, y * s);
    void l(double x, double y) => p.lineTo(x * s, y * s);
    void c(double x1, double y1, double x2, double y2, double x, double y) =>
        p.cubicTo(x1 * s, y1 * s, x2 * s, y2 * s, x * s, y * s);
    // Quarter-circle arc of radius r approximated with one cubic.
    const k = 0.5523;

    switch (icon) {
      case AppIcon.home:
        // M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z
        m(3, 10.5);
        l(12, 3);
        l(21, 10.5);
        l(21, 20);
        c(21, 20 + k, 20 + k, 21, 20, 21);
        l(15, 21);
        l(15, 15);
        l(9, 15);
        l(9, 21);
        l(4, 21);
        c(4 - k, 21, 3, 20 + k, 3, 20);
        p.close();
        canvas.drawPath(p, paint);
      case AppIcon.search:
        // circle cx=11 cy=11 r=7; m20 20-3.5-3.5
        canvas.drawCircle(Offset(11 * s, 11 * s), 7 * s, paint);
        m(20, 20);
        l(16.5, 16.5);
        canvas.drawPath(p, paint);
      case AppIcon.cart:
        // M6 7h12l-1 13H7z ; M9 7a3 3 0 0 1 6 0
        m(6, 7);
        l(18, 7);
        l(17, 20);
        l(7, 20);
        p.close();
        m(9, 7);
        c(9, 5.343, 10.343, 4, 12, 4);
        c(13.657, 4, 15, 5.343, 15, 7);
        canvas.drawPath(p, paint);
      case AppIcon.back:
        // m15 5-7 7 7 7
        m(15, 5);
        l(8, 12);
        l(15, 19);
        canvas.drawPath(p, paint);
      case AppIcon.minus:
        m(5, 12);
        l(19, 12);
        canvas.drawPath(p, paint);
      case AppIcon.plus:
        m(12, 5);
        l(12, 19);
        m(5, 12);
        l(19, 12);
        canvas.drawPath(p, paint);
      case AppIcon.alert:
        // circle r=9; M12 7.5v5.5; M12 16.5h.01
        canvas.drawCircle(Offset(12 * s, 12 * s), 9 * s, paint);
        m(12, 7.5);
        l(12, 13);
        m(12, 16.5);
        l(12.01, 16.5);
        canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
}
