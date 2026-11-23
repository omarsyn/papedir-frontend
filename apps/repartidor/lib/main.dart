import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await LocalNotificationsService.instance.inicializar();

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
    Future.microtask(() async {
      await ref.read(authProvider.notifier).checkSession();
      _configurarListenersRealtimeYFcm();
    });
  }

  void _configurarListenersRealtimeYFcm() {
    ref.read(socketServiceProvider).configurarNotificaciones(
      onCuentaAprobada: () async {
        await LocalNotificationsService.instance.mostrarCuentaAprobada();
        ref.read(authProvider.notifier).markAsApproved();
      },
      onPedidoDisponible: (data) async {
        final folio = (data['folio'] ?? data['pedidoId'] ?? 'Nuevo').toString();
        final tiendaMap = data['tienda'];
        final tienda = tiendaMap is Map<String, dynamic>
            ? (tiendaMap['nombre'] ?? 'Tienda PaPedir').toString()
            : (data['tiendaNombre'] ?? 'Tienda PaPedir').toString();
        final ganancia =
            ((data['costoEnvio'] ?? data['ganancia'] ?? 0) as num).toDouble();

        await LocalNotificationsService.instance.mostrarNuevoPedido(
          folio: folio,
          tienda: tienda,
          ganancia: ganancia,
        );
      },
    );

    ref.read(fcmServiceProvider).listenMessages(
      onForegroundMessage: (message) async {
        final tipo = (message.data['tipo'] ?? message.data['type'] ?? '')
            .toString()
            .toLowerCase();

        if (tipo.contains('aprobada')) {
          await LocalNotificationsService.instance.mostrarCuentaAprobada();
          ref.read(authProvider.notifier).markAsApproved();
          return;
        }

        if (tipo.contains('pedido')) {
          final folio = (message.data['folio'] ?? 'Nuevo').toString();
          final tienda =
              (message.data['tienda'] ?? 'Tienda PaPedir').toString();
          final ganancia =
              double.tryParse('${message.data['ganancia'] ?? 0}') ?? 0.0;

          await LocalNotificationsService.instance.mostrarNuevoPedido(
            folio: folio,
            tienda: tienda,
            ganancia: ganancia,
          );
          return;
        }

        if (tipo.contains('password') || tipo.contains('contrasena')) {
          await LocalNotificationsService.instance.mostrarPasswordActualizada();
        }
      },
      onNotificationTap: (message) {
        final router = ref.read(routerProvider);
        final ruta = message.data['ruta']?.toString();
        if (ruta != null && ruta.startsWith('/')) {
          router.go(ruta);
        }
      },
    );
  }

  Future<void> _conectarRealtime() async {
    final token = await ref.read(tokenStorageProvider).getAccessToken();
    if (token == null || token.isEmpty) return;

    final baseUrl = ref.read(dioProvider).options.baseUrl;
    ref.read(socketServiceProvider).connect(
          baseUrl: baseUrl,
          accessToken: token,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.usuario == null && next.usuario != null) {
        ref.read(fcmServiceProvider).registerDevice(AppTipo.repartidor);
        _conectarRealtime();
        if (!next.isPendingApproval && !next.isBanned) {
          LocalNotificationsService.instance.mostrarBienvenidaRepartidor();
        }
      } else if (previous?.usuario != null && next.usuario == null) {
        ref.read(socketServiceProvider).disconnect();
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
