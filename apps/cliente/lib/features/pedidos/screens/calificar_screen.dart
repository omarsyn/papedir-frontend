import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/mensajes.dart';
import '../providers/calificar_provider.dart';

class CalificarScreen extends ConsumerWidget {
  const CalificarScreen({
    super.key,
    required this.pedidoId,
    required this.nombreTienda,
  });

  final String pedidoId;
  final String nombreTienda;

  Future<void> _enviar(BuildContext context, WidgetRef ref) async {
    final comentario = ref
        .read(comentarioControllerProvider(pedidoId))
        .text
        .trim();
    try {
      await ref.read(calificarProvider(pedidoId).notifier).enviar(comentario);
      if (!context.mounted) return;
      mostrarMensaje(context, '¡Gracias por tu calificación!');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(calificarProvider(pedidoId));
    final notifier = ref.read(calificarProvider(pedidoId).notifier);
    final comentario = ref.watch(comentarioControllerProvider(pedidoId));
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Calificar pedido')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(nombreTienda, style: tema.textTheme.titleMedium),
          const Text('¿Cómo estuvo la comida o los productos?'),
          _Estrellas(valor: estado.tienda, onCambio: notifier.estrellasTienda),
          const SizedBox(height: 16),
          Text('Repartidor', style: tema.textTheme.titleMedium),
          const Text('¿Cómo fue la entrega?'),
          _Estrellas(
            valor: estado.repartidor,
            onCambio: notifier.estrellasRepartidor,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: comentario,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comentario (opcional)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: estado.enviando ? null : () => _enviar(context, ref),
            child: estado.enviando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar calificación'),
          ),
        ],
      ),
    );
  }
}

class _Estrellas extends StatelessWidget {
  const _Estrellas({required this.valor, required this.onCambio});

  final int valor;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            iconSize: 36,
            color: Colors.amber,
            tooltip: '$i',
            icon: Icon(i <= valor ? Icons.star : Icons.star_border),
            onPressed: () => onCambio(i),
          ),
      ],
    );
  }
}
