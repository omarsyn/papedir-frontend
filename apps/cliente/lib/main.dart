import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/home_shell.dart';

void main() {
  runApp(const ProviderScope(child: PaPedirCliente()));
}

class PaPedirCliente extends ConsumerStatefulWidget {
  const PaPedirCliente({super.key});

  @override
  ConsumerState<PaPedirCliente> createState() => _PaPedirClienteState();
}

class _PaPedirClienteState extends ConsumerState<PaPedirCliente> {
  bool _restaurando = true;

  @override
  void initState() {
    super.initState();
    // Intenta recuperar la sesión guardada (tokens en almacenamiento seguro).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(sesionProvider.notifier).restaurar();
      } catch (_) {
        // Sin sesión: se mostrará el login.
      }
      if (!mounted) return;
      setState(() {
        _restaurando = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(sesionProvider);
    final Widget inicio;
    if (_restaurando) {
      inicio = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (usuario == null) {
      inicio = const LoginScreen();
    } else {
      inicio = const HomeShell();
    }
    return MaterialApp(
      // La llave reinicia la navegación al iniciar o cerrar sesión.
      key: ValueKey<bool>(usuario != null),
      title: 'PaPedir',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: inicio,
    );
  }
}
