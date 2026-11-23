import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/screens/recuperar_password_screen.dart';
import 'features/auth/screens/registro_repartidor_screen.dart';
import 'features/documentos/documentos_screen.dart';
import 'features/ganancias/ganancias_screen.dart';
import 'features/historial/screens/historial_screen.dart';
import 'features/mapa_disponibles/screens/mapa_disponibles_screen.dart';
import 'features/onboarding/providers/onboarding_provider.dart';
import 'features/onboarding/screens/onboarding_repartidor_screen.dart';
import 'features/perfil/screens/perfil_screen.dart';
import 'features/permisos/screens/permissions_gate_screen.dart';
import 'features/revision/revision_screen.dart';
import 'features/terminos/terminos_pendientes_screen.dart';
import 'features/viaje_activo/screens/viaje_activo_screen.dart';

/// Avisa a GoRouter que vuelva a evaluar `redirect` cuando cambia la sesión
/// o el onboarding.
class _RefrescoRouter extends ChangeNotifier {
  void avisar() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = _RefrescoRouter();
  ref.listen(authProvider, (_, __) => authRefresh.avisar());
  ref.listen(onboardingRepartidorProvider, (_, __) => authRefresh.avisar());
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final onboardingState = ref.read(onboardingRepartidorProvider);
      final isLoggedIn = authState.isAuthenticated;
      final isPending = authState.isPendingApproval;
      final location = state.matchedLocation;
      final isPublicRoute = location == '/login' ||
          location == '/registro' ||
          location == '/recuperar-password';

      if (!isLoggedIn) {
        return isPublicRoute ? null : '/login';
      }

      // Términos nuevos: se aceptan antes de cualquier otra cosa.
      if (authState.usuario?.terminosPendientes ?? false) {
        return location == '/terminos' ? null : '/terminos';
      }

      if (isPending) {
        return location == '/revision' ? null : '/revision';
      }

      if (!onboardingState.completadoEnSesion) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      if (isPublicRoute ||
          location == '/revision' ||
          location == '/terminos' ||
          location == '/onboarding') {
        return '/permisos';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          appTipo: AppTipo.repartidor,
          tituloApp: 'PaPedir Repartidor',
          logo: Image.asset(
            'assets/images/Logo.png',
            height: 92,
            fit: BoxFit.contain,
          ),
          onIrARegistro: () => context.push('/registro'),
          onOlvidePassword: () => context.push('/recuperar-password'),
        ),
      ),
      GoRoute(
        path: '/registro',
        builder: (context, state) => const RegistroRepartidorScreen(),
      ),
      GoRoute(
        path: '/recuperar-password',
        builder: (context, state) => RecuperarPasswordScreen(
          emailInicial: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingRepartidorScreen(),
      ),
      GoRoute(
        path: '/revision',
        builder: (context, state) => const RevisionScreen(),
      ),
      GoRoute(
        path: '/terminos',
        builder: (context, state) => const TerminosPendientesScreen(),
      ),
      GoRoute(
        path: '/ganancias',
        builder: (context, state) => const GananciasScreen(),
      ),
      GoRoute(
        path: '/documentos',
        builder: (context, state) => const DocumentosScreen(),
      ),
      GoRoute(
        path: '/permisos',
        builder: (context, state) => const PermissionsGateScreen(),
      ),
      GoRoute(
        path: '/mapa',
        builder: (context, state) => const MapaDisponiblesScreen(),
      ),
      GoRoute(
        path: '/viaje',
        builder: (context, state) => const ViajeActivoScreen(),
      ),
      GoRoute(
        path: '/historial',
        builder: (context, state) => const HistorialScreen(),
      ),
      GoRoute(
        path: '/perfil',
        builder: (context, state) => const PerfilScreen(),
      ),
      GoRoute(
        path: '/soporte',
        builder: (context, state) => const TicketsListScreen(),
      ),
    ],
  );
});