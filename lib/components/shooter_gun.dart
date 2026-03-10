import 'package:flame/components.dart';

import '../game/tapnova_game.dart';

class ShooterGun extends SpriteComponent with HasGameReference<TapNovaGame> {
  ShooterGun({required String spritePath})
    : _spritePath = spritePath,
      super(anchor: Anchor.center);

  final String _spritePath;

  @override
  Future<void> onLoad() async {
    sprite = Sprite(game.images.fromCache(_spritePath));
    size = Vector2(108, 108);
    await super.onLoad();
  }
}
