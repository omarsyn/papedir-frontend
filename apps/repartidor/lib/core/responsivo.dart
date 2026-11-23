import 'package:core/core.dart' show ApiException;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Diseño responsivo (ACUERDOS §13): en pantallas anchas (tablet o
/// escritorio) el contenido se centra con un ancho máximo para que no se
/// estire; en el teléfono ocupa todo el ancho.
class AnchoMaximo extends StatelessWidget {
  const AnchoMaximo({super.key, required this.child, this.maxAncho = 640});

  final Widget child;
  final double maxAncho;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth <= maxAncho
          ? child
          : Center(
              child: SizedBox(width: maxAncho, child: child),
            ),
    );
  }
}

/// Texto legible de cualquier error (la API manda `message` en español).
String mensajeDeError(Object e) {
  if (e is DioException) return ApiException.fromDioException(e).message;
  return e.toString();
}
