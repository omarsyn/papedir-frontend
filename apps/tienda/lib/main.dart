import 'package:core/core.dart'
    show
        AppTipo,
        AuthState,
        LoginScreen,
        PendingReviewScreen,
        authProvider,
        dioProvider,
        fcmServiceProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_shell.dart';
import 'features/registro/screens/registro_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Sin Firebase la app sigue funcionando; solo se pierden las notificaciones.
  }
  runApp(const ProviderScope(child: PaPedirTienda()));
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

class PaPedirTienda extends ConsumerWidget {
  const PaPedirTienda({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Registra el token de notificaciones cada vez que se inicia sesión.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.usuario == null && next.usuario != null) {
        ref
            .read(fcmServiceProvider)
            .registerDevice(AppTipo.tienda)
            .catchError((Object _) {});
      }
    });

    final arranque = ref.watch(arranqueProvider);
    final auth = ref.watch(authProvider);
    final autenticado = auth.isAuthenticated;
    final pendiente = auth.isPendingApproval;

    final Widget inicio;
    if (arranque.isLoading) {
      inicio = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (!autenticado) {
      inicio = Builder(
        builder: (context) => LoginScreen(
          appTipo: AppTipo.tienda,
          tituloApp: 'PaPedir Tienda',
          onIrARegistro: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RegistroScreen()),
            );
          },
        ),
      );
    } else if (pendiente) {
      inicio = const PendingReviewScreen();
    } else {
      inicio = const HomeShell();
    }

    return MaterialApp(
      // La llave reinicia la navegación al entrar, salir o ser aprobado.
      key: ValueKey<String>('$autenticado|$pendiente'),
      title: 'PaPedir Tienda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE65100)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: inicio,
    );
  }
}
