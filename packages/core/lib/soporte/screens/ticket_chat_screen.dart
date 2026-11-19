import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_provider.dart';
import '../tickets_provider.dart';

class TicketChatScreen extends ConsumerStatefulWidget {
  final String ticketId;

  const TicketChatScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends ConsumerState<TicketChatScreen> {
  final _textoCtrl = TextEditingController();

  @override
  void dispose() {
    _textoCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _textoCtrl.text;
    if (texto.trim().isEmpty) return;

    final ok = await ref
        .read(ticketChatProvider(widget.ticketId).notifier)
        .enviarMensaje(texto);
    if (ok && mounted) {
      _textoCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(ticketChatProvider(widget.ticketId));
    final miUsuarioId = ref.watch(authProvider).usuario?.id;
    final ticket = estado.ticket;
    final cerrado = ticket?.estado.name == 'cerrado';

    return Scaffold(
      appBar: AppBar(
        title: Text(ticket != null ? 'Ticket ${ticket.folio}' : 'Detalle ticket'),
      ),
      body: Column(
        children: [
          if (ticket != null)
            Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.asunto,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ticket.descripcion,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          Expanded(
            child: estado.cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: estado.mensajes.length,
                    itemBuilder: (context, index) {
                      final msg = estado.mensajes[index];
                      final esMio = msg.autorId == miUsuarioId;

                      return Align(
                        alignment: esMio
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: esMio
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!esMio)
                                Text(
                                  'Soporte',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              Text(
                                msg.texto,
                                style: TextStyle(
                                  color: esMio ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!cerrado)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textoCtrl,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _enviar(),
                        decoration: const InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: estado.enviando ? null : _enviar,
                      icon: const Icon(Icons.send),
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