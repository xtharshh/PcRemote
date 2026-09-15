import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Responsive card: comfortable on phones, roomier past 600px.
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  const ResponsiveCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 600;
        return Card(
          margin: EdgeInsets.all(wide ? 16 : 8),
          child: Padding(
            padding: EdgeInsets.all(wide ? 24 : 16),
            child: child,
          ),
        );
      },
    );
  }
}

/// LumiLink logo: sun/brightness + link, drawn with code so it matches
/// on Android, Windows and in-app without binary assets.
/// Same mark everywhere: rounded indigo→teal tile, amber sun, link arc.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'LumiLink logo',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LogoPainter()),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide;
    final rect = Rect.fromLTWH(0, 0, r, r);
    // Tile: indigo -> teal gradient, rounded.
    final tile = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF0D9488)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(r * 0.24)), tile);
    final cx = r / 2, cy = r * 0.44;
    // Sun core.
    canvas.drawCircle(
        Offset(cx, cy), r * 0.15, Paint()..color = const Color(0xFFFFC53D));
    // Sun rays.
    final ray = Paint()
      ..color = const Color(0xFFFFC53D)
      ..strokeWidth = r * 0.045
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p1 = Offset(cx + (r * 0.22) * math.cos(a), cy + (r * 0.22) * math.sin(a));
      final p2 = Offset(cx + (r * 0.30) * math.cos(a), cy + (r * 0.30) * math.sin(a));
      canvas.drawLine(p1, p2, ray);
    }
    // Link arc under the sun.
    final link = Paint()
      ..color = Colors.white
      ..strokeWidth = r * 0.06
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy + r * 0.34), radius: r * 0.20),
        math.pi * 0.15, math.pi * 0.7, false, link);
    canvas.drawCircle(Offset(cx - r * 0.20, cy + r * 0.30), r * 0.05, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + r * 0.20, cy + r * 0.30), r * 0.05, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Small section heading used across screens.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// Big action button: 150ms press-scale, loading state, haptic tap,
/// screen-reader label.
class BigActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final Future<void> Function() onTap;

  const BigActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  State<BigActionButton> createState() => _BigActionButtonState();
}

class _BigActionButtonState extends State<BigActionButton> {
  double _scale = 1.0;
  bool _busy = false;

  Future<void> _press() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _scale = 0.95;
      _busy = true;
    });
    try {
      await widget.onTap();
    } finally {
      if (mounted) {
        setState(() {
          _scale = 1.0;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.95),
        onTapUp: (_) => _press(),
        onTapCancel: () => setState(() => _scale = 1.0),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _press,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(widget.icon),
              label: Text(widget.label),
              style: widget.color == null
                  ? null
                  : ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      foregroundColor: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated brightness ring: sweeps from the previous value to the new one.
class BrightnessRing extends StatefulWidget {
  final int value;
  final int suggest;
  const BrightnessRing({super.key, required this.value, required this.suggest});

  @override
  State<BrightnessRing> createState() => _BrightnessRingState();
}

class _BrightnessRingState extends State<BrightnessRing> {
  late double _from;
  late double _to;

  @override
  void initState() {
    super.initState();
    _from = 0;
    _to = widget.value / 100;
  }

  @override
  void didUpdateWidget(covariant BrightnessRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = _to;
      _to = widget.value / 100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: SizedBox(
        width: 168,
        height: 168,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: _from, end: _to),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => CustomPaint(
            painter: _RingPainter(
              progress: v,
              track: scheme.surfaceContainerHighest,
              bar: scheme.primary,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${widget.value}%',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('suggest ${widget.suggest}%',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color bar;
  static const _stroke = 14.0;

  const _RingPainter(
      {required this.progress, required this.track, required this.bar});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - _stroke) / 2,
    );
    final trackPaint = Paint()
      ..color = track
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final barPaint = Paint()
      ..color = bar
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, trackPaint);
    canvas.drawArc(
        rect, -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0), false, barPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.bar != bar || old.track != track;
}
