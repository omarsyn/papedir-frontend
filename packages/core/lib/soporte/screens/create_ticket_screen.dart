import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../tickets_provider.dart';
import 'ticket_chat_screen.dart';

class CreateTicketScreen extends ConsumerStatefulWidget {
  final String? pedidoIdInicial;

  const CreateTicketScreen({super.key, this.pedidoIdInicial});

  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _asuntoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  late final TextEditingController _pedidoCtrl;

  @override
  void initState() {
    super.initState();
    _pedidoCtrl = TextEditingController(text: widget.pedidoIdInicial ?? '');
  }

  @override
  void dispose() {
    _asuntoCtrl.dispose();
    _descripcionCtrl.dispose();
    _pedidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    final ticket = await ref.read(ticketsProvider.notifier).crearTicket(
          asunto: _asuntoCtrl.text,
          descripcion: _descripcionCtrl.text,
          pedidoId: _pedidoCtrl.text,
        );

    if (!mounted) return;
    if (ticket != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TicketChatScreen(ticketId: ticket.id),
        ),
      );
    } else {
      final err = ref.read(ticketsProvider).mensajeError;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final creando = ref.watch(ticketsProvider).creando;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo ticket de soporte')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _asuntoCtrl,
              decoration: const InputDecoration(
                labelText: 'Asunto',
                hintText: 'Ej. Problema al entregar pedido',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 4)
                  ? 'Describe brevemente el asunto'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pedidoCtrl,
              decoration: const InputDecoration(
                labelText: 'ID de pedido relacionado (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descripcionCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Descripción detallada',
                hintText: 'Explica qué ocurrió para que soporte te ayude',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Agrega más detalle (mínimo 10 caracteres)'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: creando ? null : _enviar,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: creando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(creando ? 'Enviando...' : 'Crear ticket'),
            ),
          ],
        ),
      ),
    );
  }
}