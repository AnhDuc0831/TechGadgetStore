class UserProfile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? phone;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.phone,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['fullName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'customer',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'phone': phone,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? avatarUrl,
    String? phone,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      role: role,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
