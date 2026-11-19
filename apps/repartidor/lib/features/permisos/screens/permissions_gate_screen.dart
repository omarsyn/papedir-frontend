import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

class PermissionsGateScreen extends StatefulWidget {
  const PermissionsGateScreen({super.key});

  @override
  State<PermissionsGateScreen> createState() => _PermissionsGateScreenState();
}

class _PermissionsGateScreenState extends State<PermissionsGateScreen>
    with WidgetsBindingObserver {
  String _mensaje = 'Verificando permisos de ubicación...';
  bool _requiereAccionManual = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificarPermisos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificarPermisos();
    }
  }

  Future<void> _verificarPermisos() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _mensaje =
            'Activa el GPS de tu dispositivo para recibir y entregar pedidos.';
        _requiereAccionManual = true;
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _mensaje =
            'PaPedir Repartidor requiere acceso a tu ubicación para mostrarte pedidos cercanos y validar llegadas.';
        _requiereAccionManual = true;
      });
      return;
    }

    if (!mounted) return;
    context.go('/mapa');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
              Text(_mensaje, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (_requiereAccionManual) ...[
                FilledButton(
                  onPressed: () async {
                    final enabled = await Geolocator.isLocationServiceEnabled();
                    if (!enabled) {
                      await Geolocator.openLocationSettings();
                    } else {
                      await Geolocator.openAppSettings();
                    }
                  },
                  child: const Text('Abrir configuración'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _verificarPermisos,
                  child: const Text('Volver a verificar'),
                ),
              ] else
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}