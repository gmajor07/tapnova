import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../game/tapnova_game.dart';

class Player extends SpriteComponent
    with TapCallbacks, HasGameReference<TapNovaGame> {
  final String spritePath;
  final double fallSpeed;
  final double radius;
  final int bonusScore;
  final int coinReward;
  final bool isRare;
  final bool isSpecial;
  final double speedScale;

  Player({
    required super.position,
    required this.radius,
    required this.spritePath,
    required this.fallSpeed,
    this.bonusScore = 0,
    this.coinReward = 0,
    this.isRare = false,
    this.isSpecial = false,
    this.speedScale = 1,
  }) : super(anchor: Anchor.center, size: Vector2.all(radius * 2));

  @override
  Future<void> onLoad() async {
    sprite = Sprite(game.images.fromCache(spritePath));
    await super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    scale.setAll(game.bubbleHitboxScale);
    position.y += fallSpeed * speedScale * game.bubbleSpeedMultiplier * dt;

    final visibleRadius = (size.y * scale.y) / 2;
    if (position.y - visibleRadius > game.size.y) {
      game.onTargetMissed(this);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (!game.isTapMode) {
      return;
    }
    game.onTargetTapped(this);
  }
}
