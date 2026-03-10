import 'package:shared_preferences/shared_preferences.dart';

class DailyReward {
  final int day;
  final String label;
  final DailyRewardType type;
  final int amount;

  const DailyReward({
    required this.day,
    required this.label,
    required this.type,
    this.amount = 0,
  });
}

enum DailyRewardType { coins, powerUp, rareBubble }

class DailyRewardState {
  final int streakDay;
  final String? lastClaimDate;

  const DailyRewardState({
    required this.streakDay,
    required this.lastClaimDate,
  });
}

class DailyRewardManager {
  static const _streakKey = 'daily_reward_streak';
  static const _lastClaimKey = 'daily_reward_last_claim';

  final List<DailyReward> rewards = const [
    DailyReward(
      day: 1,
      label: '100 coins',
      type: DailyRewardType.coins,
      amount: 100,
    ),
    DailyReward(
      day: 2,
      label: 'Power-up',
      type: DailyRewardType.powerUp,
      amount: 1,
    ),
    DailyReward(
      day: 3,
      label: '200 coins',
      type: DailyRewardType.coins,
      amount: 200,
    ),
    DailyReward(
      day: 4,
      label: 'Power-up',
      type: DailyRewardType.powerUp,
      amount: 1,
    ),
    DailyReward(
      day: 5,
      label: '300 coins',
      type: DailyRewardType.coins,
      amount: 300,
    ),
    DailyReward(
      day: 6,
      label: 'Power-up',
      type: DailyRewardType.powerUp,
      amount: 1,
    ),
    DailyReward(
      day: 7,
      label: 'Rare bubble',
      type: DailyRewardType.rareBubble,
      amount: 1,
    ),
  ];

  DailyRewardState _state = const DailyRewardState(
    streakDay: 0,
    lastClaimDate: null,
  );

  DailyRewardState get state => _state;

  DailyReward get nextReward {
    final nextDay = (_state.streakDay % rewards.length) + 1;
    return rewards[nextDay - 1];
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _state = DailyRewardState(
      streakDay: prefs.getInt(_streakKey) ?? 0,
      lastClaimDate: prefs.getString(_lastClaimKey),
    );
  }

  bool canClaimToday() {
    final today = _todayKey();
    return _state.lastClaimDate != today;
  }

  Future<DailyReward?> claimToday() async {
    if (!canClaimToday()) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final todayDate = DateTime.now();
    final streak = _resolveNextStreakDay(todayDate);
    final reward = rewards[streak - 1];
    final today = _dateKey(todayDate);

    await prefs.setInt(_streakKey, streak);
    await prefs.setString(_lastClaimKey, today);

    _state = DailyRewardState(streakDay: streak, lastClaimDate: today);
    return reward;
  }

  int _resolveNextStreakDay(DateTime today) {
    final lastClaimDate = _state.lastClaimDate;
    if (lastClaimDate == null) {
      return 1;
    }

    final parsed = _parseDateKey(lastClaimDate);
    if (parsed == null) {
      return 1;
    }

    final difference = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(parsed.year, parsed.month, parsed.day));

    if (difference.inDays == 1) {
      final next = _state.streakDay + 1;
      return next > rewards.length ? 1 : next;
    }

    if (difference.inDays <= 0) {
      return _state.streakDay == 0 ? 1 : _state.streakDay;
    }

    return 1;
  }

  String _todayKey() => _dateKey(DateTime.now());

  String _dateKey(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  DateTime? _parseDateKey(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }
}
