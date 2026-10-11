import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

class _View {
  final Rect bounds;
  final Size size;
  _View(this.bounds, this.size);

  double get s =>
      math.min(size.width / bounds.width, size.height / bounds.height);
  Offset get o => Offset((size.width - bounds.width * s) / 2,
      (size.height - bounds.height * s) / 2);
  Offset toScreen(Offset w) =>
      Offset((w.dx - bounds.left) * s + o.dx, (w.dy - bounds.top) * s + o.dy);
}

class RadarView extends StatefulWidget {
  final Farm farm;
  final String? selectedId;
  final String? locateId;
  final ValueChanged<String?> onSelect;

  const RadarView({
    super.key,
    required this.farm,
    required this.selectedId,
    required this.locateId,
    required this.onSelect,
  });

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap(Offset p, Size size) {
    final v = _View(widget.farm.bounds, size);
    String? best;
    double bestD = 28;
    for (final a in widget.farm.animals) {
      final d = (v.toScreen(a.pos) - p).distance;
      if (d < bestD) {
        bestD = d;
        best = a.id;
      }
    }
    widget.onSelect(best);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: const Color(0xFF07111C),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _tap(d.localPosition, size),
              child: CustomPaint(
                size: size,
                painter: _RadarPainter(
                  widget.farm,
                  widget.selectedId,
                  widget.locateId,
                  _c,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _RadarPainter extends CustomPainter {
  final Farm farm;
  final String? selectedId;
  final String? locateId;
  final Animation<double> anim;

  _RadarPainter(this.farm, this.selectedId, this.locateId, this.anim)
      : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final v = _View(farm.bounds, size);
    final t = anim.value;

    // Grid every 100 m
    final grid = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    for (double gx = (farm.bounds.left / 100).ceil() * 100.0;
        gx <= farm.bounds.right;
        gx += 100) {
      canvas.drawLine(v.toScreen(Offset(gx, farm.bounds.top)),
          v.toScreen(Offset(gx, farm.bounds.bottom)), grid);
    }
    for (double gy = (farm.bounds.top / 100).ceil() * 100.0;
        gy <= farm.bounds.bottom;
        gy += 100) {
      canvas.drawLine(v.toScreen(Offset(farm.bounds.left, gy)),
          v.toScreen(Offset(farm.bounds.right, gy)), grid);
    }

    // Fence
    final path = Path();
    for (int i = 0; i < farm.fence.length; i++) {
      final p = v.toScreen(farm.fence[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    final breach =
        farm.alerts.any((a) => a.active && !a.acknowledged && a.kind == 'fence');
    final fenceColor = breach ? Palette.red : Palette.cyan;

    canvas.drawPath(path, Paint()..color = fenceColor.withOpacity(0.06));
    canvas.drawPath(
      path,
      Paint()
        ..color = fenceColor.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = fenceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Radar rings and sweep, centred on the paddock
    var cx = 0.0, cy = 0.0;
    for (final p in farm.fence) {
      cx += p.dx;
      cy += p.dy;
    }
    final centre = v.toScreen(Offset(cx / farm.fence.length, cy / farm.fence.length));
    final radius = v.s * math.max(farm.bounds.width, farm.bounds.height) * 0.55;
    final ring = Paint()
      ..color = Palette.cyan.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final f in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(centre, radius * f, ring);
    }
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.transparent,
            Palette.cyan.withOpacity(0.0),
            Palette.cyan.withOpacity(0.22),
          ],
          stops: const [0.0, 0.75, 1.0],
          transform: GradientRotation(t * 2 * math.pi),
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );

    // Animals
    for (final a in farm.animals) {
      final color = Palette.forStatus(a.status);

      for (int i = 1; i < a.trail.length; i++) {
        canvas.drawLine(
          v.toScreen(a.trail[i - 1]),
          v.toScreen(a.trail[i]),
          Paint()
            ..color = color.withOpacity(0.5 * i / a.trail.length)
            ..strokeWidth = 1.5,
        );
      }

      final p = v.toScreen(a.pos);

      if (a.alarm) {
        canvas.drawCircle(
          p,
          6 + 26 * t,
          Paint()
            ..color = Palette.red.withOpacity(1 - t)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      if (a.id == locateId) {
        for (final ph in [t, (t + 0.5) % 1.0]) {
          canvas.drawCircle(
            p,
            8 + 40 * ph,
            Paint()
              ..color = Palette.green.withOpacity(1 - ph)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        }
      }

      canvas.drawCircle(
        p,
        10,
        Paint()
          ..color = color.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(p, 4.5, Paint()..color = color);

      if (a.id == selectedId) {
        canvas.drawCircle(
          p,
          13,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      if (a.id == selectedId || a.alarm || a.id == locateId) {
        _label(canvas, a.name.toUpperCase(), p, color);
      }
    }
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at + const Offset(12, -20));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.farm != farm ||
      old.selectedId != selectedId ||
      old.locateId != locateId;
}
