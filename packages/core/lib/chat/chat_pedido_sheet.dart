import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../models/mensaje_pedido.dart';
import '../models/pedido.dart';
import 'chat_pedido_provider.dart';

/// Valida si el pedido cumple las reglas de la API para chatear:
/// no debe ser manual y debe estar entre `asignado` y `en_domicilio`.
bool pedidoPermiteChat(Pedido pedido) {
  if (pedido.origen.name == 'manual') return false;
  const estadosSinChat = {
    'pendiente',
    'confirmado',
    'preparando',
    'listo',
    'entregado',
    'cancelado',
    'rechazado',
  };
  return !estadosSinChat.contains(pedido.estado.name);
}

/// Abre el chat del pedido como modal bottom sheet desde cualquier pantalla.
Future<void> mostrarChatPedidoModal(
  BuildContext context, {
  required Pedido pedido,
  String? tituloContraparte,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: ChatPedidoView(
        pedidoId: pedido.id,
        folio: pedido.folio,
        tituloContraparte: tituloContraparte ?? pedido.destino.nombre,
        soloLecturaInicial: !pedidoPermiteChat(pedido),
        esModal: true,
      ),
    ),
  );
}

class ChatPedidoScreen extends StatelessWidget {
  final String pedidoId;
  final String folio;
  final String? tituloContraparte;
  final bool soloLectura;

  const ChatPedidoScreen({
    super.key,
    required this.pedidoId,
    required this.folio,
    this.tituloContraparte,
    this.soloLectura = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ChatPedidoView(
          pedidoId: pedidoId,
          folio: folio,
          tituloContraparte: tituloContraparte,
          soloLecturaInicial: soloLectura,
          esModal: false,
        ),
      ),
    );
  }
}

class ChatPedidoView extends ConsumerStatefulWidget {
  final String pedidoId;
  final String folio;
  final String? tituloContraparte;
  final bool soloLecturaInicial;
  final bool esModal;

  const ChatPedidoView({
    super.key,
    required this.pedidoId,
    required this.folio,
    this.tituloContraparte,
    this.soloLecturaInicial = false,
    this.esModal = false,
  });

  @override
  ConsumerState<ChatPedidoView> createState() => _ChatPedidoViewState();
}

class _ChatPedidoViewState extends ConsumerState<ChatPedidoView> {
  final _textoCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _textoCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _desplazarAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _enviar() async {
    final texto = _textoCtrl.text;
    if (texto.trim().isEmpty) return;

    final enviado = await ref
        .read(chatPedidoProvider(widget.pedidoId).notifier)
        .enviarMensaje(texto);

    if (enviado && mounted) {
      _textoCtrl.clear();
      _desplazarAlFinal();
    }
  }

  String _formatearHora(DateTime fecha) {
    final local = fecha.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(chatPedidoProvider(widget.pedidoId));
    final miUsuario = ref.watch(authProvider).usuario;
    final colors = Theme.of(context).colorScheme;
    final deshabilitado = widget.soloLecturaInicial || estado.chatCerrado;

    ref.listen<ChatPedidoState>(
      chatPedidoProvider(widget.pedidoId),
      (prev, next) {
        if ((prev?.mensajes.length ?? 0) < next.mensajes.length) {
          _desplazarAlFinal();
        }
      },
    );

    return Column(
      children: [
        // Encabezado
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              if (!widget.esModal)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              const Icon(Icons.chat_bubble_outline),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tituloContraparte ?? 'Chat del pedido',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Pedido ${widget.folio}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref
                    .read(chatPedidoProvider(widget.pedidoId).notifier)
                    .cargarMensajes(),
              ),
              if (widget.esModal)
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Aviso si el chat está cerrado
        if (deshabilitado)
          Container(
            width: double.infinity,
            color: colors.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'El chat solo está disponible mientras el repartidor lleva el pedido.',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),

        // Lista de mensajes
        Expanded(
          child: _construirListaMensajes(estado, miUsuario?.id, colors),
        ),

        // Error puntual
        if (estado.mensajeError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              estado.mensajeError!,
              style: TextStyle(color: colors.error, fontSize: 12),
            ),
          ),

        // Caja de texto
        Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textoCtrl,
                  enabled: !deshabilitado && !estado.enviando,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviar(),
                  decoration: InputDecoration(
                    hintText: deshabilitado
                        ? 'Chat finalizado'
                        : 'Escribe un mensaje...',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed:
                    (deshabilitado || estado.enviando) ? null : _enviar,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                child: estado.enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirListaMensajes(
    ChatPedidoState estado,
    String? miUsuarioId,
    ColorScheme colors,
  ) {
    if (estado.cargando && estado.mensajes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (estado.mensajes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aún no hay mensajes en este pedido.\nEnvía un mensaje para coordinar la entrega.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: estado.mensajes.length,
      itemBuilder: (context, index) {
        final msg = estado.mensajes[index];
        final esMio = miUsuarioId != null && msg.autorId == miUsuarioId;

        return Align(
          alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
            ),
            decoration: BoxDecoration(
              color: esMio ? colors.primary : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(esMio ? 16 : 4),
                bottomRight: Radius.circular(esMio ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!esMio) ...[
                  Text(
                    msg.etiquetaRol,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  msg.texto,
                  style: TextStyle(
                    color: esMio ? colors.onPrimary : colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatearHora(msg.creadoEn),
                  style: TextStyle(
                    fontSize: 10,
                    color: esMio
                        ? colors.onPrimary.withValues(alpha: 0.75)
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}