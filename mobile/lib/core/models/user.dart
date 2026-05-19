// lib/core/models/user.dart

class AppUser {
  final String id;
  final String username;
  final String nickname;
  final String email;
  final String phone;
  final List<String> roles;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.email,
    required this.phone,
    required this.roles,
    this.avatarUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['_id'] ?? json['id'] ?? '') as String,
        username: (json['username'] ?? '') as String,
        nickname: (json['nickname'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        phone: (json['phone'] ?? '') as String,
        roles: ((json['roles'] as List?)?.cast<String>()) ?? const ['customer'],
        avatarUrl: json['avatarUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'username': username,
        'nickname': nickname,
        'email': email,
        'phone': phone,
        'roles': roles,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };
}
