import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/daily_rewards.dart';
import 'game/progression_manager.dart';
import 'game/tapnova_game.dart';
import 'managers/ad_manager.dart';
import 'ui/game_over_overlay.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/glass_card.dart';
import 'ui/widgets/glow_button.dart';
import 'ui/widgets/power_up_button.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ads in the background so it doesn't block app startup
  unawaited(AdManager.init());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapNova',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const GameWidgetWrapper(),
    );
  }
}

class GameWidgetWrapper extends StatefulWidget {
  const GameWidgetWrapper({super.key});

  @override
  State<GameWidgetWrapper> createState() => _GameWidgetWrapperState();
}

class _GameWidgetWrapperState extends State<GameWidgetWrapper> {
  late final TapNovaGame _game;
  final DailyRewardManager _dailyRewardManager = DailyRewardManager();
  final GameProgressionManager _progressionManager = GameProgressionManager();
  final Set<int> _levelsWithShownAds = <int>{};
  bool _isRewardReady = false;
  bool _isGameStarted = false;
  bool _isShowingAd = false;
  GameMode _selectedGameMode = GameMode.tap;

  @override
  void initState() {
    super.initState();
    _game = TapNovaGame(progressionManager: _progressionManager);
    _game.pauseEngine();
    _game.uiSignal.addListener(_handleGameUiSignal);
    _initializeRewards();
  }

  @override
  void dispose() {
    _game.uiSignal.removeListener(_handleGameUiSignal);
    super.dispose();
  }

  void _startGame() {
    _game.setGameMode(_selectedGameMode);
    setState(() {
      _isGameStarted = true;
    });
    _game.resumeEngine();
  }

  Future<void> _initializeRewards() async {
    try {
      await _progressionManager.load();
      await _dailyRewardManager.load();
    } catch (e) {
      debugPrint('Error initializing rewards: $e');
    }

    if (!mounted) return;
    setState(() {
      _isRewardReady = true;
    });
  }

