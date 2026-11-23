import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';

/// Explicación que acompaña al código en todas partes.
const _ayuda =
    'Compártelo con quien recibe (por WhatsApp o llamada). El repartidor '
    'se lo pedirá al entregar.';

/// Diálogo que aparece al crear un pedido manual con su código de entrega.
Future<void> mostrarCodigoEntrega(BuildContext context, Pedido pedido) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_outline, size: 36),
        title: Text('Pedido ${pedido.folio} creado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Código de entrega'),
            const SizedBox(height: 8),
            CodigoEntregaManual(codigo: pedido.codigoEntrega!),
            const SizedBox(height: 12),
            Text(
              '$_ayuda Destinatario: ${pedido.clienteNombre}.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Listo'),
          ),
        ],
      ),
    );

/// El código en grande con botón para copiarlo.
class CodigoEntregaManual extends StatelessWidget {
  const CodigoEntregaManual({
    super.key,
    required this.codigo,
    this.compacto = false,
  });

  final String codigo;

  /// En la tarjeta del pedido: una línea con el código y el botón de copiar.
  final bool compacto;

  void _copiar(BuildContext context) {
    Clipboard.setData(ClipboardData(text: codigo));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Código copiado')));
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    if (compacto) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: esquema.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline,
              size: 18,
              color: esquema.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(color: esquema.onPrimaryContainer),
                  children: [
                    const TextSpan(text: 'Código de entrega: '),
                    TextSpan(
                      text: codigo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copiar código',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => _copiar(context),
            ),
          ],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          codigo,
          style: texto.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
            color: esquema.primary,
          ),
        ),
        IconButton(
          tooltip: 'Copiar código',
          icon: const Icon(Icons.copy),
          onPressed: () => _copiar(context),
        ),
      ],
    );
  }
}
