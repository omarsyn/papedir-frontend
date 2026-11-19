import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        return '/inicio';
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
        path: '/inicio',
        builder: (context, state) => const _HomePlaceholderScreen(),
      ),
    ],
  );
});

/// Vista temporal mientras construimos la pantalla de permisos y el mapa
class _HomePlaceholderScreen extends ConsumerWidget {
  const _HomePlaceholderScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PaPedir Repartidor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Text('Sesión activa: ${usuario?.nombre ?? ''}'),
      ),
    );
  }
}
