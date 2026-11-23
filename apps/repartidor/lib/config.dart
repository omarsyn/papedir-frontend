class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:4010',
  );

  // URL base sin /api/v1 para la conexión Socket.IO (/realtime)
  static String get socketBaseUrl {
    if (apiUrl.endsWith('/api/v1')) {
      return apiUrl.substring(0, apiUrl.length - 7);
    }
    return apiUrl;
  }
}
