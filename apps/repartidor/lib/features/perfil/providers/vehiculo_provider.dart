import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

final vehiculoRepartidorProvider =
    AsyncNotifierProvider<VehiculoNotifier, Vehiculo?>(VehiculoNotifier.new);

class VehiculoNotifier extends AsyncNotifier<Vehiculo?> {
  @override
  Future<Vehiculo?> build() async {
    final dio = ref.watch(dioProvider);
    final res = await dio.get('/repartidor/vehiculo');
    // OpenAPI: 204 si aún no registra su vehículo
    if (res.statusCode == 204 || res.data == null || res.data == '') {
      return null;
    }
    return Vehiculo.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> registrarVehiculo(Vehiculo vehiculo) async {
    final dio = ref.read(dioProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await dio.put('/repartidor/vehiculo', data: vehiculo.toJson());
      return Vehiculo.fromJson(res.data as Map<String, dynamic>);
    });
  }
}