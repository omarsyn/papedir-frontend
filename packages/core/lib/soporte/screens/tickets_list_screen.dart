import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ticket.dart';
import '../tickets_provider.dart';
import 'create_ticket_screen.dart';
import 'ticket_chat_screen.dart';

class TicketsListScreen extends ConsumerWidget {
  const TicketsListScreen({super.key});

  String _etiquetaEstado(String raw) {
    switch (raw) {
      case 'abierto':
        return 'Abierto';
      case 'en_proceso':
      case 'enProceso':
        return 'En proceso';
      case 'resuelto':
        return 'Resuelto';
      case 'cerrado':
        return 'Cerrado';
      default:
        return raw;
    }
  }

  Color _colorEstado(String raw) {
    switch (raw) {
      case 'abierto':
        return Colors.orange;
      case 'en_proceso':
      case 'enProceso':
        return Colors.blue;
      case 'resuelto':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(ticketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Soporte y tickets'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo ticket'),
      ),
      body: _construirCuerpo(context, ref, estado),
    );
  }

  Widget _construirCuerpo(
    BuildContext context,
    WidgetRef ref,
    TicketsState estado,
  ) {
    if (estado.cargando && estado.tickets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (estado.mensajeError != null && estado.tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(estado.mensajeError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.read(ticketsProvider.notifier).cargarTickets(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (estado.tickets.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(ticketsProvider.notifier).cargarTickets(),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.support_agent_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('No tienes reportes o tickets registrados')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(ticketsProvider.notifier).cargarTickets(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        itemCount: estado.tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final Ticket ticket = estado.tickets[index];
          final rawEstado = ticket.estado.name;
          final color = _colorEstado(rawEstado);

          return Card(
            child: ListTile(
              title: Row(
                children: [
                  Text(
                    ticket.folio,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _etiquetaEstado(rawEstado),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  ticket.asunto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TicketChatScreen(ticketId: ticket.id),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}