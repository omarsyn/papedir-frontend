import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: RepartidorApp()));
}

class RepartidorApp extends ConsumerStatefulWidget {
  const RepartidorApp({super.key});

  @override
  ConsumerState<RepartidorApp> createState() => _RepartidorAppState();
}

class _RepartidorAppState extends ConsumerState<RepartidorApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(authProvider.notifier).checkSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Registrar token FCM cada vez que el usuario inicie sesión
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.usuario == null && next.usuario != null) {
        ref.read(fcmServiceProvider).registerDevice(AppTipo.repartidor);
      }
    });

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'PaPedir Repartidor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
