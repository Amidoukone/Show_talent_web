class AdminActionResponse {
  const AdminActionResponse({
    required this.success,
    required this.code,
    required this.message,
    this.retriable = false,
    this.data,
  });

  final bool success;
  final String code;
  final String message;
  final bool retriable;
  final Map<String, dynamic>? data;

  factory AdminActionResponse.fromMap(Map<String, dynamic>? map) {
    final payload = map ?? const <String, dynamic>{};
    final rawData = payload['data'];
    return AdminActionResponse(
      success: payload['success'] == true,
      code: payload['code']?.toString() ?? 'unknown',
      message: payload['message']?.toString() ?? '',
      retriable: payload['retriable'] == true,
      data: rawData is Map<String, dynamic>
          ? rawData
          : rawData is Map
              ? Map<String, dynamic>.from(rawData)
              : null,
    );
  }

  factory AdminActionResponse.failure({
    required String message,
    String code = 'action_failed',
    bool retriable = false,
  }) {
    return AdminActionResponse(
      success: false,
      code: code,
      message: message,
      retriable: retriable,
    );
  }
}
