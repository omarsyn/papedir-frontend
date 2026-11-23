import 'package:core/core.dart'
    show
        AppTipo,
        AuthState,
        LoginScreen,
        PendingReviewScreen,
        authProvider,
        dioProvider,
        preferenciasRemotasProvider,
        fcmServiceProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/preferencias.dart';
import 'core/tema.dart';
import 'core/temas_fcm.dart';
import 'core/tienda_activa.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/recuperar/recuperar_screen.dart';
import 'features/registro/screens/registro_screen.dart';
import 'features/terminos/terminos_pendientes_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Sin Firebase la app sigue funcionando; solo se pierden las notificaciones.
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const PaPedirTienda(),
    ),
  );
}

const _bienvenida = [
  PaginaOnboarding(
    icono: Icons.storefront,
    titulo: 'Tu negocio en PaPedir',
    texto: 'Registra tu tienda y recibe pedidos de clientes cercanos.',
  ),
  PaginaOnboarding(
    icono: Icons.restaurant_menu,
    titulo: 'Arma tu menú',
    texto: 'Agrega categorías y productos con foto, y marca lo que se agote.',
  ),
  PaginaOnboarding(
    icono: Icons.notifications_active_outlined,
    titulo: 'Atiende a tiempo',
    texto:
        'Acepta cada pedido en menos de 5 minutos y márcalo listo para el repartidor.',
  ),
];

/// Diseño de la app (ver core/tema.dart). El color de la marca no cambia.
ThemeData _tema(Brightness brillo) =>
    construirTema(const Color(0xFFE65100), brillo);

/// Ajusta el cliente HTTP y recupera la sesión guardada (si existe).
final arranqueProvider = FutureProvider<void>((ref) async {
  await Future<void>.delayed(Duration.zero);
  final dio = ref.read(dioProvider);
  // Render (plan gratis) puede tardar hasta ~1 min en despertar.
  dio.options.connectTimeout = const Duration(seconds: 60);
  dio.options.receiveTimeout = const Duration(seconds: 60);
  // Cada petición lleva X-Tienda-Id con la tienda elegida en "Mis tiendas".
  dio.interceptors.add(interceptorTiendaActiva(ref));
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
        // Temas de Cloud Messaging que se envían desde la consola de Firebase.
        suscribirTemas(const ['novedades', 'tiendas']);
      }
    });

    // Preferencias en Firestore: si cambian en otro teléfono, se aplican aquí.
    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      preferenciasRemotasProvider,
      (_, siguiente) => aplicarPreferenciasRemotas(ref, siguiente.valueOrNull),
    );

    final arranque = ref.watch(arranqueProvider);
    final auth = ref.watch(authProvider);
    final autenticado = auth.isAuthenticated;
    final pendiente = auth.isPendingApproval;

    final onboardingVisto = ref.watch(onboardingVistoProvider);

    final Widget inicio;
    if (!onboardingVisto) {
      inicio = const OnboardingScreen(paginas: _bienvenida);
    } else if (arranque.isLoading) {
      inicio = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (!autenticado) {
      inicio = Builder(
        builder: (context) => LoginScreen(
          appTipo: AppTipo.tienda,
          logo: Image.asset('assets/logo.png', height: 110),
          tituloApp: 'PaPedir Tienda',
          onIrARegistro: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RegistroScreen()),
            );
          },
          // Primera vez con Google/GitHub/correo: pide los datos de la tienda.
          onRegistroFirebase: (ctx, datos) => Navigator.of(ctx).push(
            MaterialPageRoute<void>(
              builder: (_) => RegistroScreen(firebase: datos),
            ),
          ),
          onOlvidePassword: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RecuperarScreen(app: AppTipo.tienda),
              ),
            );
          },
        ),
      );
    } else if (ref.watch(authProvider).usuario?.terminosPendientes ?? false) {
      // Hay términos nuevos: se aceptan antes de entrar.
      inicio = const TerminosPendientesScreen();
    } else if (pendiente) {
      inicio = const PendingReviewScreen();
    } else {
      inicio = const HomeShell();
    }

    return MaterialApp(
      // La llave reinicia la navegación al entrar, salir o ser aprobado.
      key: ValueKey<String>('$autenticado|$pendiente|$onboardingVisto'),
      title: 'PaPedir Tienda',
      debugShowCheckedModeBanner: false,
      theme: _tema(Brightness.light),
      darkTheme: _tema(Brightness.dark),
      themeMode: ref.watch(temaProvider),
      // Preferencia "Texto grande" (Firestore / teléfono).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            ref.watch(fuenteGrandeProvider) ? 1.15 : 1.0,
          ),
        ),
        child: child!,
      ),
      home: inicio,
    );
  }
}
