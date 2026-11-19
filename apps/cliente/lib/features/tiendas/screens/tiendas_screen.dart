import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/widgets/vista_async.dart';
import '../../direcciones/data/direcciones_repository.dart';
import '../../direcciones/providers/direccion_activa_provider.dart';
import '../../direcciones/screens/direccion_form_screen.dart';
import '../../direcciones/screens/direcciones_screen.dart';
import '../data/tiendas_repository.dart';
import 'menu_screen.dart';

const _categorias = ['comida', 'abarrotes', 'farmacia', 'materiales', 'otros'];

class TiendasScreen extends ConsumerStatefulWidget {
  const TiendasScreen({super.key});

  @override
  ConsumerState<TiendasScreen> createState() => _TiendasScreenState();
}

class _TiendasScreenState extends ConsumerState<TiendasScreen> {
  final _busqueda = TextEditingController();
  String _q = '';
  String? _categoria;
  bool _listo = false;
  Object? _errorInicial;

  @override
  void initState() {
    super.initState();
    _prepararDireccion();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  /// Si no hay dirección elegida, toma la primera del usuario.
  Future<void> _prepararDireccion() async {
    try {
      if (ref.read(direccionActivaProvider) == null) {
        final lista = await ref.read(direccionesRepositoryProvider).listar();
        if (!mounted) return;
        if (lista.isNotEmpty) {
          ref.read(direccionActivaProvider.notifier).elegir(lista.first);
        }
      }
      if (!mounted) return;
      setState(() {
        _listo = true;
        _errorInicial = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorInicial = e;
        _listo = true;
      });
    }
  }

  Future<void> _cambiarDireccion() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DireccionesScreen(seleccionar: true),
      ),
    );
  }

  Future<void> _agregarDireccion() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DireccionFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final direccion = ref.watch(direccionActivaProvider);
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _cambiarDireccion,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Entregar en',
                  style: Theme.of(context).textTheme.labelSmall),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      direccion?.alias ?? 'Elige una dirección',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _cuerpo(direccion),
    );
  }

  Widget _cuerpo(Direccion? direccion) {
    if (!_listo) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorInicial != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ApiError.from(_errorInicial!).message,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _listo = false;
                  });
                  _prepararDireccion();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (direccion == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_location_alt_outlined, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Agrega una dirección para ver las tiendas cercanas.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _agregarDireccion,
                child: const Text('Agregar dirección'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _busqueda,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar tienda',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _busqueda.clear();
                        setState(() {
                          _q = '';
                        });
                      },
                    ),
            ),
            onSubmitted: (v) {
              setState(() {
                _q = v.trim();
              });
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: const Text('Todas'),
                  selected: _categoria == null,
                  onSelected: (_) {
                    setState(() {
                      _categoria = null;
                    });
                  },
                ),
              ),
              for (final c in _categorias)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(etiquetaCategoria(c)),
                    selected: _categoria == c,
                    onSelected: (_) {
                      setState(() {
                        _categoria = c;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: VistaAsync<List<Tienda>>(
            key: ValueKey<String>('${direccion.id}|$_q|$_categoria'),
            cargar: () => ref.read(tiendasRepositoryProvider).listar(
                  lat: direccion.ubicacion.lat,
                  lng: direccion.ubicacion.lng,
                  q: _q,
                  categoria: _categoria,
                ),
            builder: (context, tiendas, recargar) {
              if (tiendas.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay tiendas abiertas cerca de esta dirección.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: recargar,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: tiendas.length,
                  itemBuilder: (context, i) =>
                      _TarjetaTienda(tienda: tiendas[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TarjetaTienda extends StatelessWidget {
  const _TarjetaTienda({required this.tienda});

  final Tienda tienda;

  @override
  Widget build(BuildContext context) {
    final partes = <String>[
      etiquetaCategoria(tienda.categoria),
      '${tienda.tiempoPreparacionMin} min',
      if (tienda.distanciaKm != null)
        '${tienda.distanciaKm!.toStringAsFixed(1)} km',
      if (tienda.calificacion != null)
        '★ ${tienda.calificacion!.toStringAsFixed(1)}',
    ];
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.storefront)),
        title: Text(tienda.nombre),
        subtitle: Text(partes.join(' · ')),
        trailing: tienda.abierta ? null : const Chip(label: Text('Cerrada')),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => MenuScreen(tienda: tienda)),
          );
        },
      ),
    );
  }
}
