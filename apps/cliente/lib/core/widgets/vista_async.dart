import 'package:flutter/material.dart';

import '../api_error.dart';

/// Carga un Future y muestra: cargando, error con "Reintentar", o el contenido.
/// El builder recibe `recargar` para usarlo con RefreshIndicator.
class VistaAsync<T> extends StatefulWidget {
  const VistaAsync({super.key, required this.cargar, required this.builder});

  final Future<T> Function() cargar;
  final Widget Function(
    BuildContext context,
    T datos,
    Future<void> Function() recargar,
  ) builder;

  @override
  State<VistaAsync<T>> createState() => _VistaAsyncState<T>();
}

class _VistaAsyncState<T> extends State<VistaAsync<T>> {
  late Future<T> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = widget.cargar();
  }

  Future<void> _recargar() async {
    if (!mounted) return;
    final f = widget.cargar();
    setState(() {
      _futuro = f;
    });
    try {
      await f;
    } catch (_) {
      // el error se muestra en la vista
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ApiError.from(snap.error!).message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _recargar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        return widget.builder(context, snap.data as T, _recargar);
      },
    );
  }
}
