import 'dart:ui';
import 'package:flutter/material.dart';
import '../game/tapnova_game.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_card.dart';
import 'widgets/glow_button.dart';

class GameOverOverlay extends StatelessWidget {
  final TapNovaGame game;
  static const String id = 'GameOver';

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blurred backdrop with red tint
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: const Color(0xFF200008).withValues(alpha: 0.78),
            ),
          ),
        ),
        // Decorative orbs
        Positioned(
          top: -80,
          right: -60,
          child: _Orb(color: AppTheme.accentRed, size: 260, opacity: 0.1),
        ),
        Positioned(
          bottom: -80,
          left: -60,
          child: _Orb(color: AppTheme.accentPurple, size: 240, opacity: 0.08),
        ),
        // Center card
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: GlassCard(
              radius: 24,
              borderColor: AppTheme.accentRed.withValues(alpha: 0.4),
              shadows: [
                BoxShadow(
                  color: AppTheme.accentRed.withValues(alpha: 0.18),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 30,
                ),
              ],
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Danger icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppTheme.redOrangeGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.redGlow(spread: 4, blur: 18),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // GAME OVER gradient text
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppTheme.redOrangeGradient.createShader(bounds),
                    child: const Text(
                      'GAME OVER',
                      style: AppTheme.headingStyle,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppTheme.borderSubtle,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Score display
                  Text('${game.score}', style: AppTheme.scoreStyle),
                  const Text('FINAL SCORE', style: AppTheme.labelStyle),
                  const SizedBox(height: 14),
                  // Level badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppTheme.cyanPurpleGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.cyanGlow(spread: 1, blur: 8),
                    ),
                    child: Text(
                      game.levelTimeRemaining == null
                          ? 'LEVEL ${game.currentLevel.level}  ·  GOAL ${game.levelProgress}/${game.currentLevel.goalPops}'
                          : 'LEVEL ${game.currentLevel.level}  ·  GOAL ${game.levelProgress}/${game.currentLevel.goalPops}  ·  ${game.levelTimeRemaining!.ceil()}S',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Reason
                  Text(
                    game.gameOverReason,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.accentRed,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Restart button
                  SizedBox(
                    width: double.infinity,
                    child: GlowButton(
                      label: 'RESTART',
                      onPressed: game.restartGame,
                      gradient: AppTheme.cyanPurpleGradient,
                      glowShadows: AppTheme.cyanGlow(spread: 3, blur: 18),
                      icon: const Icon(
                        Icons.replay_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      height: 52,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _Orb({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
