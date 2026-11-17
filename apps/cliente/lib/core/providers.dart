import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'token_store.dart';

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(const FlutterSecureStorage()),
);

/// Cuenta las veces que la sesión expiró (el refresh falló).
/// La sesión escucha este contador y se cierra sola.
class ContadorExpiracion extends Notifier<int> {
  @override
  int build() => 0;

  void incrementar() {
    state = state + 1;
  }
}

final expiracionProvider =
    NotifierProvider<ContadorExpiracion, int>(ContadorExpiracion.new);

final dioProvider = Provider<Dio>((ref) {
  return crearDio(
    tokens: ref.read(tokenStoreProvider),
    onSesionExpirada: () => ref.read(expiracionProvider.notifier).incrementar(),
  );
});
