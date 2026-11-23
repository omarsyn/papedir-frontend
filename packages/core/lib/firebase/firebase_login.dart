import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../auth/auth_provider.dart';
import '../models/enums.dart';

/// Proveedores de Firebase Authentication que usan las apps.
enum ProveedorFirebase { google, github }

/// Qué pasó al intentar entrar con Firebase.
sealed class ResultadoFirebase {
  const ResultadoFirebase();
}

/// Ya hay sesión de PaPedir (tokens guardados).
class SesionIniciada extends ResultadoFirebase {
  const SesionIniciada();
}

/// Primera vez: falta "Completa tu registro" (teléfono, términos y,
/// en la App Tienda, los datos de la tienda).
class RegistroRequerido extends ResultadoFirebase {
  const RegistroRequerido({this.nombre, this.email});

  final String? nombre;
  final String? email;
}

/// Cuenta de correo sin verificar: se mandó el correo de verificación.
class CorreoSinVerificar extends ResultadoFirebase {
  const CorreoSinVerificar(this.email);

  final String email;
}

/// El usuario cerró la ventana de Google o GitHub.
class LoginCancelado extends ResultadoFirebase {
  const LoginCancelado();
}

class ErrorFirebase extends ResultadoFirebase {
  const ErrorFirebase(this.mensaje, {this.codigo});

  final String mensaje;
  final String? codigo;
}

/// Login con Firebase (ACUERDOS §13): Google, GitHub o correo. Después
/// cambia el ID token de Firebase por la sesión de PaPedir con
/// `POST /auth/firebase`.
class FirebaseLogin {
  FirebaseLogin(this._ref);

  final Ref _ref;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  Dio get _dio => _ref.read(dioProvider);

  /// Entrar con Google o GitHub (ventana del proveedor).
  Future<ResultadoFirebase> conProveedor(
    ProveedorFirebase proveedor,
    AppTipo app,
  ) async {
    try {
      final AuthProvider p = switch (proveedor) {
        ProveedorFirebase.google =>
          GoogleAuthProvider()
            ..setCustomParameters({'prompt': 'select_account'}),
        ProveedorFirebase.github =>
          GithubAuthProvider()..addScope('user:email'),
      };
      await _auth.signInWithProvider(p);
    } on FirebaseAuthException catch (e) {
      if (_esCancelacion(e)) return const LoginCancelado();
      return ErrorFirebase(_mensaje(e), codigo: e.code);
    } catch (e) {
      return ErrorFirebase('No se pudo iniciar sesión: $e');
    }
    return _canjear(app);
  }

  /// Entrar con una cuenta de correo de Firebase.
  Future<ResultadoFirebase> conCorreo(
    String email,
    String password,
    AppTipo app,
  ) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final u = cred.user!;
      if (!u.emailVerified) {
        await u.sendEmailVerification();
        return CorreoSinVerificar(u.email ?? email);
      }
    } on FirebaseAuthException catch (e) {
      return ErrorFirebase(_mensaje(e), codigo: e.code);
    }
    return _canjear(app);
  }

  /// Crear una cuenta de correo en Firebase. Manda el correo de
  /// verificación; al verificarlo se entra con [conCorreo].
  Future<ResultadoFirebase> crearCuentaCorreo(
    String email,
    String password,
  ) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.sendEmailVerification();
      return CorreoSinVerificar(email.trim());
    } on FirebaseAuthException catch (e) {
      return ErrorFirebase(_mensaje(e), codigo: e.code);
    }
  }

  /// Botón "Reenviar" de la pantalla "Revisa tu correo".
  Future<void> reenviarVerificacion() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Al volver de verificar el correo: recarga y entra.
  Future<ResultadoFirebase> yaVerifique(AppTipo app) async {
    final u = _auth.currentUser;
    if (u == null) return const ErrorFirebase('Inicia sesión de nuevo');
    await u.reload();
    if (!(_auth.currentUser?.emailVerified ?? false)) {
      return CorreoSinVerificar(u.email ?? '');
    }
    return _canjear(app);
  }

  /// Recuperar contraseña de una cuenta de Firebase.
  Future<void> recuperarPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// Segunda llamada a /auth/firebase con los datos de "Completa tu registro".
  Future<ResultadoFirebase> completarRegistro(
    AppTipo app,
    Map<String, dynamic> registro,
  ) => _canjear(app, registro: registro);

  /// ID token reciente (para eliminar la cuenta).
  Future<String?> idToken() async => _auth.currentUser?.getIdToken(true);

  Future<void> cerrarSesion() async {
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  Future<ResultadoFirebase> _canjear(
    AppTipo app, {
    Map<String, dynamic>? registro,
  }) async {
    final u = _auth.currentUser;
    if (u == null) return const ErrorFirebase('Inicia sesión de nuevo');
    try {
      final idToken = await u.getIdToken(true);
      final r = await _dio.post<Map<String, dynamic>>(
        '/auth/firebase',
        data: {
          'idToken': idToken,
          'app': app.name,
          if (registro != null) 'registro': registro,
        },
      );
      await _ref
          .read(authProvider.notifier)
          .guardarSesionDesdeRespuesta(r.data!);
      return const SesionIniciada();
    } on DioException catch (e) {
      final err = ApiException.fromDioException(e);
      switch (err.error) {
        case 'REGISTRO_REQUERIDO':
          return RegistroRequerido(nombre: u.displayName, email: u.email);
        case 'CORREO_NO_VERIFICADO':
          await u.sendEmailVerification();
          return CorreoSinVerificar(u.email ?? '');
        default:
          // La cuenta de Firebase no sirve para esta app: no la dejamos abierta.
          if (registro == null) await cerrarSesion();
          return ErrorFirebase(err.message, codigo: err.error);
      }
    }
  }

  bool _esCancelacion(FirebaseAuthException e) =>
      e.code == 'web-context-canceled' ||
      e.code == 'canceled' ||
      e.code == 'user-cancelled' ||
      e.code == 'popup-closed-by-user';

  String _mensaje(FirebaseAuthException e) => switch (e.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Correo o contraseña incorrectos',
    'invalid-email' => 'El correo no es válido',
    'email-already-in-use' => 'Ese correo ya tiene una cuenta. Inicia sesión.',
    'weak-password' => 'La contraseña debe tener al menos 6 caracteres',
    'too-many-requests' => 'Demasiados intentos. Espera unos minutos.',
    'account-exists-with-different-credential' =>
      'Ese correo ya entra con otro método (Google, GitHub o correo).',
    'operation-not-allowed' =>
      'Este método de inicio de sesión no está activado en Firebase.',
    'network-request-failed' => 'Sin conexión a internet',
    _ => e.message ?? 'No se pudo iniciar sesión (${e.code})',
  };
}

final firebaseLoginProvider = Provider<FirebaseLogin>(FirebaseLogin.new);
