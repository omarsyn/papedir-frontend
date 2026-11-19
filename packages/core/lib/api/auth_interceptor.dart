import 'package:dio/dio.dart';
import '../auth/token_storage.dart';
import '../models/usuario.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final TokenStorage tokenStorage;
  final void Function()? onSessionExpired;

  AuthInterceptor({
    required this.dio,
    required this.tokenStorage,
    this.onSessionExpired,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['_retried'] == true;
    final isRefreshEndpoint = err.requestOptions.path.contains('/auth/refresh');

    if (isUnauthorized && !alreadyRetried && !isRefreshEndpoint) {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          // Instancia limpia para evitar ciclos en el interceptor
          final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
          final res = await refreshDio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          final newTokens = Tokens.fromJson(res.data as Map<String, dynamic>);
          await tokenStorage.saveTokens(newTokens);

          final retryOptions = err.requestOptions;
          retryOptions.extra['_retried'] = true;
          retryOptions.headers['Authorization'] =
              'Bearer ${newTokens.accessToken}';

          final clonedResponse = await dio.fetch(retryOptions);
          return handler.resolve(clonedResponse);
        } catch (_) {
          await tokenStorage.clear();
          onSessionExpired?.call();
        }
      } else {
        await tokenStorage.clear();
        onSessionExpired?.call();
      }
    }

    handler.next(err);
  }
}
