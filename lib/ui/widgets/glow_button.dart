import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A gradient button with neon glow shadow. Dims when disabled.
class GlowButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final LinearGradient gradient;
  final List<BoxShadow>? glowShadows;
  final Widget? icon;
  final double height;
  final double fontSize;
  final double radius;

  const GlowButton({
    super.key,
    required this.label,
    this.onPressed,
    this.gradient = AppTheme.cyanPurpleGradient,
    this.glowShadows,
    this.icon,
    this.height = 52,
    this.fontSize = 15,
    this.radius = 14,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.35,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              gradient: enabled ? widget.gradient : const LinearGradient(
                colors: [Color(0xFF2A3050), Color(0xFF1E2540)],
              ),
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: enabled
                  ? (widget.glowShadows ?? AppTheme.cyanGlow())
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  widget.icon!,
                  const SizedBox(width: 10),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
