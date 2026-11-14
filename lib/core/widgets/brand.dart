import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Circular "SB" monogram with a gold double ring and petal marks.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MonogramPainter(onDark: onDark),
        child: Center(
          child: Text(
            'SB',
            style: TextStyle(
              fontFamily: AppTheme.serif,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.34,
              letterSpacing: -0.5,
              color: onDark ? AppColors.goldLight : AppColors.maroon,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonogramPainter extends CustomPainter {
  _MonogramPainter({required this.onDark});
  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final fill = Paint()..color = onDark ? AppColors.maroon800 : AppColors.ivory;
    canvas.drawCircle(c, r, fill);
    final gold = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(c, r - 1, gold..strokeWidth = 1.6);
    canvas.drawCircle(c, r * 0.80, gold..strokeWidth = 0.8);
    // 12 small petals between the rings
    final petal = Paint()..color = AppColors.gold;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final p = c + Offset(math.cos(a), math.sin(a)) * (r * 0.9);
      canvas.drawCircle(p, r * 0.035, petal);
    }
  }

  @override
  bool shouldRepaint(covariant _MonogramPainter old) => old.onDark != onDark;
}

/// A thin saree-border ("zari") motif: two gold rules with a row of small
/// diamonds between them. Used under headers and on the login screen.
class ZariBorder extends StatelessWidget {
  const ZariBorder({super.key, this.height = 12, this.color = AppColors.gold, this.opacity = 1});

  final double height;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _ZariPainter(color.withValues(alpha: opacity))),
      );
}

class _ZariPainter extends CustomPainter {
  _ZariPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, 0.5), Offset(size.width, 0.5), line);
    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), line);
    final mid = size.height / 2;
    final d = size.height * 0.28;
    final step = d * 3.2;
    final fill = Paint()..color = color;
    var i = 0;
    for (double x = step / 2; x < size.width; x += step) {
      if (i.isEven) {
        final path = Path()
          ..moveTo(x, mid - d)
          ..lineTo(x + d, mid)
          ..lineTo(x, mid + d)
          ..lineTo(x - d, mid)
          ..close();
        canvas.drawPath(path, fill);
      } else {
        canvas.drawCircle(Offset(x, mid), d * 0.35, fill);
      }
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _ZariPainter old) => old.color != color;
}

/// "Shah Brothers" wordmark with optional tagline.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.onDark = false, this.size = 28, this.showTagline = true});

  final bool onDark;
  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Shah Brothers',
          style: TextStyle(
            fontFamily: AppTheme.serif,
            fontWeight: FontWeight.w700,
            fontSize: size,
            letterSpacing: -0.3,
            color: onDark ? AppColors.ivory : AppColors.maroon,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'HERITAGE SAREES · SINCE 1972',
            style: TextStyle(
              fontSize: size * 0.36,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w600,
              color: onDark ? AppColors.goldLight : AppColors.goldDeep,
            ),
          ),
        ],
      ],
    );
  }
}

/// Maroon hero panel used at the top of dashboards.
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 22)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.maroon, AppColors.maroon900],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.maroon900.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: Opacity(
                opacity: 0.08,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.goldLight, width: 18),
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
            const Positioned(left: 0, right: 0, bottom: 0, child: ZariBorder(height: 10, opacity: 0.55)),
          ],
        ),
      ),
    );
  }
}
