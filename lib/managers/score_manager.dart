import 'package:flutter/foundation.dart';

class ScoreManager extends ChangeNotifier {
  int _score = 0;
  int get score => _score;

  void increment() {
    _score++;
    notifyListeners();
  }

  void reset() {
    _score = 0;
    notifyListeners();
  }
}
