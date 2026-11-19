import 'package:core/core.dart'
    show
        AppTipo,
        AuthState,
        LoginScreen,
        authProvider,
        dioProvider,
        fcmServiceProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/screens/register_screen.dart';
import 'features/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Sin Firebase la app sigue funcionando; solo se pierden las notificaciones.
  }
  runApp(const ProviderScope(child: PaPedirCliente()));
}

/// Ajusta el cliente HTTP y recupera la sesión guardada (si existe).
final arranqueProvider = FutureProvider<void>((ref) async {
  await Future<void>.delayed(Duration.zero);
  final dio = ref.read(dioProvider);
  // Render (plan gratis) puede tardar hasta ~1 min en despertar.
  dio.options.connectTimeout = const Duration(seconds: 60);
  dio.options.receiveTimeout = const Duration(seconds: 60);
  await ref.read(authProvider.notifier).checkSession();
});

class PaPedirCliente extends ConsumerWidget {
  const PaPedirCliente({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Registra el token de notificaciones cada vez que se inicia sesión.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.usuario == null && next.usuario != null) {
        ref
            .read(fcmServiceProvider)
            .registerDevice(AppTipo.cliente)
            .catchError((Object _) {});
      }
    });

    final arranque = ref.watch(arranqueProvider);
    final autenticado = ref.watch(authProvider).isAuthenticated;

    final Widget inicio;
    if (arranque.isLoading) {
      inicio = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (!autenticado) {
      inicio = Builder(
        builder: (context) => LoginScreen(
          appTipo: AppTipo.cliente,
          tituloApp: 'PaPedir',
          onIrARegistro: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
            );
          },
        ),
      );
    } else {
      inicio = const HomeShell();
    }

    return MaterialApp(
      // La llave reinicia la navegación al iniciar o cerrar sesión.
      key: ValueKey<bool>(autenticado),
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