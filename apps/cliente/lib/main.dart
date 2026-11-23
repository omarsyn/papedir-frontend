import 'package:core/core.dart'
    show
        AppTipo,
        AuthState,
        LoginScreen,
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
import 'features/auth/screens/register_screen.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/recuperar/recuperar_screen.dart';
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
      child: const PaPedirCliente(),
    ),
  );
}

const _bienvenida = [
  PaginaOnboarding(
    icono: Icons.storefront,
    titulo: 'Tiendas de Celaya',
    texto: 'Pide comida, abarrotes o medicina de los negocios cerca de ti.',
  ),
  PaginaOnboarding(
    icono: Icons.map_outlined,
    titulo: 'Marca tu dirección',
    texto:
        'Elige el punto exacto en el mapa para que el repartidor llegue sin perderse.',
  ),
  PaginaOnboarding(
    icono: Icons.delivery_dining,
    titulo: 'Sigue tu pedido',
    texto: 'Ve en qué va tu pedido y recíbelo con tu código de entrega.',
  ),
];

/// Diseño de la app (ver core/tema.dart). El color de la marca no cambia.
ThemeData _tema(Brightness brillo) =>
    construirTema(const Color(0xFF1565C0), brillo);

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
        // Temas de Cloud Messaging que se envían desde la consola de Firebase.
        suscribirTemas([
          'novedades',
          if (ref.read(promocionesProvider)) 'promociones',
        ]);
      }
    });

    // Preferencias en Firestore: si cambian en otro teléfono, se aplican aquí.
    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      preferenciasRemotasProvider,
      (_, siguiente) => aplicarPreferenciasRemotas(ref, siguiente.valueOrNull),
    );

    final arranque = ref.watch(arranqueProvider);
    final autenticado = ref.watch(authProvider).isAuthenticated;

    final onboardingVisto = ref.watch(onboardingVistoProvider);

    final Widget inicio;
    if (!onboardingVisto) {
      inicio = const OnboardingScreen(paginas: _bienvenida);
    } else if (arranque.isLoading) {
      inicio = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (!autenticado) {
      inicio = Builder(
        builder: (context) => LoginScreen(
          appTipo: AppTipo.cliente,
          logo: Image.asset('assets/logo.png', height: 110),
          tituloApp: 'PaPedir',
          onIrARegistro: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
            );
          },
          onOlvidePassword: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RecuperarScreen(app: AppTipo.cliente),
              ),
            );
          },
        ),
      );
    } else if (ref.watch(authProvider).usuario?.terminosPendientes ?? false) {
      // Hay términos nuevos: se aceptan antes de entrar.
      inicio = const TerminosPendientesScreen();
    } else {
      inicio = const HomeShell();
    }

    return MaterialApp(
      // La llave reinicia la navegación al iniciar o cerrar sesión.
      key: ValueKey<String>('$autenticado|$onboardingVisto'),
      title: 'PaPedir',
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
