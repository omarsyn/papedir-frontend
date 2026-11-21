import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/widgets/mensajes.dart';
import '../mi_tienda/data/tienda_repository.dart';
import '../mi_tienda/providers/mi_tienda_provider.dart';

/// Aceleración (m/s², ya sin gravedad) de un golpe fuerte. En reposo marca ~0.
const _umbral = 15.0;

/// Golpes fuertes seguidos que cuentan como "agitar".
const _golpesNecesarios = 3;

/// Tiempo máximo entre esos golpes.
const _ventana = Duration(milliseconds: 1000);

/// Tiempo mínimo entre dos avisos.
const _espera = Duration(seconds: 10);

/// Minutos de pausa al agitar.
const _minutosPausa = 15;

/// Escucha el acelerómetro mientras la tienda está abierta en pantalla.
/// Al agitar el teléfono ofrece pausar los pedidos 15 minutos.
class DetectorAgitar extends ConsumerStatefulWidget {
  const DetectorAgitar({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DetectorAgitar> createState() => _DetectorAgitarState();
}

class _DetectorAgitarState extends ConsumerState<DetectorAgitar> {
  StreamSubscription<UserAccelerometerEvent>? _suscripcion;
  DateTime _ultimoAviso = DateTime(2000);
  DateTime _ultimoGolpe = DateTime(2000);
  int _golpes = 0;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    // userAccelerometer descuenta la gravedad: levantar el teléfono casi no
    // marca nada, solo las sacudidas. gameInterval = ~50 lecturas por segundo.
    _suscripcion = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_alMoverse, onError: (Object _) {});
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }

  void _alMoverse(UserAccelerometerEvent e) {
    if (_ocupado || !mounted) return;
    final fuerza = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (fuerza <= _umbral) return;

    final ahora = DateTime.now();
    // Un golpe aislado no cuenta: tienen que ser varios seguidos.
    _golpes = ahora.difference(_ultimoGolpe) <= _ventana ? _golpes + 1 : 1;
    _ultimoGolpe = ahora;
    if (_golpes < _golpesNecesarios) return;
    _golpes = 0;

    if (ahora.difference(_ultimoAviso) < _espera) return;
    _ultimoAviso = ahora;
    _preguntar();
  }

  Future<void> _preguntar() async {
    _ocupado = true;
    try {
      // Se pregunta al servidor si ya está en pausa: así cuenta también
      // si se pausó o se reanudó desde "Mi tienda".
      final repo = ref.read(tiendaRepositoryProvider);
      final tienda = await repo.miTienda();
      if (tienda.pausada || !mounted) return;

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.vibration),
          title: const Text('¿Pausar pedidos?'),
          content: const Text(
            'Agitaste el teléfono. ¿Dejar de recibir pedidos nuevos $_minutosPausa minutos?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pausar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await repo.pausar(_minutosPausa);
      ref.invalidate(miTiendaProvider);
      if (mounted) {
        mostrarMensaje(context, 'Pedidos pausados $_minutosPausa minutos');
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      _ocupado = false;
      _ultimoAviso = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
