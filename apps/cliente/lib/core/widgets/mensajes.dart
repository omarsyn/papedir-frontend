import 'package:flutter/material.dart';

import '../api_error.dart';

/// Muestra el mensaje de un error de la API en un SnackBar.
void mostrarError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(ApiError.from(error).message)));
}

void mostrarMensaje(BuildContext context, String texto) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
}
