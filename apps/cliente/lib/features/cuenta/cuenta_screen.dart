import 'package:core/core.dart' show authProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../carrito/providers/carrito_provider.dart';
import '../direcciones/providers/direccion_activa_provider.dart';
import '../direcciones/screens/direcciones_screen.dart';

class CuentaScreen extends ConsumerWidget {
  const CuentaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(usuario?.nombre ?? ''),
            subtitle: Text(
              [usuario?.email, usuario?.telefono]
                  .whereType<String>()
                  .where((s) => s.isNotEmpty)
                  .join('\n'),
            ),
            isThreeLine: (usuario?.telefono ?? '').isNotEmpty,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Mis direcciones'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DireccionesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              // Se limpia el estado local antes de cerrar sesión.
              ref.invalidate(carritoProvider);
              ref.invalidate(direccionActivaProvider);
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}