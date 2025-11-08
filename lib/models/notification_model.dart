import 'package:flutter/material.dart';

class AppNotification {
  String? id;
  String userId;
  String? eventId;
  String? eventTitle;
  String type; // "event_approved", "event_declined", "event_reminder"
  String title;
  String message;
  DateTime? createdAt;
  bool isRead;
  bool isNew;

  AppNotification({
    this.id,
    required this.userId,
    this.eventId,
    this.eventTitle,
    required this.type,
    required this.title,
    required this.message,
    this.createdAt,
    this.isRead = false,
    this.isNew = true,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String?,
      userId: (json['userId'] ?? json['user_id']) as String,
      eventId: (json['eventId'] ?? json['event_id']) as String?,
      eventTitle: (json['eventTitle'] ?? json['event_title']) as String?,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      isRead: (json['isRead'] ?? json['is_read']) as bool? ?? false,
      isNew: (json['isNew'] ?? json['is_new']) as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      if (eventId != null) 'event_id': eventId,
      if (eventTitle != null) 'event_title': eventTitle,
      'type': type,
      'title': title,
      'message': message,
      // Don't include createdAt - let the database set it automatically
      'is_read': isRead,
      'is_new': isNew,
    };
  }

  bool get isEventStatusNotification => type == 'event_approved' || type == 'event_declined';
  bool get isEventReminderNotification => type == 'event_reminder';

  IconData get iconData {
    switch (type) {
      case 'event_approved':
        return Icons.check_circle;
      case 'event_declined':
        return Icons.cancel;
      case 'event_reminder':
        return Icons.event;
      default:
        return Icons.notifications;
    }
  }

  Color get backgroundColor {
    return const Color(0xFF3B82F6); // Info
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.tryParse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String get formattedTimestamp {
    final dt = createdAt;
    if (dt == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}


