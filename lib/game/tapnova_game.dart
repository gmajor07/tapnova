import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math';

import '../components/obstacle.dart';
import '../components/player.dart';
import '../components/shooter_gun.dart';
import '../components/shooter_projectile.dart';
import 'progression_manager.dart';
import '../ui/game_over_overlay.dart';

enum GameMode { tap, shooter }

class LevelConfig {
  final int level;
  final int goalPops;
  final double? timeLimitSeconds;
  final double minBubbleSpeed;
  final double maxBubbleSpeed;
  final double spawnRatePerSecond;

  const LevelConfig({
    required this.level,
    required this.goalPops,
    this.timeLimitSeconds,
    required this.minBubbleSpeed,
    required this.maxBubbleSpeed,
    required this.spawnRatePerSecond,
  });
}

class TapNovaGame extends FlameGame with TapCallbacks {
  TapNovaGame({required this.progressionManager});

  static const List<String> _bubbleSpritePaths = [
    'assets/bubbles/blue.png',
    'assets/bubbles/gold.png',
    'assets/bubbles/red.png',
  ];
  static const String _bombSpritePath = 'assets/bubbles/bomb.png';
  static const String _backgroundSkyPath = 'assets/backgrounds/sky.png';
  static const String _backgroundSpacePath = 'assets/backgrounds/space.png';
  static const String _popEffectPath = 'assets/effects/pop.png';
  static const String _sparkleEffectPath = 'assets/effects/sparkle.png';
  static const String _shooterGunPath = 'assets/shooter/gun.png';
  static const String _shooterProjectilePath =
      'assets/shooter/bullet_bubble.png';
  static const String _shooterAimLinePath = 'assets/shooter/aim_line.png';
  static const String _shooterShootParticlePath =
      'assets/shooter/shoot_particle.png';

  final GameProgressionManager progressionManager;
  final Random _random = Random();
  final ValueNotifier<int> uiSignal = ValueNotifier<int>(0);
  final ValueNotifier<Offset> screenShake = ValueNotifier<Offset>(Offset.zero);
  Offset? _pendingScreenShakeOffset;
  bool _screenShakePostFrameScheduled = false;

  late final TextComponent _scoreText;
  late final TextComponent _livesText;
  late final TextComponent _levelText;
  late final TextComponent _goalText;
  late final TextComponent _comboText;
  late final SpriteComponent _background;
  late final ShooterGun _shooterGun;
  late final SpriteComponent _aimLine;

  int score = 0;
  int lives = 3;
  bool isGameOver = false;
  String gameOverReason = 'No lives left.';
  GameMode _gameMode = GameMode.tap;

  int slowTimeCharges = 1;
  int bubbleMagnetCharges = 1;
  int multiplierCharges = 1;
  int bubbleBlastCharges = 1;

  double _slowTimeRemaining = 0;
  double _magnetRemaining = 0;
  double _multiplierRemaining = 0;

  double _spawnTimer = 0;
  int _currentLevelIndex = 0;
  int _levelProgress = 0;
  double _levelTimeRemaining = 0;
  int _comboChain = 0;
  double _comboWindowRemaining = 0;
  String _comboLabel = '';
  double _shakeRemaining = 0;
  double _shakeMagnitude = 0;
  double _shootCooldownRemaining = 0;
  Vector2 _aimTarget = Vector2.zero();
  final List<AchievementUnlock> _pendingAchievementUnlocks = [];

  int get coins => progressionManager.coins;
  int get rareBubbleCount => progressionManager.rareBubbles;
  List<AchievementDefinition> get unlockedAchievements =>
      progressionManager.unlockedAchievements;

  final List<LevelConfig> _levels = const [
    LevelConfig(
      level: 1,
      goalPops: 10,
      minBubbleSpeed: 120,
      maxBubbleSpeed: 160,
      spawnRatePerSecond: 1.3,
    ),
    LevelConfig(
      level: 2,
      goalPops: 20,
      minBubbleSpeed: 140,
      maxBubbleSpeed: 200,
      spawnRatePerSecond: 1.6,
    ),
    LevelConfig(
      level: 3,
      goalPops: 30,
      minBubbleSpeed: 160,
      maxBubbleSpeed: 240,
      spawnRatePerSecond: 1.9,
    ),
    LevelConfig(
      level: 4,
      goalPops: 25,
      timeLimitSeconds: 20,
      minBubbleSpeed: 180,
      maxBubbleSpeed: 280,
      spawnRatePerSecond: 2.2,
    ),
    LevelConfig(
      level: 5,
      goalPops: 50,
      minBubbleSpeed: 200,
      maxBubbleSpeed: 320,
      spawnRatePerSecond: 2.5,
    ),
  ];

