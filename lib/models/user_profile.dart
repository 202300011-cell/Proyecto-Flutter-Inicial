class UserProfile {
  final int? id;
  final String name;
  final String email;
  final String password;
  final String accountType;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const UserProfile({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.accountType,
    required this.createdAt,
    this.lastLoginAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'accountType': accountType,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, Object?> map) {
    return UserProfile(
      id: map['id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      accountType: map['accountType'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastLoginAt: map['lastLoginAt'] == null
          ? null
          : DateTime.parse(map['lastLoginAt'] as String),
    );
  }
}