  Future<void> _claimDailyReward() async {
    final reward = await _dailyRewardManager.claimToday();
    if (!mounted) return;
    var message = 'Today\'s reward already claimed!';

    if (reward != null) {
      switch (reward.type) {
        case DailyRewardType.coins:
          _game.addCoins(reward.amount, countTowardsRun: false);
          message = 'Day ${reward.day}: +${reward.amount} coins';
          break;
        case DailyRewardType.powerUp:
          message = 'Day ${reward.day}: ${_game.grantRandomPowerUpReward()}';
          break;
        case DailyRewardType.rareBubble:
          _game.grantRareBubbleReward();
          message = 'Day ${reward.day}: Rare bubble unlocked';
          break;
      }
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _usePowerUp(String Function() activate) {
    _showSnackBar(activate());
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _restartGame() {
    _game.restartGame();
    _levelsWithShownAds.clear();
    setState(() {});
  }

  Future<void> _showRewardedAd({
    required AdPlacement placement,
    required String Function() onReward,
  }) async {
    final level = _game.currentLevel.level;
    if (_isShowingAd) {
      return;
    }
    if (_levelsWithShownAds.contains(level)) {
      return;
    }

    setState(() {
      _isShowingAd = true;
    });

    final result = await AdManager.showRewarded(placement: placement);
    if (!mounted) {
      return;
    }

    setState(() {
      _isShowingAd = false;
    });

    if (result.rewarded) {
      _levelsWithShownAds.add(level);
      _showSnackBar(onReward());
      return;
    }

    _showSnackBar(result.message ?? 'No rewarded ad available right now.');
  }

  Future<void> _continueWithRewardedAd() async {
    final level = _game.currentLevel.level;
    if (_isShowingAd) {
      return;
    }
    if (!_game.isGameOver || !_game.canContinueWithAd) {
      _showSnackBar('Continue is not available right now.');
      return;
    }
    if (_levelsWithShownAds.contains(level)) {
      _showSnackBar('This level already used its ad.');
      return;
    }

    setState(() {
      _isShowingAd = true;
    });

    final result = await AdManager.showRewarded(
      placement: AdPlacement.continueGame,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isShowingAd = false;
    });

    if (!result.rewarded) {
      _showSnackBar(result.message ?? 'No rewarded ad available right now.');
      return;
    }

    _levelsWithShownAds.add(level);
    final message = _game.continueFromRewardedAd();
    _game.resumeEngine();
    setState(() {});
    _showSnackBar(message);
  }

  void _handleGameUiSignal() {
    if (!mounted) {
      return;
    }

    final unlocks = _game.takePendingAchievementUnlocks();
    for (final unlock in unlocks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Achievement unlocked: ${unlock.definition.title} (+${unlock.definition.coinsReward} coins)',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (_isGameStarted) {
      setState(() {});
    }
  }

  // ── Daily Reward card ─────────────────────────────────────────────────
  Widget _buildDailyRewardCard() {
    if (!_isRewardReady) return const SizedBox.shrink();

    final nextReward = _dailyRewardManager.nextReward;
    final canClaim = _dailyRewardManager.canClaimToday();

    return GlassCard(
      borderColor: AppTheme.borderGoldGlow,
      radius: 16,
      shadows: AppTheme.goldGlow(spread: 2, blur: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              size: 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DAY ${nextReward.day}',
                style: const TextStyle(
                  color: AppTheme.accentGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                nextReward.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          _PremiumClaimButton(canClaim: canClaim, onPressed: _claimDailyReward),
        ],
      ),
    );
  }

  // ── Power-ups panel ───────────────────────────────────────────────────
  Widget _buildPowerUpsCard() {
    return Positioned(
      left: 12,
      bottom: MediaQuery.of(context).padding.bottom + 12,
      child: ValueListenableBuilder<int>(
        valueListenable: _game.uiSignal,
        builder: (context, _, __) {
          return GlassCard(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                const Text('POWER-UPS', style: AppTheme.labelStyle),
                const SizedBox(height: 8),
                // Buttons row
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    PowerUpButton(
                      icon: Icons.access_time_rounded,
                      label: 'SLOW',
                      charges: _game.slowTimeCharges,
                      isActive: _game.isSlowTimeActive,
                      onPressed: _game.slowTimeCharges > 0
                          ? () => _usePowerUp(_game.activateSlowTime)
                          : null,
                    ),
                    PowerUpButton(
                      icon: Icons.electric_bolt_rounded,
                      label: 'MAGNET',
                      charges: _game.bubbleMagnetCharges,
                      isActive: _game.isBubbleMagnetActive,
                      onPressed: _game.bubbleMagnetCharges > 0
                          ? () => _usePowerUp(_game.activateBubbleMagnet)
                          : null,
                    ),
                    PowerUpButton(
                      icon: Icons.auto_fix_high_rounded,
                      label: 'x2',
                      charges: _game.multiplierCharges,
                      isActive: _game.isMultiplierActive,
                      onPressed: _game.multiplierCharges > 0
                          ? () => _usePowerUp(_game.activateMultiplier)
                          : null,
                    ),
                    PowerUpButton(
                      icon: Icons.blur_on_rounded,
                      label: 'BLAST',
                      charges: _game.bubbleBlastCharges,
                      isActive: false,
                      onPressed: _game.bubbleBlastCharges > 0
                          ? () => _usePowerUp(_game.activateBubbleBlast)
                          : null,
                    ),
                    PowerUpButton(
                      icon: Icons.video_library_rounded,
                      label: 'P-UP AD',
                      charges: 0,
                      isActive: _isShowingAd,
                      onPressed: _isShowingAd
                          ? null
                          : () => _showRewardedAd(
                              placement: AdPlacement.unlockPowerUp,
                              onReward: _game.grantRandomPowerUpReward,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressCard() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 12,
      child: ValueListenableBuilder<int>(
        valueListenable: _game.uiSignal,
        builder: (context, _, __) {
          final unlockedIds = _game.unlockedAchievements
              .map((achievement) => achievement.id)
              .toSet();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GlassCard(
                borderColor: AppTheme.borderGoldGlow,
                radius: 16,
                shadows: AppTheme.goldGlow(spread: 2, blur: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      size: 16,
                      color: AppTheme.accentGold,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_game.coins} coins',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Rare ${_game.rareBubbleCount}',
                        style: const TextStyle(
                          color: AppTheme.accentCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildDailyRewardCard(),
              const SizedBox(height: 10),
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ACHIEVEMENTS', style: AppTheme.labelStyle),
                    const SizedBox(height: 8),
                    ...GameProgressionManager.achievementDefinitions.map((def) {
                      final unlockedNow = unlockedIds.contains(def.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              unlockedNow
                                  ? Icons.verified_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 14,
                              color: unlockedNow
                                  ? AppTheme.accentGreen
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              def.title,
                              style: TextStyle(
                                color: unlockedNow
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '+${def.coinsReward}',
                              style: const TextStyle(
                                color: AppTheme.accentGold,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Brand badge (top-left) ─────────────────────────────────────────────
  Widget _buildTopLeftBrand() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.cyanPurpleGradient.createShader(bounds),
                  child: const Icon(
                    Icons.bubble_chart_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 7),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.cyanPurpleGradient.createShader(bounds),
                  child: const Text(
                    'TAPNOVA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SESSION', style: AppTheme.labelStyle),
                const SizedBox(height: 4),
                Text(
                  'Pops ${_progressionManager.totalPops} • Best combo ${_progressionManager.bestCombo}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Start overlay ─────────────────────────────────────────────────────
  Widget _buildStartOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppTheme.bgDark.withValues(alpha: 0.88),
        child: Stack(
          children: [
            // Decorative radial orbs
            Positioned(
              top: -60,
              left: -40,
              child: _GlowOrb(
                color: AppTheme.accentCyan,
                size: 220,
                opacity: 0.12,
              ),
            ),
            Positioned(
              bottom: -80,
              right: -60,
              child: _GlowOrb(
                color: AppTheme.accentPurple,
                size: 280,
                opacity: 0.12,
              ),
            ),
            // Center content
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: GlassCard(
                    radius: 24,
                    borderColor: AppTheme.borderGlow,
                    shadows: [
                      BoxShadow(
                        color: AppTheme.accentCyan.withValues(alpha: 0.15),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 30,
                      ),
                    ],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 36,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo orb
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: AppTheme.cyanPurpleGradient,
                            shape: BoxShape.circle,
                            boxShadow: AppTheme.cyanGlow(spread: 4, blur: 20),
                          ),
                          child: const Icon(
                            Icons.bubble_chart_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Title with gradient
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.cyanPurpleGradient.createShader(bounds),
                          child: const Text(
                            'TAPNOVA',
                            style: AppTheme.gameTitleStyle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Divider line
                        Container(
                          height: 1,
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: AppTheme.cyanPurpleGradient,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Tagline
                        const Text(
                          'Pop bubbles. Avoid bombs.',
                          style: AppTheme.bodyStyle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _ModeOptionCard(
                                label: 'TAP',
                                icon: Icons.touch_app_rounded,
                                description: 'Tap bubbles directly.',
                                isSelected: _selectedGameMode == GameMode.tap,
                                onTap: () {
                                  setState(() {
                                    _selectedGameMode = GameMode.tap;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ModeOptionCard(
                                label: 'SHOOTER',
                                icon: Icons.ads_click_rounded,
                                description: 'Aim the gun and fire shots.',
                                isSelected:
                                    _selectedGameMode == GameMode.shooter,
                                onTap: () {
                                  setState(() {
                                    _selectedGameMode = GameMode.shooter;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _selectedGameMode == GameMode.tap
                              ? 'Classic mode: tap bubbles, avoid bombs.'
                              : 'Shooter mode: tap to fire upward from the cannon.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        // Start button
                        SizedBox(
                          width: double.infinity,
                          child: GlowButton(
                            label: _selectedGameMode == GameMode.tap
                                ? 'START TAP MODE'
                                : 'START SHOOTER MODE',
                            onPressed: _startGame,
                            gradient: AppTheme.cyanPurpleGradient,
                            glowShadows: AppTheme.cyanGlow(spread: 4, blur: 22),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            height: 56,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ValueListenableBuilder<Offset>(
            valueListenable: _game.screenShake,
            builder: (context, offset, child) {
              return Transform.translate(offset: offset, child: child);
            },
            child: GameWidget<TapNovaGame>(
              game: _game,
              overlayBuilderMap: {
                GameOverOverlay.id: (context, game) => GameOverOverlay(
                  game: game,
                  onRestart: _restartGame,
                  onContinue: game.canContinueWithAd
                      ? _continueWithRewardedAd
                      : null,
                  onDoubleCoins: game.canDoubleCoinsWithAd
                      ? () => _showRewardedAd(
                          placement: AdPlacement.doubleCoins,
                          onReward: game.claimDoubleCoinsReward,
                        )
                      : null,
                  isShowingAd: _isShowingAd,
                ),
              },
            ),
          ),
          if (_isGameStarted) ...[
            _buildTopLeftBrand(),
            _buildProgressCard(),
            _buildPowerUpsCard(),
          ] else
            _buildStartOverlay(),
        ],
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────────

/// Decorative radial glow orb for backgrounds.
class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });

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
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.label,
    required this.icon,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isSelected ? AppTheme.cyanPurpleGradient : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentCyan.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: isSelected ? AppTheme.cyanGlow(spread: 1, blur: 10) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact animated claim button for daily reward card.
class _PremiumClaimButton extends StatelessWidget {
  final bool canClaim;
  final VoidCallback onPressed;

  const _PremiumClaimButton({required this.canClaim, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canClaim ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: canClaim ? AppTheme.goldGradient : null,
          color: canClaim ? null : AppTheme.bgCardElevated,
          borderRadius: BorderRadius.circular(10),
          boxShadow: canClaim ? AppTheme.goldGlow(spread: 2, blur: 8) : null,
        ),
        child: Text(
          canClaim ? 'CLAIM' : 'CLAIMED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: canClaim ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
