import 'package:flutter/material.dart';

class UnreadCounterService extends ChangeNotifier {
  static final UnreadCounterService _instance =
      UnreadCounterService._internal();

  factory UnreadCounterService() => _instance;

  UnreadCounterService._internal();

  int _totalUnreadCount = 0;

  int get totalUnreadCount => _totalUnreadCount;

  void updateTotalUnreadCount(int count) {
    if (_totalUnreadCount != count) {
      _totalUnreadCount = count;
      notifyListeners();
    }
  }

  void incrementUnread(String chatId) {
    _totalUnreadCount++;
    notifyListeners();
  }

  void resetForChat(String chatId, int previousUnreadCount) {
    _totalUnreadCount = _totalUnreadCount - previousUnreadCount;
    if (_totalUnreadCount < 0) _totalUnreadCount = 0;
    notifyListeners();
  }
}
