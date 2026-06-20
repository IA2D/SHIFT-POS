abstract interface class ApiClient {
  Future<ApiResponse> get(String path);

  Future<ApiResponse> post(
    String path, {
    Map<String, Object?> body = const {},
  });
}

class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final Map<String, Object?> body;

  bool get ok => statusCode >= 200 && statusCode < 300;
}
