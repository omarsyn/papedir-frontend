import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Sube la foto de perfil y la guarda en PaPedir (`PATCH /usuarios/me`).
///
/// - Cuentas de Firebase (correo): Firebase Storage en `usuarios/{uid}/avatar.jpg` (reglas de Victor).
/// - Cuentas de PaPedir (las de prueba): `POST /uploads` con `tipo = perfil`.
///
/// Solo se llama si `usuario.puedeCambiarFoto` es true; las cuentas de
/// Google o GitHub usan la foto del proveedor. Devuelve la URL nueva.
Future<String> subirAvatar(Dio dio, File archivo) async {
  final usuario = FirebaseAuth.instance.currentUser;
  final String url;
  if (usuario != null) {
    final ref = FirebaseStorage.instance.ref(
      'usuarios/${usuario.uid}/avatar.jpg',
    );
    await ref.putFile(archivo, SettableMetadata(contentType: 'image/jpeg'));
    url = await ref.getDownloadURL();
  } else {
    final r = await dio.post<Map<String, dynamic>>(
      '/uploads',
      data: FormData.fromMap({
        'tipo': 'perfil',
        'archivo': await MultipartFile.fromFile(
          archivo.path,
          filename: 'avatar.jpg',
        ),
      }),
    );
    url = '${r.data?['url']}';
  }
  await dio.patch<void>('/usuarios/me', data: {'fotoUrl': url});
  return url;
}
