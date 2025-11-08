class AppNotification {
  String? id;
  final String userId;
  final String eventId;
  final String eventTitle;
  final String type;
  final String title;
  final String message;
  String? createdAt;
  bool isRead;
  bool isNew;

  AppNotification({
    this.id,
    required this.userId,
    required this.eventId,
    required this.eventTitle,
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
      userId: json['user_id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      eventTitle: json['event_title'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      isNew: json['is_new'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'event_id': eventId,
      'event_title': eventTitle,
      'type': type,
      'title': title,
      'message': message,
      if (createdAt != null) 'created_at': createdAt,
      'is_read': isRead,
      'is_new': isNew,
    };
  }
}
