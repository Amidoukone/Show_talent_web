class AdminAccessResult {
  const AdminAccessResult._({
    required this.isAuthorized,
    required this.message,
    required this.grantedClaims,
  });

  const AdminAccessResult.authorized({
    required List<String> grantedClaims,
  }) : this._(
          isAuthorized: true,
          message: null,
          grantedClaims: grantedClaims,
        );

  const AdminAccessResult.denied(String message)
      : this._(
          isAuthorized: false,
          message: message,
          grantedClaims: const [],
        );

  final bool isAuthorized;
  final String? message;
  final List<String> grantedClaims;
}
