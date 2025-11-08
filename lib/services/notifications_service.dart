import 'dart:async';
import '../models/notification_model.dart';

abstract class NotificationsService {
  Future<String?> getCurrentUserIdPublic();
  Future<List<AppNotification>> getUserNotifications(String userId);
  Future<void> markNotificationAsRead(String id);
  Future<void> markAllNotificationsAsRead();
  Future<void> deleteNotification(String id);
}

