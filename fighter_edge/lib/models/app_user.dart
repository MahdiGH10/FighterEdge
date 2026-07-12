import '../billing/subscription.dart';

/// Provider-agnostic domain user. Firebase/Supabase/etc. map into this shape
/// so the rest of the app never depends on a specific auth SDK.
class AppUser {
  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;
  final Plan plan;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.plan,
    required this.createdAt,
    this.emailVerified = false,
  });

  bool get isPro => plan == Plan.pro;

  AppUser copyWith({
    String? displayName,
    bool? emailVerified,
    Plan? plan,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      emailVerified: emailVerified ?? this.emailVerified,
      plan: plan ?? this.plan,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'emailVerified': emailVerified,
        'plan': plan.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: (json['displayName'] as String?) ?? '',
        emailVerified: (json['emailVerified'] as bool?) ?? false,
        plan: Plan.values.firstWhere(
          (p) => p.name == json['plan'],
          orElse: () => Plan.free,
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
