import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/historial/screens/historial_screen.dart';
import 'features/mapa_disponibles/screens/mapa_disponibles_screen.dart';
import 'features/permisos/screens/permissions_gate_screen.dart';
import 'features/viaje_activo/screens/viaje_activo_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isPending = authState.isPendingApproval;
      final location = state.matchedLocation;

      if (!isLoggedIn) {
        return location == '/login' ? null : '/login';
      }

      if (isPending) {
        return location == '/revision' ? null : '/revision';
      }

      if (location == '/login' || location == '/revision') {
        return '/permisos';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(
          appTipo: AppTipo.repartidor,
          tituloApp: 'PaPedir Repartidor',
        ),
      ),
      GoRoute(
        path: '/revision',
        builder: (context, state) => const PendingReviewScreen(),
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
        builder: (context, state) => const _RutaPendienteScreen(
          titulo: 'Mi Perfil',
        ),
      ),
    ],
  );
});

class _RutaPendienteScreen extends StatelessWidget {
  final String titulo;
  const _RutaPendienteScreen({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(child: Text('Construyendo pantalla: $titulo')),
    );
  }
}
