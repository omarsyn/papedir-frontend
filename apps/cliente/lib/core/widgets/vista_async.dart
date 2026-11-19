import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_error.dart';

/// Muestra un AsyncValue: cargando, error con "Reintentar" o el contenido.
class VistaAsync<T> extends StatelessWidget {
  const VistaAsync({
    super.key,
    required this.valor,
    required this.onReintentar,
    required this.builder,
  });

  final AsyncValue<T> valor;
  final VoidCallback onReintentar;
  final Widget Function(T datos) builder;

  @override
  Widget build(BuildContext context) {
    return valor.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ApiError.from(error).message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onReintentar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Para RefreshIndicator: recarga sin propagar el error (la vista ya lo muestra).
Future<void> recargarSilencioso(Future<Object?> Function() refrescar) async {
  try {
    await refrescar();
  } catch (_) {
    // el error se muestra en la vista
  }
}
