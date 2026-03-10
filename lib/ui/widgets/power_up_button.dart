import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Individual power-up pill button with charge count and active glow state.
class PowerUpButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int charges;
  final bool isActive;
  final VoidCallback? onPressed;

  const PowerUpButton({
    super.key,
    required this.icon,
    required this.label,
    required this.charges,
    required this.isActive,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = charges > 0 && onPressed != null;

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentCyan.withValues(alpha: 0.12)
              : AppTheme.bgCardElevated.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.accentCyan : AppTheme.borderSubtle,
            width: isActive ? 1.4 : 1.0,
          ),
          boxShadow: isActive ? AppTheme.cyanGlow(spread: 2, blur: 10) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active indicator dot
            if (isActive) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.accentCyan,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentCyan,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              icon,
              size: 15,
              color: enabled
                  ? (isActive ? AppTheme.accentCyan : Colors.white70)
                  : AppTheme.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: enabled
                    ? (isActive ? AppTheme.accentCyan : Colors.white)
                    : AppTheme.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 6),
            // Charge badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: enabled
                    ? AppTheme.accentCyan.withValues(alpha: 0.18)
                    : AppTheme.textMuted.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$charges',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: enabled ? AppTheme.accentCyan : AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
