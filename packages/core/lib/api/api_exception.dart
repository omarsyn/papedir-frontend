import 'package:dio/dio.dart';

class CampoError {
  final String campo;
  final String mensaje;

  const CampoError({required this.campo, required this.mensaje});

  factory CampoError.fromJson(Map<String, dynamic> json) => CampoError(
    campo: json['campo'] as String? ?? '',
    mensaje: json['mensaje'] as String? ?? '',
  );
}

class ApiException implements Exception {
  final int statusCode;
  final String error;
  final String message;
  final List<CampoError> detalles;

  const ApiException({
    required this.statusCode,
    required this.error,
    required this.message,
    this.detalles = const [],
  });

  factory ApiException.fromDioException(DioException e) {
    final response = e.response;
    final data = response?.data;

    if (data is Map<String, dynamic>) {
      final rawDetalles = data['detalles'] as List<dynamic>? ?? [];
      return ApiException(
        statusCode: data['statusCode'] as int? ?? response?.statusCode ?? 500,
        error: data['error'] as String? ?? 'ERROR_INTERNO',
        message: data['message'] as String? ?? 'Ocurrió un error inesperado',
        detalles: rawDetalles
            .whereType<Map<String, dynamic>>()
            .map(CampoError.fromJson)
            .toList(),
      );
    }

    return ApiException(
      statusCode: response?.statusCode ?? 0,
      error: 'ERROR_RED',
      message: 'No se pudo conectar con el servidor de PaPedir',
    );
  }

  @override
  String toString() => 'ApiException($statusCode, $error): $message';
}
