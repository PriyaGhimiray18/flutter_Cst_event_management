class EventModel {
  String? id;
  String title;
  String description;
  String location;
  String category; // e.g., Sports, Culture, Literature, Social Events
  String date; // ISO yyyy-MM-dd
  String time; // HH:mm (24h)
  String? imageUrl;
  String status; // pending/approved/declined
  String requesterId;
  String requesterName;
  String requesterEmail;
  bool isUrgent;

  EventModel({
    this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.category,
    required this.date,
    required this.time,
    this.imageUrl,
    this.status = 'pending',
    required this.requesterId,
    required this.requesterName,
    required this.requesterEmail,
    this.isUrgent = false,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      category: json['category'] as String,
      date: json['date'] as String,
      time: json['time'] as String,
      imageUrl: json['imageUrl'] as String?,
      status: json['status'] as String? ?? 'pending',
      requesterId: json['requesterId'] as String,
      requesterName: json['requesterName'] as String,
      requesterEmail: json['requesterEmail'] as String,
      isUrgent: json['isUrgent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'category': category,
      'date': date,
      'time': time,
      'imageUrl': imageUrl,
      'status': status,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requesterEmail': requesterEmail,
      'isUrgent': isUrgent,
    };
  }
}


