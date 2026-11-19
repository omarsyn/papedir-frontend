import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PerfilState {
  final String nombre;
  final String telefono;
  final String correo;
  final String vehiculo;
  final String placas;
  final bool cargando;
  final bool guardando;
  final String? mensajeError;

  const PerfilState({
    this.nombre = '',
    this.telefono = '',
    this.correo = '',
    this.vehiculo = '',
    this.placas = '',
    this.cargando = false,
    this.guardando = false,
    this.mensajeError,
  });

  PerfilState copyWith({
    String? nombre,
    String? telefono,
    String? correo,
    String? vehiculo,
    String? placas,
    bool? cargando,
    bool? guardando,
    String? mensajeError,
    bool limpiarError = false,
  }) {
    return PerfilState(
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      correo: correo ?? this.correo,
      vehiculo: vehiculo ?? this.vehiculo,
      placas: placas ?? this.placas,
      cargando: cargando ?? this.cargando,
      guardando: guardando ?? this.guardando,
      mensajeError: limpiarError ? null : (mensajeError ?? this.mensajeError),
    );
  }
}

class PerfilNotifier extends StateNotifier<PerfilState> {
  final Dio _dio;
  final Ref _ref;

  PerfilNotifier(this._dio, this._ref) : super(const PerfilState()) {
    final usuario = _ref.read(authProvider).usuario;
    if (usuario != null) {
      state = state.copyWith(nombre: usuario.nombre);
    }
    cargarPerfil();
  }

  Future<void> cargarPerfil() async {
    state = state.copyWith(cargando: true, limpiarError: true);
    try {
      final res = await _dio.get('/usuarios/me');
      final data = res.data as Map<String, dynamic>;
      final perfilRep = data['repartidor'] as Map<String, dynamic>? ??
          data['perfilRepartidor'] as Map<String, dynamic>? ??
          {};

      state = state.copyWith(
        nombre: (data['nombre'] ?? state.nombre).toString(),
        telefono: (data['telefono'] ?? '').toString(),
        correo: (data['email'] ?? data['correo'] ?? '').toString(),
        vehiculo:
            (perfilRep['tipoVehiculo'] ?? perfilRep['vehiculo'] ?? '').toString(),
        placas: (perfilRep['placas'] ?? '').toString(),
        cargando: false,
      );
    } on DioException catch (e) {
      final err = ApiException.fromDioException(e);
      state = state.copyWith(cargando: false, mensajeError: err.message);
    }
  }

  Future<bool> actualizarPerfil({
    required String nombre,
    required String telefono,
  }) async {
    state = state.copyWith(guardando: true, limpiarError: true);
    try {
      await _dio.patch(
        '/usuarios/me',
        data: {
          'nombre': nombre.trim(),
          'telefono': telefono.trim(),
        },
      );

      state = state.copyWith(
        nombre: nombre.trim(),
        telefono: telefono.trim(),
        guardando: false,
      );

      await _ref.read(authProvider.notifier).checkSession();
      return true;
    } on DioException catch (e) {
      final err = ApiException.fromDioException(e);
      state = state.copyWith(guardando: false, mensajeError: err.message);
      return false;
    }
  }
}

final perfilProvider =
    StateNotifierProvider.autoDispose<PerfilNotifier, PerfilState>((ref) {
  final dio = ref.watch(dioProvider);
  return PerfilNotifier(dio, ref);
});