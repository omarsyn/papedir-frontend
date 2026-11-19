import 'package:core/core.dart' show ApiException;
import 'package:dio/dio.dart';

/// Error listo para mostrar en pantalla (traduce ApiException de core).
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
    if (e is ApiException) return _desde(e);
    if (e is DioException) {
      final sinRespuesta = e.response == null;
      final esTimeout = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      if (sinRespuesta && esTimeout) {
        return ApiError('El servidor tardó en responder, intenta de nuevo');
      }
      return _desde(ApiException.fromDioException(e));
    }
    return ApiError('Ocurrió un error inesperado');
  }

  static ApiError _desde(ApiException e) => ApiError(
        e.message,
        codigo: e.error,
        statusCode: e.statusCode,
        detalles: {for (final d in e.detalles) d.campo: d.mensaje},
      );

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