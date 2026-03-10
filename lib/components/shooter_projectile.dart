import 'package:flame/components.dart';

import '../game/tapnova_game.dart';

class ShooterProjectile extends SpriteComponent
    with HasGameReference<TapNovaGame> {
  ShooterProjectile({
    required super.position,
    required this.velocity,
    required String spritePath,
  }) : _spritePath = spritePath,
       super(anchor: Anchor.center, size: Vector2.all(26));

  final Vector2 velocity;
  final String _spritePath;

  @override
  Future<void> onLoad() async {
    sprite = Sprite(game.images.fromCache(_spritePath));
    angle = velocity.screenAngle();
    await super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;

    if (game.resolveShooterProjectileHit(this)) {
      removeFromParent();
      return;
    }

    if (position.y < -size.y ||
        position.y > game.size.y + size.y ||
        position.x < -size.x ||
        position.x > game.size.x + size.x) {
      removeFromParent();
    }
  }
}