  LevelConfig get currentLevel => _levels[_currentLevelIndex];
  GameMode get gameMode => _gameMode;
  bool get isTapMode => _gameMode == GameMode.tap;
  bool get isShooterMode => _gameMode == GameMode.shooter;
  bool get isSlowTimeActive => _slowTimeRemaining > 0;
  bool get isBubbleMagnetActive => _magnetRemaining > 0;
  bool get isMultiplierActive => _multiplierRemaining > 0;
  double get bubbleSpeedMultiplier => isSlowTimeActive ? 0.55 : 1.0;
  double get bubbleHitboxScale => isBubbleMagnetActive ? 1.55 : 1.0;
  int get levelProgress => _levelProgress;
  double? get levelTimeRemaining =>
      currentLevel.timeLimitSeconds == null ? null : _levelTimeRemaining;
  int get comboChain => _comboChain;
  String get comboLabel => _comboLabel;

  @override
  Future<void> onLoad() async {
    // Disable Flame's default 'assets/images/' prefix.
    images.prefix = '';

    FlameAudio.audioCache.prefix = 'assets/sounds/';
    await FlameAudio.audioCache.loadAll([
      'pop.mp3',
      'combo.mp3',
      'level_up.mp3',
    ]);
    await images.loadAll([
      ..._bubbleSpritePaths,
      _bombSpritePath,
      _backgroundSkyPath,
      _backgroundSpacePath,
      _popEffectPath,
      _sparkleEffectPath,
      _shooterGunPath,
      _shooterProjectilePath,
      _shooterAimLinePath,
      _shooterShootParticlePath,
    ]);

    _background = SpriteComponent(
      position: Vector2.zero(),
      size: size,
      sprite: Sprite(images.fromCache(_backgroundSkyPath)),
      priority: -10,
    );
    add(_background);

    _scoreText = TextComponent(
      text: '',
      position: Vector2(16, 100),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          shadows: [Shadow(color: Color(0x8800E5FF), blurRadius: 12)],
        ),
      ),
    );
    add(_scoreText);

    _livesText = TextComponent(
      text: '',
      position: Vector2(16, 128),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFB0BEC5),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
    add(_livesText);

    _levelText = TextComponent(
      text: '',
      position: Vector2(16, 152),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFB830),
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          shadows: [Shadow(color: Color(0x66FFB830), blurRadius: 8)],
        ),
      ),
    );
    add(_levelText);

    _goalText = TextComponent(
      text: '',
      position: Vector2(16, 176),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFE5F6FF),
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
    add(_goalText);

    _comboText = TextComponent(
      text: '',
      position: Vector2.zero(),
      anchor: Anchor.center,
      priority: 5,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFF176),
          fontSize: 30,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
          shadows: [Shadow(color: Color(0xAAFFB300), blurRadius: 20)],
        ),
      ),
    );
    add(_comboText);

    _aimLine = SpriteComponent(
      position: Vector2.zero(),
      size: Vector2(16, 160),
      sprite: Sprite(images.fromCache(_shooterAimLinePath)),
      anchor: Anchor.bottomCenter,
      priority: 2,
    );
    _aimLine.opacity = 0;
    add(_aimLine);

    _shooterGun = ShooterGun(spritePath: _shooterGunPath)..priority = 3;
    add(_shooterGun);

    _startLevelState();
    _aimTarget = size / 2;
    _syncShooterHud();
    _updateHud();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _background.size = size;
      _layoutShooterHud();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOver) {
      return;
    }

    _updatePowerUpTimers(dt);
    _updateComboTimer(dt);
    _updateLevelTimer(dt);
    _updateScreenShake(dt);
    _shootCooldownRemaining = max(0, _shootCooldownRemaining - dt);

    _spawnTimer += dt;
    final spawnInterval = 1 / currentLevel.spawnRatePerSecond;
    if (_spawnTimer >= spawnInterval) {
      _spawnTimer = 0;
      _spawnTarget();
    }
  }

  void _spawnTarget() {
    final radius = 24.0;
    final availableWidth = max(1.0, size.x - (radius * 2));
    final x = radius + _random.nextDouble() * availableWidth;
    final speedRange =
        currentLevel.maxBubbleSpeed - currentLevel.minBubbleSpeed;
    final fallSpeed =
        currentLevel.minBubbleSpeed + (_random.nextDouble() * speedRange);
    final bombChance = min(0.34, 0.1 + (currentLevel.level * 0.04));
    final specialBubbleChance = min(0.28, 0.08 + (currentLevel.level * 0.03));

    if (_random.nextDouble() < bombChance) {
      add(
        Obstacle(
          position: Vector2(x, -radius),
          radius: radius,
          spritePath: _bombSpritePath,
          fallSpeed: fallSpeed,
        ),
      );
      return;
    }

    final isSpecialBubble = _random.nextDouble() < specialBubbleChance;
    final bubbleSpritePath = isSpecialBubble
        ? 'assets/bubbles/gold.png'
        : _bubbleSpritePaths[_random.nextInt(_bubbleSpritePaths.length)];
    add(
      Player(
        position: Vector2(x, -radius),
        radius: radius,
        spritePath: bubbleSpritePath,
        fallSpeed: fallSpeed,
        bonusScore: isSpecialBubble ? 2 : 0,
        coinReward: isSpecialBubble ? 5 : 0,
        isRare: isSpecialBubble,
        isSpecial: isSpecialBubble,
        speedScale: isSpecialBubble ? 1.12 : 1,
      ),
    );
  }

  void onTargetTapped(Player target) {
    if (isGameOver || !target.isMounted) {
      return;
    }
    target.removeFromParent();
    _showPopEffect(target.position.clone(), target.isSpecial);
    _triggerScreenShake(target.isSpecial ? 8 : 3);
    FlameAudio.play('pop.mp3');

    _levelProgress += 1;
    final pointsEarned = _awardComboPoints();
    score += pointsEarned + target.bonusScore;
    _collectProgressRewards(
      comboChain: _comboChain,
      level: currentLevel.level,
      coinReward: target.coinReward,
      rareBubbleReward: target.isRare ? 1 : 0,
    );
    _completeLevelIfNeeded();
    _updateHud();
    _notifyUi();
  }

  void onTargetMissed(Player target) {
    if (isGameOver || !target.isMounted) {
      return;
    }
    target.removeFromParent();

    _loseLife('A bubble reached the bottom.');
  }

  void onBombTapped(Obstacle obstacle) {
    if (isGameOver || !obstacle.isMounted) {
      return;
    }
    obstacle.removeFromParent();
    _showSparkleEffect(obstacle.position.clone());
    _triggerScreenShake(12);
    _loseLife('You tapped a bomb.');
  }

  void onBombMissed(Obstacle obstacle) {
    if (!obstacle.isMounted) {
      return;
    }
    obstacle.removeFromParent();
  }

  void restartGame() {
    children.whereType<Player>().toList().forEach((target) {
      target.removeFromParent();
    });
    children.whereType<Obstacle>().toList().forEach((bomb) {
      bomb.removeFromParent();
    });
    children.whereType<ShooterProjectile>().toList().forEach((projectile) {
      projectile.removeFromParent();
    });

    score = 0;
    lives = 3;
    isGameOver = false;
    gameOverReason = 'No lives left.';
    slowTimeCharges = 1;
    bubbleMagnetCharges = 1;
    multiplierCharges = 1;
    bubbleBlastCharges = 1;
    _slowTimeRemaining = 0;
    _magnetRemaining = 0;
    _multiplierRemaining = 0;
    _spawnTimer = 0;
    _currentLevelIndex = 0;
    _comboChain = 0;
    _comboWindowRemaining = 0;
    _comboLabel = '';
    _shakeRemaining = 0;
    _shakeMagnitude = 0;
    _shootCooldownRemaining = 0;
    _setScreenShake(Offset.zero);
    _startLevelState();
    _updateBackgroundByLevel();
    _syncShooterHud();
    overlays.remove(GameOverOverlay.id);
    _updateHud();
    _notifyUi();
  }

  void setGameMode(GameMode mode) {
    if (_gameMode == mode) {
      return;
    }
    _gameMode = mode;
    if (isLoaded) {
      _syncShooterHud();
    }
    _notifyUi();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (!isShooterMode || isGameOver) {
      return;
    }
    _fireShooterProjectile(event.canvasPosition);
  }

  void _updateHud() {
    _scoreText.text = 'Score: $score';
    _livesText.text = 'Lives: $lives';
    _levelText.text =
        'Level: ${currentLevel.level} • Combo: x${_comboMultiplierForDisplay()}';
    _goalText.text = _goalHudText();
    _comboText.position = Vector2(size.x / 2, size.y * 0.22);
  }

  void _updateBackgroundByLevel() {
    final useSpace = currentLevel.level >= 3;
    final nextPath = useSpace ? _backgroundSpacePath : _backgroundSkyPath;
    _background.sprite = Sprite(images.fromCache(nextPath));
  }

  void _endGame() {
    isGameOver = true;
    _notifyUi();
    overlays.add(GameOverOverlay.id);
  }

  void _layoutShooterHud() {
    _shooterGun.position = Vector2(size.x / 2, size.y - 64);
    if (_aimTarget == Vector2.zero()) {
      _aimTarget = Vector2(size.x / 2, size.y * 0.3);
    }
    _updateAimLine();
  }

  void _syncShooterHud() {
    if (!isLoaded) {
      return;
    }
    _layoutShooterHud();
    final visibleOpacity = isShooterMode ? 1.0 : 0.0;
    _shooterGun.opacity = visibleOpacity;
    _aimLine.opacity = visibleOpacity;
  }

  void _updateAimLine() {
    final start = _shooterGun.position;
    final toTarget = _aimTarget - start;
    final direction = toTarget.length2 == 0
        ? Vector2(0, -1)
        : toTarget.normalized();
    final distance = max(64.0, min(220.0, toTarget.length));

    _aimLine.position = start;
    _aimLine.size = Vector2(18, distance);
    _aimLine.angle = direction.screenAngle();
    _shooterGun.angle = atan2(direction.y, direction.x) + (pi / 2);
  }

  void _fireShooterProjectile(Vector2 target) {
    if (_shootCooldownRemaining > 0) {
      return;
    }

    final muzzle = _shooterGun.position + Vector2(0, -28);
    final rawDirection = target - muzzle;
    if (rawDirection.length2 == 0) {
      return;
    }

    final direction = rawDirection.normalized();
    if (direction.y > -0.08) {
      return;
    }

    _aimTarget = target;
    _updateAimLine();
    _shootCooldownRemaining = 0.22;

    add(
      ShooterProjectile(
        position: muzzle.clone(),
        velocity: direction * 520,
        spritePath: _shooterProjectilePath,
      ),
    );
    _showShootEffect(muzzle);
  }

  bool resolveShooterProjectileHit(ShooterProjectile projectile) {
    if (!isShooterMode || isGameOver) {
      return false;
    }

    final projectileRadius = projectile.size.x * 0.4;
    for (final target in children.whereType<Player>().toList()) {
      final hitRadius = (target.size.x * target.scale.x) / 2;
      if ((target.position - projectile.position).length <=
          hitRadius + projectileRadius) {
        onTargetTapped(target);
        return true;
      }
    }

    for (final bomb in children.whereType<Obstacle>().toList()) {
      final hitRadius = bomb.size.x / 2;
      if ((bomb.position - projectile.position).length <=
          hitRadius + projectileRadius) {
        onBombTapped(bomb);
        return true;
      }
    }

    return false;
  }

  void _showShootEffect(Vector2 position) {
    final effect = SpriteAnimationComponent(
      position: position,
      size: Vector2.all(42),
      anchor: Anchor.center,
      priority: 4,
      animation: SpriteAnimation.spriteList([
        Sprite(images.fromCache(_shooterShootParticlePath)),
      ], stepTime: 0.06),
    );
    effect.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.45),
          EffectController(duration: 0.12, curve: Curves.easeOut),
        ),
        OpacityEffect.fadeOut(
          EffectController(duration: 0.14, curve: Curves.easeIn),
        ),
        RemoveEffect(delay: 0),
      ]),
    );
    add(effect);
  }

  String activateSlowTime() {
    if (isGameOver) {
      return 'Cannot use power-up after game over.';
    }
    if (isSlowTimeActive) {
      return 'Slow Time is already active.';
    }
    if (slowTimeCharges <= 0) {
      return 'No Slow Time charges left.';
    }

    slowTimeCharges -= 1;
    _slowTimeRemaining = 5;
    _notifyUi();
    return 'Slow Time activated for 5 seconds.';
  }

  String activateBubbleMagnet() {
    if (isGameOver) {
      return 'Cannot use power-up after game over.';
    }
    if (isBubbleMagnetActive) {
      return 'Bubble Magnet is already active.';
    }
    if (bubbleMagnetCharges <= 0) {
      return 'No Bubble Magnet charges left.';
    }

    bubbleMagnetCharges -= 1;
    _magnetRemaining = 6;
    _notifyUi();
    return 'Bubble Magnet activated for 6 seconds.';
  }

  String activateMultiplier() {
    if (isGameOver) {
      return 'Cannot use power-up after game over.';
    }
    if (isMultiplierActive) {
      return 'Multiplier is already active.';
    }
    if (multiplierCharges <= 0) {
      return 'No Multiplier charges left.';
    }

    multiplierCharges -= 1;
    _multiplierRemaining = 6;
    _notifyUi();
    return 'Score Multiplier activated for 6 seconds.';
  }

  String activateBubbleBlast() {
    if (isGameOver) {
      return 'Cannot use power-up after game over.';
    }
    if (bubbleBlastCharges <= 0) {
      return 'No Bubble Blast charges left.';
    }

    bubbleBlastCharges -= 1;
    final cleared = _blastRandomBubbles();
    _notifyUi();
    if (cleared == 0) {
      return 'Bubble Blast fired, but no bubbles were on screen.';
    }
    return 'Bubble Blast popped $cleared bubbles.';
  }

  void _updatePowerUpTimers(double dt) {
    final wasSlow = isSlowTimeActive;
    final wasMagnet = isBubbleMagnetActive;
    final wasMultiplier = isMultiplierActive;

    if (_slowTimeRemaining > 0) {
      _slowTimeRemaining = max(0, _slowTimeRemaining - dt);
    }
    if (_magnetRemaining > 0) {
      _magnetRemaining = max(0, _magnetRemaining - dt);
    }
    if (_multiplierRemaining > 0) {
      _multiplierRemaining = max(0, _multiplierRemaining - dt);
    }

    if (wasSlow != isSlowTimeActive ||
        wasMagnet != isBubbleMagnetActive ||
        wasMultiplier != isMultiplierActive) {
      _notifyUi();
    }
  }

  void _loseLife(String reason) {
    lives -= 1;
    _resetCombo();
    _triggerScreenShake(14);
    _updateHud();
    _notifyUi();

    if (lives <= 0) {
      gameOverReason = reason;
      _endGame();
      return;
    }

    if (currentLevel.timeLimitSeconds != null) {
      _levelProgress = 0;
      _levelTimeRemaining = currentLevel.timeLimitSeconds!;
    }
  }

  void _notifyUi() {
    uiSignal.value += 1;
  }

  void _showPopEffect(Vector2 center, bool isSpecial) {
    _showBurstEffect(center, _popEffectPath);
    _showPopParticles(
      center,
      isSpecial ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF),
      isSpecial ? 12 : 8,
    );
  }

  void _showSparkleEffect(Vector2 center) {
    _showBurstEffect(center, _sparkleEffectPath);
    _showPopParticles(center, const Color(0xFFFF6E8A), 12);
  }

  void _showBurstEffect(Vector2 center, String spritePath) {
    final effect = SpriteComponent(
      sprite: Sprite(images.fromCache(spritePath)),
      size: Vector2.all(40),
      position: center,
      anchor: Anchor.center,
      priority: 2,
    );
    effect.add(
      ScaleEffect.to(Vector2.all(1.5), EffectController(duration: 0.2)),
    );
    effect.add(
      OpacityEffect.fadeOut(
        EffectController(duration: 0.2),
        onComplete: effect.removeFromParent,
      ),
    );
    add(effect);
  }

  void _showPopParticles(Vector2 center, Color color, int count) {
    for (var index = 0; index < count; index++) {
      final particle = CircleComponent(
        radius: 3 + _random.nextDouble() * 3,
        position: center.clone(),
        anchor: Anchor.center,
        priority: 3,
        paint: Paint()..color = color.withValues(alpha: 0.9),
      );
      final angle = _random.nextDouble() * pi * 2;
      final distance = 18 + _random.nextDouble() * 34;
      particle.add(
        MoveEffect.by(
          Vector2(cos(angle) * distance, sin(angle) * distance),
          EffectController(duration: 0.28 + _random.nextDouble() * 0.14),
        ),
      );
      particle.add(
        ScaleEffect.to(
          Vector2.all(0.15),
          EffectController(duration: 0.32 + _random.nextDouble() * 0.12),
        ),
      );
      particle.add(
        OpacityEffect.fadeOut(
          EffectController(duration: 0.32 + _random.nextDouble() * 0.12),
          onComplete: particle.removeFromParent,
        ),
      );
      add(particle);
    }
  }

  void _startLevelState() {
    _levelProgress = 0;
    _levelTimeRemaining = currentLevel.timeLimitSeconds ?? 0;
    _resetCombo();
  }

  int _awardComboPoints() {
    final bool withinWindow = _comboWindowRemaining > 0;
    _comboChain = withinWindow ? _comboChain + 1 : 1;
    _comboWindowRemaining = 1.15;

    var points = 1;
    if (_comboChain >= 5) {
      points *= 3;
      _triggerComboFeedback('SUPER COMBO x3');
    } else if (_comboChain >= 3) {
      points *= 2;
      _triggerComboFeedback('COMBO x2');
    } else {
      _comboLabel = '';
    }

    if (isMultiplierActive) {
      points *= 2;
      _triggerComboFeedback(
        _comboChain >= 3 ? '$_comboLabel • x2 SCORE' : 'x2 SCORE',
      );
    }

    return points;
  }

  void _triggerComboFeedback(String label) {
    _comboLabel = label;
    _comboText.text = label;
    _comboText.scale = Vector2.all(0.6);
    _comboText.children.whereType<Effect>().toList().forEach((effect) {
      effect.removeFromParent();
    });
    _comboText.add(
      ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.16)),
    );
    FlameAudio.play('combo.mp3');
    _showComboFlash();
    _triggerScreenShake(6);
  }

  void _showComboFlash() {
    final flash = RectangleComponent(
      position: Vector2.zero(),
      size: size.clone(),
      priority: 4,
      paint: Paint()..color = const Color(0x55FFF176),
    );
    flash.add(
      OpacityEffect.fadeOut(
        EffectController(duration: 0.22),
        onComplete: flash.removeFromParent,
      ),
    );
    add(flash);
  }

  void _completeLevelIfNeeded() {
    if (_levelProgress < currentLevel.goalPops) {
      return;
    }

    final previousLevel = currentLevel.level;
    if (_currentLevelIndex < _levels.length - 1) {
      _currentLevelIndex += 1;
      _startLevelState();
      _collectAchievementUnlocks(
        progressionManager.recordLevelReached(currentLevel.level),
      );
      FlameAudio.play('level_up.mp3');
      _updateBackgroundByLevel();
      _triggerComboFeedback('LEVEL ${currentLevel.level}');
      addCoins(25);
      return;
    }

    _levelProgress = currentLevel.goalPops;
    if (previousLevel == _levels.last.level) {
      gameOverReason = 'You cleared every level.';
      _endGame();
    }
  }

  void _updateLevelTimer(double dt) {
    if (currentLevel.timeLimitSeconds == null || isGameOver) {
      return;
    }

    _levelTimeRemaining = max(0, _levelTimeRemaining - dt);
    if (_levelTimeRemaining == 0) {
      _loseLife('Time ran out on Level ${currentLevel.level}.');
    }
    _updateHud();
  }

  void _updateComboTimer(double dt) {
    if (_comboWindowRemaining > 0) {
      _comboWindowRemaining = max(0, _comboWindowRemaining - dt);
      if (_comboWindowRemaining == 0) {
        _resetCombo();
        _notifyUi();
      }
    }
  }

  void _resetCombo() {
    _comboChain = 0;
    _comboWindowRemaining = 0;
    _comboLabel = '';
    _comboText.text = '';
  }

  int _comboMultiplierForDisplay() {
    if (_comboChain >= 5) {
      return 3;
    }
    if (_comboChain >= 3) {
      return 2;
    }
    return 1;
  }

  String _goalHudText() {
    final goalText = 'Goal: $_levelProgress/${currentLevel.goalPops} pops';
    final timeLimit = currentLevel.timeLimitSeconds;
    if (timeLimit == null) {
      return goalText;
    }

    return '$goalText • ${_levelTimeRemaining.ceil()}s left';
  }

  int _blastRandomBubbles() {
    final bubbles = children
        .whereType<Player>()
        .where((bubble) => bubble.isMounted)
        .toList();
    if (bubbles.isEmpty) {
      return 0;
    }

    bubbles.shuffle(_random);
    final count = min(6, bubbles.length);
    for (final bubble in bubbles.take(count)) {
      onTargetTapped(bubble);
    }
    return count;
  }

  void _collectProgressRewards({
    required int comboChain,
    required int level,
    required int coinReward,
    required int rareBubbleReward,
  }) {
    if (coinReward > 0) {
      progressionManager.addCoins(coinReward);
    }
    if (rareBubbleReward > 0) {
      progressionManager.addRareBubble(count: rareBubbleReward);
    }
    _collectAchievementUnlocks(
      progressionManager.recordBubblePop(comboChain: comboChain, level: level),
    );
  }

  void _collectAchievementUnlocks(List<AchievementUnlock> unlocks) {
    if (unlocks.isEmpty) {
      return;
    }
    _pendingAchievementUnlocks.addAll(unlocks);
    _notifyUi();
  }

  List<AchievementUnlock> takePendingAchievementUnlocks() {
    final unlocks = List<AchievementUnlock>.from(_pendingAchievementUnlocks);
    _pendingAchievementUnlocks.clear();
    return unlocks;
  }

  void addCoins(int amount) {
    progressionManager.addCoins(amount);
    _notifyUi();
  }

  String grantRandomPowerUpReward() {
    final rewardIndex = _random.nextInt(4);
    switch (rewardIndex) {
      case 0:
        slowTimeCharges += 1;
        break;
      case 1:
        bubbleMagnetCharges += 1;
        break;
      case 2:
        multiplierCharges += 1;
        break;
      default:
        bubbleBlastCharges += 1;
        break;
    }
    _notifyUi();
    switch (rewardIndex) {
      case 0:
        return 'Slow Time +1';
      case 1:
        return 'Magnet +1';
      case 2:
        return 'Multiplier +1';
      default:
        return 'Bubble Blast +1';
    }
  }

  void grantRareBubbleReward() {
    progressionManager.addRareBubble();
    _notifyUi();
  }

  void _triggerScreenShake(double magnitude) {
    _shakeMagnitude = max(_shakeMagnitude, magnitude);
    _shakeRemaining = max(_shakeRemaining, 0.18);
  }

  void _setScreenShake(Offset offset) {
    if (screenShake.value == offset && _pendingScreenShakeOffset == null) {
      return;
    }

    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    final canUpdateNow =
        schedulerPhase == SchedulerPhase.idle ||
        schedulerPhase == SchedulerPhase.postFrameCallbacks;

    if (canUpdateNow) {
      _pendingScreenShakeOffset = null;
      screenShake.value = offset;
      return;
    }

    _pendingScreenShakeOffset = offset;
    if (_screenShakePostFrameScheduled) {
      return;
    }

    _screenShakePostFrameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _screenShakePostFrameScheduled = false;
      final pendingOffset = _pendingScreenShakeOffset;
      _pendingScreenShakeOffset = null;
      if (pendingOffset != null && screenShake.value != pendingOffset) {
        screenShake.value = pendingOffset;
      }
    });
  }

  void _updateScreenShake(double dt) {
    if (_shakeRemaining <= 0) {
      if (screenShake.value != Offset.zero) {
        _setScreenShake(Offset.zero);
      }
      return;
    }

    _shakeRemaining = max(0, _shakeRemaining - dt);
    final dx = (_random.nextDouble() * 2 - 1) * _shakeMagnitude;
    final dy = (_random.nextDouble() * 2 - 1) * _shakeMagnitude;
    _setScreenShake(Offset(dx, dy));

    if (_shakeRemaining == 0) {
      _shakeMagnitude = 0;
      _setScreenShake(Offset.zero);
    }
  }
}
