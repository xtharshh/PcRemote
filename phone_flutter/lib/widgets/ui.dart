import 'package:flutter/material.dart';

/// Responsive card: comfortable padding on phones, roomier on wide screens.
/// (LayoutBuilder pattern from the flutter-ui-ux skill.)
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

/// Big action button with a 150ms press-scale micro-interaction
/// and a screen-reader label (skill: animations + accessibility).
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
