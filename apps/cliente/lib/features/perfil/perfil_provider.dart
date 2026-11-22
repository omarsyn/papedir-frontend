import 'package:core/core.dart' show Tokens, authProvider;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/providers.dart';

/// Campos del formulario de perfil (se llenan con los datos actuales).
class PerfilCampos {
  PerfilCampos({required String nombre, required String telefono})
    : nombre = TextEditingController(text: nombre),
      telefono = TextEditingController(text: telefono);

  final form = GlobalKey<FormState>();
  final TextEditingController nombre;
  final TextEditingController telefono;

  void dispose() {
    nombre.dispose();
    telefono.dispose();
  }
}

final perfilCamposProvider = Provider.autoDispose<PerfilCampos>((ref) {
  final u = ref.read(authProvider).usuario;
  final c = PerfilCampos(nombre: u?.nombre ?? '', telefono: u?.telefono ?? '');
  ref.onDispose(c.dispose);
  return c;
});

/// Qué se está haciendo en la pantalla de perfil (para deshabilitar botones).
enum AccionPerfil { ninguna, guardando, password, eliminando }

class PerfilNotifier extends AutoDisposeNotifier<AccionPerfil> {
  @override
  AccionPerfil build() => AccionPerfil.ninguna;

  Future<T> _hacer<T>(AccionPerfil a, Future<T> Function() f) async {
    state = a;
    try {
      return await f();
    } finally {
      state = AccionPerfil.ninguna;
    }
  }

  /// PATCH /usuarios/me y recarga el usuario de la sesión.
  Future<void> guardar({required String nombre, required String telefono}) =>
      _hacer(AccionPerfil.guardando, () async {
        await conApiError(
          () => ref
              .read(dioProvider)
              .patch<void>(
                '/usuarios/me',
                data: {'nombre': nombre, 'telefono': telefono},
              ),
        );
        await ref.read(authProvider.notifier).checkSession();
      });

  /// PUT /usuarios/me/password. Cierra las otras sesiones y devuelve
  /// tokens nuevos para este teléfono.
  Future<void> cambiarPassword(String actual, String nueva) =>
      _hacer(AccionPerfil.password, () async {
        final r = await conApiError(
          () => ref
              .read(dioProvider)
              .put<Map<String, dynamic>>(
                '/usuarios/me/password',
                data: {'actual': actual, 'nueva': nueva},
              ),
        );
        final d = r.data ?? const {};
        await ref
            .read(tokenStorageProvider)
            .saveTokens(
              Tokens(
                accessToken: '${d['accessToken']}',
                refreshToken: '${d['refreshToken']}',
              ),
            );
      });

  /// DELETE /usuarios/me con la contraseña. Después cierra la sesión local.
  Future<void> eliminarCuenta(String password) =>
      _hacer(AccionPerfil.eliminando, () async {
        await conApiError(
          () => ref
              .read(dioProvider)
              .delete<void>('/usuarios/me', data: {'password': password}),
        );
        await ref.read(tokenStorageProvider).clear();
        await ref.read(authProvider.notifier).logout();
      });
}

final perfilProvider =
    NotifierProvider.autoDispose<PerfilNotifier, AccionPerfil>(
      PerfilNotifier.new,
    );
