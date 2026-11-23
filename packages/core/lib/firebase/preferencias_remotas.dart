import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Usuario de Firebase Authentication (null si la sesión no es de Firebase,
/// por ejemplo con las cuentas de prueba de PaPedir).
final usuarioFirebaseProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Preferencias del usuario en Firestore (ACUERDOS §13):
///
///   usuarios/{uid}
///     tema: "sistema" | "claro" | "oscuro"
///     fuente: "normal" | "grande"
///     onboardingVisto: true
///     temasFCM: ["promociones", "novedades"]
///     notificaciones: { pedidos, promociones, chat }
///
/// Se escucha en tiempo real: si cambia en un teléfono, se ve en el otro.
/// Firestore guarda copia local, así que funciona sin internet.
/// Aquí nunca van datos del negocio.
final preferenciasRemotasProvider = StreamProvider<Map<String, dynamic>?>((
  ref,
) {
  final u = ref.watch(usuarioFirebaseProvider).valueOrNull;
  if (u == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('usuarios')
      .doc(u.uid)
      .snapshots()
      .map((d) => d.data());
});

/// Guarda (mezclando) en el documento del usuario. Sin sesión de Firebase
/// no hace nada: la app ya lo guardó en el teléfono.
Future<void> guardarPreferenciasRemotas(Map<String, dynamic> datos) async {
  try {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(u.uid)
        .set(datos, SetOptions(merge: true));
  } catch (_) {
    // Sin Firebase configurado (o en pruebas): queda solo en el teléfono.
  }
}
