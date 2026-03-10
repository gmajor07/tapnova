import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final int coinsReward;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.coinsReward,
  });
}

class AchievementUnlock {
  final AchievementDefinition definition;

  const AchievementUnlock(this.definition);
}

class GameProgressionManager {
  static const _coinsKey = 'progression_coins';
  static const _totalPopsKey = 'progression_total_pops';
  static const _bestComboKey = 'progression_best_combo';
  static const _highestLevelKey = 'progression_highest_level';
  static const _rareBubblesKey = 'progression_rare_bubbles';
  static const _unlockedAchievementsKey = 'progression_unlocked_achievements';

  static const List<AchievementDefinition> achievementDefinitions = [
    AchievementDefinition(
      id: 'bubble_master',
      title: 'Bubble Master',
      description: 'Pop 100 bubbles',
      coinsReward: 100,
    ),
    AchievementDefinition(
      id: 'speed_tapper',
      title: 'Speed Tapper',
      description: 'Reach a 10-hit combo',
      coinsReward: 150,
    ),
    AchievementDefinition(
      id: 'survivor',
      title: 'Survivor',
      description: 'Reach level 5',
      coinsReward: 200,
    ),
  ];

  SharedPreferences? _prefs;

  int coins = 0;
  int totalPops = 0;
  int bestCombo = 0;
  int highestLevel = 1;
  int rareBubbles = 0;
  final Set<String> unlockedAchievementIds = <String>{};

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    coins = _prefs!.getInt(_coinsKey) ?? 0;
    totalPops = _prefs!.getInt(_totalPopsKey) ?? 0;
    bestCombo = _prefs!.getInt(_bestComboKey) ?? 0;
    highestLevel = _prefs!.getInt(_highestLevelKey) ?? 1;
    rareBubbles = _prefs!.getInt(_rareBubblesKey) ?? 0;
    unlockedAchievementIds
      ..clear()
      ..addAll(_prefs!.getStringList(_unlockedAchievementsKey) ?? const []);
  }

  List<AchievementUnlock> recordBubblePop({
    required int comboChain,
    required int level,
    int coinsEarned = 0,
  }) {
    totalPops += 1;
    bestCombo = max(bestCombo, comboChain);
    highestLevel = max(highestLevel, level);
    coins += coinsEarned;
    _schedulePersist();
    return _unlockEligibleAchievements();
  }

  List<AchievementUnlock> recordLevelReached(int level) {
    highestLevel = max(highestLevel, level);
    _schedulePersist();
    return _unlockEligibleAchievements();
  }

  void addCoins(int amount) {
    if (amount <= 0) {
      return;
    }
    coins += amount;
    _schedulePersist();
  }

  void addRareBubble({int count = 1}) {
    if (count <= 0) {
      return;
    }
    rareBubbles += count;
    _schedulePersist();
  }

  List<AchievementDefinition> get unlockedAchievements => achievementDefinitions
      .where((achievement) => unlockedAchievementIds.contains(achievement.id))
      .toList(growable: false);

  List<AchievementUnlock> _unlockEligibleAchievements() {
    final unlocks = <AchievementUnlock>[];
    for (final achievement in achievementDefinitions) {
      if (unlockedAchievementIds.contains(achievement.id)) {
        continue;
      }
      if (!_isUnlockedByStats(achievement.id)) {
        continue;
      }
      unlockedAchievementIds.add(achievement.id);
      coins += achievement.coinsReward;
      unlocks.add(AchievementUnlock(achievement));
    }
    if (unlocks.isNotEmpty) {
      _schedulePersist();
    }
    return unlocks;
  }

  bool _isUnlockedByStats(String id) {
    switch (id) {
      case 'bubble_master':
        return totalPops >= 100;
      case 'speed_tapper':
        return bestCombo >= 10;
      case 'survivor':
        return highestLevel >= 5;
      default:
        return false;
    }
  }

  void _schedulePersist() {
    if (_prefs == null) {
      return;
    }
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    await prefs.setInt(_coinsKey, coins);
    await prefs.setInt(_totalPopsKey, totalPops);
    await prefs.setInt(_bestComboKey, bestCombo);
    await prefs.setInt(_highestLevelKey, highestLevel);
    await prefs.setInt(_rareBubblesKey, rareBubbles);
    await prefs.setStringList(
      _unlockedAchievementsKey,
      unlockedAchievementIds.toList(growable: false),
    );
  }
}
