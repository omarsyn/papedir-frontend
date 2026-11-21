import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/error_codes.dart' as errores;
import 'package:local_auth/local_auth.dart';

/// Pide huella, rostro o el PIN del teléfono antes de una acción sensible.
class Biometria {
  final _auth = LocalAuthentication();

  /// true si el usuario se identificó. Si el teléfono no tiene ningún
  /// bloqueo configurado, deja pasar (no hay con qué verificar).
  Future<bool> confirmar(String motivo) async {
    try {
      if (!await _auth.isDeviceSupported()) return true;
      return await _auth.authenticate(
        localizedReason: motivo,
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on PlatformException catch (e) {
      return e.code == errores.notAvailable ||
          e.code == errores.notEnrolled ||
          e.code == errores.passcodeNotSet;
    }
  }
}

final biometriaProvider = Provider<Biometria>((ref) => Biometria());
