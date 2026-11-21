import 'package:dio/dio.dart';
import '../models/cartera_models.dart';

class CarteraRepository {
  final Dio _dio;

  CarteraRepository(this._dio);

  Future<EstadoDeCuenta> obtenerCartera({int page = 1, int limit = 20}) async {
    final response = await _dio.get(
      '/cartera',
      queryParameters: {'page': page, 'limit': limit},
    );
    return EstadoDeCuenta.fromJson(response.data as Map<String, dynamic>);
  }
}