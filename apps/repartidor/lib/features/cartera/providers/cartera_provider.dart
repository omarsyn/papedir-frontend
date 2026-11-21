import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart'; // Ajusta al nombre de tu paquete core

final carteraRepositoryProvider = Provider<CarteraRepository>((ref) {
  final dio = ref.watch(dioProvider); // Cliente Dio autenticado de core
  return CarteraRepository(dio);
});

final carteraProvider =
    AsyncNotifierProvider<CarteraNotifier, EstadoDeCuenta>(CarteraNotifier.new);

class CarteraNotifier extends AsyncNotifier<EstadoDeCuenta> {
  @override
  Future<EstadoDeCuenta> build() async {
    return ref.read(carteraRepositoryProvider).obtenerCartera(page: 1, limit: 20);
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(carteraRepositoryProvider).obtenerCartera(page: 1, limit: 20),
    );
  }

  Future<void> cargarMasMovimientos() async {
    final actual = state.valueOrNull;
    if (actual == null || actual.movimientos.length >= actual.total) return;

    final siguientePagina = actual.page + 1;
    final nuevoEstado = await ref
        .read(carteraRepositoryProvider)
        .obtenerCartera(page: siguientePagina, limit: actual.limit);

    state = AsyncData(
      EstadoDeCuenta(
        saldo: nuevoEstado.saldo,
        estado: nuevoEstado.estado,
        limiteDeudaRaw: nuevoEstado.limiteDeudaRaw,
        bloqueado: nuevoEstado.bloqueado,
        movimientos: [...actual.movimientos, ...nuevoEstado.movimientos],
        page: nuevoEstado.page,
        limit: nuevoEstado.limit,
        total: nuevoEstado.total,
      ),
    );
  }
}

/// Extrae el mensaje de error si la API responde 409 DEUDA_EXCEDIDA
String? extraerMensajeDeudaExcedida(Object error) {
  if (error is DioException && error.response?.statusCode == 409) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['error'] == 'DEUDA_EXCEDIDA') {
      return data['message'] as String? ??
          'Has excedido el límite de deuda permitido en tu cartera.';
    }
  }
  return null;
}