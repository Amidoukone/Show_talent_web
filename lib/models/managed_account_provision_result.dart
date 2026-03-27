class ManagedAccountProvisionResult {
  final String uid;
  final String email;
  final String role;
  final bool existingUser;
  final String? passwordSetupLink;
  final String? emailVerificationLink;

  const ManagedAccountProvisionResult({
    required this.uid,
    required this.email,
    required this.role,
    required this.existingUser,
    this.passwordSetupLink,
    this.emailVerificationLink,
  });

  factory ManagedAccountProvisionResult.fromMap(Map<String, dynamic> map) {
    return ManagedAccountProvisionResult(
      uid: map['uid']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      existingUser: map['existingUser'] == true,
      passwordSetupLink: _readOptionalString(map['passwordSetupLink']),
      emailVerificationLink: _readOptionalString(map['emailVerificationLink']),
    );
  }

  static String? _readOptionalString(dynamic value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}
