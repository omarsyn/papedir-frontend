import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_provider.dart';

class PendingReviewScreen extends ConsumerWidget {
  const PendingReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PaPedir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top_rounded, size: 72),
              const SizedBox(height: 24),
              Text(
                'Tu cuenta está en revisión',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Hola ${usuario?.nombre ?? ''}, el equipo de soporte está validando tus datos. '
                'En cuanto seas aprobado podrás conectarte y recibir pedidos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).checkSession(),
                icon: const Icon(Icons.refresh),
                label: const Text('Verificar estado'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
