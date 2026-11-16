import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';

void main() => runApp(const ProviderScope(child: PaPedirCliente()));

class PaPedirCliente extends ConsumerWidget {
  const PaPedirCliente({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionProvider);
    return MaterialApp(
      title: 'PaPedir',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: usuario == null
          ? const LoginScreen()
          : Scaffold(
              appBar: AppBar(title: const Text('PaPedir')),
              body: Center(child: Text('Hola, ${usuario.nombre}')),
            ),
    );
  }
}
