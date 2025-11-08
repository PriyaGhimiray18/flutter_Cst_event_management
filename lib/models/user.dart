class User {
  final String id;
  String name;
  String email;
  String role; // "user" or "admin"
  String? profileImageUrl;
  DateTime? createdAt;
  DateTime? lastLoginAt;
  bool isActive;

  User({
    required this.id,
    required this.email,
    required this.name,
    String? role,
    this.profileImageUrl,
    this.createdAt,
    this.lastLoginAt,
    bool? isActive,
  }) : role = role ?? 'user', isActive = isActive ?? true;

  bool get isAdmin => role == 'admin';
  bool get isUser => role == 'user';

  void updateLastLogin() {
    lastLoginAt = DateTime.now();
  }

  factory User.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toUtc();
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toUtc();
      }
      return null;
    }

    return User(
      id: json['id'] as String? ?? json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      profileImageUrl: json['profile_image_url'] as String? ?? json['profileImageUrl'] as String?,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      lastLoginAt: parseDate(json['last_login_at'] ?? json['lastLoginAt']),
      isActive: (json['is_active'] as bool?) ?? (json['isActive'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (lastLoginAt != null) 'last_login_at': lastLoginAt!.toUtc().toIso8601String(),
      'is_active': isActive,
    };
  }
}
