import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../game/tapnova_game.dart';

class Obstacle extends SpriteComponent
    with TapCallbacks, HasGameReference<TapNovaGame> {
  final String spritePath;
  final double fallSpeed;
  final double radius;

  Obstacle({
    required super.position,
    required this.radius,
    required this.spritePath,
    required this.fallSpeed,
  }) : super(anchor: Anchor.center, size: Vector2.all(radius * 2));

  @override
  Future<void> onLoad() async {
    sprite = Sprite(game.images.fromCache(spritePath));
    await super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += fallSpeed * dt;

    if (position.y - (size.y / 2) > game.size.y) {
      game.onBombMissed(this);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (!game.isTapMode) {
      return;
    }
    game.onBombTapped(this);
  }
}
