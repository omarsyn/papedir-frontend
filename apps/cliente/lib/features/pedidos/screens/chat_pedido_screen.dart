import 'dart:async';

import 'package:core/core.dart' show authProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/providers.dart';
import '../../../core/tema.dart';
import '../../../core/widgets/mensajes.dart';

/// Mensaje del chat del pedido (cliente ↔ repartidor; soporte también puede).
class MensajePedido {
  const MensajePedido({
    required this.id,
    required this.autorId,
    required this.autorRol,
    required this.texto,
    this.creadoEn,
  });

  final String id;
  final String autorId;
  final String autorRol;
  final String texto;
  final DateTime? creadoEn;

  factory MensajePedido.fromJson(Map<String, dynamic> j) => MensajePedido(
    id: '${j['id']}',
    autorId: '${j['autorId'] ?? ''}',
    autorRol: '${j['autorRol'] ?? ''}',
    texto: '${j['texto'] ?? ''}',
    creadoEn: DateTime.tryParse('${j['creadoEn']}')?.toLocal(),
  );
}

String _hora(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Mensajes del pedido; se revisa cada 4 s mientras el chat está abierto.
final mensajesPedidoProvider = FutureProvider.autoDispose
    .family<List<MensajePedido>, String>((ref, pedidoId) async {
      final timer = Timer(const Duration(seconds: 4), ref.invalidateSelf);
      ref.onDispose(timer.cancel);
      final r = await conApiError(
        () => ref
            .read(dioProvider)
            .get<List<dynamic>>('/pedidos/$pedidoId/mensajes'),
      );
      return [
        for (final m in r.data ?? const [])
          MensajePedido.fromJson(Map<String, dynamic>.from(m as Map)),
      ];
    });

/// Caja de texto del chat (se libera al salir).
final cajaChatProvider = Provider.autoDispose<TextEditingController>((ref) {
  final c = TextEditingController();
  ref.onDispose(c.dispose);
  return c;
});

/// true mientras se envía un mensaje.
class EnviandoNotifier extends AutoDisposeNotifier<bool> {
  @override
  bool build() => false;

  Future<void> enviar(String pedidoId, String texto) async {
    state = true;
    try {
      await conApiError(
        () => ref
            .read(dioProvider)
            .post<void>('/pedidos/$pedidoId/mensajes', data: {'texto': texto}),
      );
      ref.invalidate(mensajesPedidoProvider(pedidoId));
    } finally {
      state = false;
    }
  }
}

final enviandoChatProvider =
    NotifierProvider.autoDispose<EnviandoNotifier, bool>(EnviandoNotifier.new);

class ChatPedidoScreen extends ConsumerWidget {
  const ChatPedidoScreen({
    super.key,
    required this.pedidoId,
    required this.titulo,
  });

  final String pedidoId;
  final String titulo;

  Future<void> _enviar(BuildContext context, WidgetRef ref) async {
    final caja = ref.read(cajaChatProvider);
    final texto = caja.text.trim();
    if (texto.isEmpty) return;
    try {
      await ref.read(enviandoChatProvider.notifier).enviar(pedidoId, texto);
      caja.clear();
    } on ApiError catch (e) {
      if (!context.mounted) return;
      mostrarMensaje(
        context,
        e.codigo == 'CHAT_CERRADO'
            ? 'El chat se cierra cuando el pedido ya no va en camino.'
            : e.message,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mensajes = ref.watch(mensajesPedidoProvider(pedidoId));
    final yo = ref.watch(authProvider).usuario?.id;
    final enviando = ref.watch(enviandoChatProvider);
    final caja = ref.watch(cajaChatProvider);
    final esquema = Theme.of(context).colorScheme;
    final lista = mensajes.valueOrNull ?? const <MensajePedido>[];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat con el repartidor'),
            Text(titulo, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: mensajes.isLoading && lista.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : lista.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Escríbele al repartidor, por ejemplo para darle '
                        'una referencia de tu casa.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(Disenio.margen),
                    itemCount: lista.length,
                    itemBuilder: (_, i) {
                      final m = lista[lista.length - 1 - i];
                      final mio = m.autorId == yo;
                      final rol = switch (m.autorRol) {
                        'repartidor' => 'Repartidor',
                        'soporte' || 'admin' => 'Soporte',
                        _ => null,
                      };
                      return Align(
                        alignment: mio
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 300),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: mio
                                ? esquema.primary
                                : esquema.surfaceContainerHighest,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(mio ? 18 : 4),
                              bottomRight: Radius.circular(mio ? 4 : 18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!mio && rol != null)
                                Text(
                                  rol,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: esquema.primary,
                                  ),
                                ),
                              Text(
                                m.texto,
                                style: TextStyle(
                                  color: mio
                                      ? esquema.onPrimary
                                      : esquema.onSurface,
                                ),
                              ),
                              if (m.creadoEn != null)
                                Text(
                                  _hora(m.creadoEn!),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: mio
                                        ? esquema.onPrimary.withValues(
                                            alpha: 0.7,
                                          )
                                        : esquema.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: caja,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _enviar(context, ref),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: enviando ? null : () => _enviar(context, ref),
                    icon: enviando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
