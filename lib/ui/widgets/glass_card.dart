import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A premium glassmorphic card with blur backdrop and neon border.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color borderColor;
  final List<BoxShadow>? shadows;
  final double blurSigma;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    this.radius = 20,
    this.borderColor = AppTheme.borderGlow,
    this.shadows,
    this.blurSigma = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: AppTheme.glassCard(
            borderColor: borderColor,
            radius: radius,
            shadows: shadows,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
