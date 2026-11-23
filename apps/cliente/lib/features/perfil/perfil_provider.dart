import 'dart:io';

import 'package:core/core.dart'
    show Tokens, authProvider, firebaseLoginProvider, subirAvatar;
import 'package:image_picker/image_picker.dart';
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
enum AccionPerfil { ninguna, guardando, password, eliminando, foto }

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

  /// Elige una foto de la galería y la sube (Firebase Storage para cuentas
  /// de Firebase, `/uploads` para las de PaPedir). Devuelve false si el
  /// usuario no eligió ninguna.
  Future<bool> cambiarFoto() => _hacer(AccionPerfil.foto, () async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (foto == null) return false;
    await conApiError(
      () => subirAvatar(ref.read(dioProvider), File(foto.path)),
    );
    await ref.read(authProvider.notifier).checkSession();
    return true;
  });

  /// DELETE /usuarios/me con la contraseña o, en cuentas de Firebase
  /// (sin contraseña de PaPedir), con un ID token reciente.
  Future<void> eliminarCuenta(String password) =>
      _hacer(AccionPerfil.eliminando, () async {
        final Map<String, dynamic> datos = password.isNotEmpty
            ? {'password': password}
            : {'idToken': await ref.read(firebaseLoginProvider).idToken()};
        await conApiError(
          () => ref.read(dioProvider).delete<void>('/usuarios/me', data: datos),
        );
        await ref.read(tokenStorageProvider).clear();
        await ref.read(authProvider.notifier).logout();
      });
}

final perfilProvider =
    NotifierProvider.autoDispose<PerfilNotifier, AccionPerfil>(
      PerfilNotifier.new,
    );
