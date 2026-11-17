import 'package:dio/dio.dart';

/// Error con el formato estándar de la API:
/// { statusCode, error, message, detalles: [{ campo, mensaje }] }
class ApiError implements Exception {
  ApiError(
    this.message, {
    this.codigo,
    this.statusCode,
    this.detalles = const {},
  });

  final String message;

  /// Código estable de la API (ej. PEDIDO_MINIMO, FUERA_DE_COBERTURA).
  final String? codigo;
  final int? statusCode;

  /// Errores por campo (campo -> mensaje), solo en validación (400).
  final Map<String, String> detalles;

  factory ApiError.from(Object e) {
    if (e is ApiError) return e;
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final det = <String, String>{};
        final lista = data['detalles'];
        if (lista is List) {
          for (final d in lista) {
            if (d is Map) {
              det['${d['campo']}'] = '${d['mensaje']}';
            }
          }
        }
        return ApiError(
          '${data['message'] ?? 'Error del servidor'}',
          codigo: data['error'] as String?,
          statusCode: e.response?.statusCode,
          detalles: det,
        );
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return ApiError('El servidor tardó en responder, intenta de nuevo');
      }
      return ApiError('No se pudo conectar con el servidor');
    }
    return ApiError('Ocurrió un error inesperado');
  }

  @override
  String toString() => message;
}

/// Ejecuta [accion] y convierte cualquier fallo en un [ApiError].
Future<T> conApiError<T>(Future<T> Function() accion) async {
  try {
    return await accion();
  } catch (e) {
    throw ApiError.from(e);
  }
}
