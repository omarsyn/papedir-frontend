import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

class PermisosState {
  const PermisosState({
    this.mensaje = 'Verificando permisos de ubicación...',
    this.requiereAccionManual = false,
  });

  final String mensaje;
  final bool requiereAccionManual;
}

/// Revisa GPS y permiso de ubicación (Riverpod, sin estado local).
class PermisosNotifier extends AutoDisposeNotifier<PermisosState> {
  @override
  PermisosState build() => const PermisosState();

  /// true si ya se puede entrar al mapa.
  Future<bool> verificar() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      state = const PermisosState(
        mensaje:
            'Activa el GPS de tu dispositivo para recibir y entregar pedidos.',
        requiereAccionManual: true,
      );
      return false;
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      state = const PermisosState(
        mensaje:
            'PaPedir Repartidor requiere acceso a tu ubicación para mostrarte '
            'pedidos cercanos y validar llegadas.',
        requiereAccionManual: true,
      );
      return false;
    }
    return true;
  }
}

final permisosProvider =
    NotifierProvider.autoDispose<PermisosNotifier, PermisosState>(
      PermisosNotifier.new,
    );

/// El State solo escucha cuando la app vuelve de Ajustes; el estado de la
/// pantalla vive en [permisosProvider].
class PermissionsGateScreen extends ConsumerStatefulWidget {
  const PermissionsGateScreen({super.key});

  @override
  ConsumerState<PermissionsGateScreen> createState() =>
      _PermissionsGateScreenState();
}

class _PermissionsGateScreenState extends ConsumerState<PermissionsGateScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_verificar);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verificar();
  }

  Future<void> _verificar() async {
    final ok = await ref.read(permisosProvider.notifier).verificar();
    if (ok && mounted) context.go('/mapa');
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(permisosProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined, size: 72),
                  const SizedBox(height: 24),
                  Text(
                    'Ubicación requerida',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(estado.mensaje, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (estado.requiereAccionManual) ...[
                    FilledButton(
                      onPressed: () async {
                        final activo =
                            await Geolocator.isLocationServiceEnabled();
                        if (!activo) {
                          await Geolocator.openLocationSettings();
                        } else {
                          await Geolocator.openAppSettings();
                        }
                      },
                      child: const Text('Abrir configuración'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _verificar,
                      child: const Text('Volver a verificar'),
                    ),
                  ] else
                    const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
