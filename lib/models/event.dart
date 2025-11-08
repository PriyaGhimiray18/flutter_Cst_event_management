class Event {
  String? id;
  final String title;
  final String category;
  final String date;
  final String time;
  final String location;
  final String description;
  String imageUrl;
  String status;
  String requesterId;
  String requesterName;
  String requesterEmail;
  String? createdAt;
  String? updatedAt;
  bool isInterested;
  bool isSaved;
  int attendees;
  bool isUrgent;

  Event({
    this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.time,
    required this.location,
    required this.description,
    this.imageUrl = '',
    this.status = 'pending',
    this.requesterId = '',
    this.requesterName = '',
    this.requesterEmail = '',
    this.createdAt,
    this.updatedAt,
    this.isInterested = false,
    this.isSaved = false,
    this.attendees = 0,
    this.isUrgent = false,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      requesterId: json['requester_id'] as String? ?? '',
      requesterName: json['requester_name'] as String? ?? '',
      requesterEmail: json['requester_email'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      isInterested: (json['is_interested'] as bool?) ?? false,
      // Support both snake_case and camelCase for saved flag
      isSaved: (json['is_saved'] as bool?) ?? (json['isSaved'] as bool?) ?? false,
      attendees: json['attendees'] as int? ?? 0,
      isUrgent: json['is_urgent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'category': category,
      'date': date,
      'time': time,
      'location': location,
      'description': description,
      'image_url': imageUrl,
      'status': status,
      'requester_id': requesterId,
      'requester_name': requesterName,
      'requester_email': requesterEmail,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      'is_interested': isInterested,
      'is_saved': isSaved,
      'is_urgent': isUrgent,
    };
  }

  Event copyWith({
    String? id,
    String? title,
    String? category,
    String? date,
    String? time,
    String? location,
    String? description,
    String? imageUrl,
    String? status,
    String? requesterId,
    String? requesterName,
    String? requesterEmail,
    String? createdAt,
    String? updatedAt,
    bool? isInterested,
    bool? isSaved,
    int? attendees,
    bool? isUrgent,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      requesterEmail: requesterEmail ?? this.requesterEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isInterested: isInterested ?? this.isInterested,
      isSaved: isSaved ?? this.isSaved,
      attendees: attendees ?? this.attendees,
      isUrgent: isUrgent ?? this.isUrgent,
    );
  }

  // Helper methods aligned with Java model
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDeclined => status == 'declined';
}
