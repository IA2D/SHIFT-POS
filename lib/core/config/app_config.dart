class AppConfig {
  const AppConfig({
    required this.environment,
    required this.api,
    required this.database,
    required this.network,
  });

  final String environment;
  final ApiConfig api;
  final DatabaseConfig database;
  final NetworkConfig network;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      environment: json['environment'] as String? ?? 'development',
      api: ApiConfig.fromJson(json['api'] as Map<String, dynamic>? ?? {}),
      database: DatabaseConfig.fromJson(
        json['database'] as Map<String, dynamic>? ?? {},
      ),
      network: NetworkConfig.fromJson(
        json['network'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class ApiConfig {
  const ApiConfig({
    required this.enabled,
    required this.baseUrl,
    required this.timeoutSeconds,
  });

  final bool enabled;
  final String baseUrl;
  final int timeoutSeconds;

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    return ApiConfig(
      enabled: json['enabled'] as bool? ?? false,
      baseUrl: json['baseUrl'] as String? ?? 'http://127.0.0.1:8080',
      timeoutSeconds: json['timeoutSeconds'] as int? ?? 20,
    );
  }
}

class DatabaseConfig {
  const DatabaseConfig({
    required this.enabled,
    required this.driver,
    required this.name,
  });

  final bool enabled;
  final String driver;
  final String name;

  factory DatabaseConfig.fromJson(Map<String, dynamic> json) {
    return DatabaseConfig(
      enabled: json['enabled'] as bool? ?? false,
      driver: json['driver'] as String? ?? 'sqlite',
      name: json['name'] as String? ?? 'shift_pos.sqlite',
    );
  }
}

class NetworkConfig {
  const NetworkConfig({
    required this.defaultMasterPort,
  });

  final int defaultMasterPort;

  factory NetworkConfig.fromJson(Map<String, dynamic> json) {
    return NetworkConfig(
      defaultMasterPort: json['defaultMasterPort'] as int? ?? 47831,
    );
  }
}
