import 'package:flutter/material.dart';

class Palette {
  static const bg = Color(0xFF050B14);
  static const bgTop = Color(0xFF0A1B2E);
  static const cyan = Color(0xFF00E5FF);
  static const green = Color(0xFF00FF9D);
  static const amber = Color(0xFFFFB020);
  static const red = Color(0xFFFF4D6D);
  static const text = Color(0xFFE8F4FF);
  static const textDim = Color(0xFF7F98B2);
  static const glass = Color(0x0FFFFFFF);
  static const glassBorder = Color(0x1FFFFFFF);

  static Color forStatus(String status) {
    switch (status) {
      case 'critical':
        return red;
      case 'warning':
        return amber;
      default:
        return green;
    }
  }
}

const neonGradient = LinearGradient(colors: [Palette.green, Palette.cyan]);

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.bgTop, Palette.bg],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -120, right: -100, child: _glow(Palette.cyan, 300)),
          Positioned(bottom: -140, left: -120, child: _glow(Palette.green, 320)),
          child,
        ],
      ),
    );
  }

  Widget _glow(Color c, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [c.withOpacity(0.14), c.withOpacity(0.0)],
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Palette.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? Palette.glassBorder),
      ),
      child: child,
    );
  }
}
