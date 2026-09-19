import 'package:flutter/material.dart';

/// The official mark for a social sign-in provider.
///
/// These colours are not design tokens — they are somebody else's trademark,
/// which must be reproduced exactly and look the same in every theme. The web
/// client's `social-providers.tsx` is the reference for Google's four-colour G;
/// Facebook carries Meta blue for the same reason.
class AppSocialProviderMark extends StatelessWidget {
  const AppSocialProviderMark(this.provider, {this.size = 24, super.key});

  final String provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (provider) {
      'google' => SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(painter: _GoogleMarkPainter()),
      ),
      'facebook' => SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(painter: _FacebookMarkPainter()),
      ),
      _ => _UnknownProviderMark(name: provider, size: size),
    };
  }
}

class _UnknownProviderMark extends StatelessWidget {
  const _UnknownProviderMark({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String initial = name.isEmpty
        ? '?'
        : String.fromCharCodes(name.runes.take(1)).toUpperCase();

    return Text(
      initial,
      style: TextStyle(fontSize: size * 0.75, fontWeight: FontWeight.w600),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _green = Color(0xFF34A853);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 48;

    canvas.save();
    canvas.scale(scale);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    paint.color = _blue;
    canvas.drawPath(
      Path()
        ..moveTo(45.12, 24.5)
        ..cubicTo(45.12, 22.94, 44.98, 21.44, 44.72, 20)
        ..lineTo(24, 20)
        ..lineTo(24, 28.51)
        ..lineTo(35.84, 28.51)
        ..cubicTo(35.34, 31.01, 33.68, 33.09, 31.45, 34.45)
        ..lineTo(31.45, 39.97)
        ..lineTo(38.56, 39.97)
        ..cubicTo(42.72, 36.14, 45.12, 30.5, 45.12, 24.5)
        ..close(),
      paint,
    );

    paint.color = _green;
    canvas.drawPath(
      Path()
        ..moveTo(24, 46)
        ..cubicTo(29.94, 46, 34.92, 44.03, 38.56, 40.67)
        ..lineTo(31.45, 35.15)
        ..cubicTo(29.48, 36.47, 26.96, 37.25, 24, 37.25)
        ..cubicTo(18.27, 37.25, 13.42, 33.38, 11.69, 28.18)
        ..lineTo(4.34, 28.18)
        ..lineTo(4.34, 33.88)
        ..cubicTo(8.02, 40.94, 15.46, 46, 24, 46)
        ..close(),
      paint,
    );

    paint.color = _yellow;
    canvas.drawPath(
      Path()
        ..moveTo(11.69, 28.18)
        ..cubicTo(11.25, 26.86, 11, 25.45, 11, 24)
        ..cubicTo(11, 22.55, 11.25, 21.14, 11.69, 19.82)
        ..lineTo(11.69, 14.12)
        ..lineTo(4.34, 14.12)
        ..cubicTo(2.85, 17.09, 2, 20.45, 2, 24)
        ..cubicTo(2, 27.55, 2.85, 30.91, 4.34, 33.88)
        ..lineTo(11.69, 28.18)
        ..close(),
      paint,
    );

    paint.color = _red;
    canvas.drawPath(
      Path()
        ..moveTo(24, 9.75)
        ..cubicTo(27.23, 9.75, 30.13, 10.86, 32.41, 13.04)
        ..lineTo(38.72, 6.73)
        ..cubicTo(34.91, 3.18, 29.93, 1, 24, 1)
        ..cubicTo(15.4, 1, 7.96, 5.94, 4.34, 13.12)
        ..lineTo(11.69, 19.82)
        ..cubicTo(13.42, 14.62, 18.27, 10.75, 24, 10.75)
        ..close(),
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FacebookMarkPainter extends CustomPainter {
  const _FacebookMarkPainter();

  static const Color _blue = Color(0xFF1877F2);

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);

    final Paint paint = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path()
        ..moveTo(24, 12.073)
        ..cubicTo(24, 5.446, 18.627, 0.073, 12, 0.073)
        ..cubicTo(5.373, 0.073, 0, 5.446, 0, 12.073)
        ..cubicTo(0, 18.063, 4.388, 23.027, 10.125, 23.927)
        ..lineTo(10.125, 15.542)
        ..lineTo(7.078, 15.542)
        ..lineTo(7.078, 12.073)
        ..lineTo(10.125, 12.073)
        ..lineTo(10.125, 9.43)
        ..cubicTo(10.125, 6.423, 11.917, 4.754, 14.658, 4.754)
        ..cubicTo(15.97, 4.754, 17.344, 4.989, 18.656, 5.224)
        ..lineTo(18.656, 8.177)
        ..lineTo(17.203, 8.177)
        ..cubicTo(15.797, 8.177, 15.281, 8.925, 15.281, 9.749)
        ..lineTo(15.281, 12.073)
        ..lineTo(18.609, 12.073)
        ..lineTo(18.077, 15.542)
        ..lineTo(15.281, 15.542)
        ..lineTo(15.281, 23.927)
        ..cubicTo(20.612, 23.027, 24, 18.063, 24, 12.073)
        ..close(),
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
