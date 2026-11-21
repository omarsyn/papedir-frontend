import 'package:core/core.dart' show authProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/catalogos_provider.dart';
import '../../../core/models.dart';
import '../../../core/widgets/imagen_red.dart';
import '../../../core/widgets/vista_async.dart';
import '../../direcciones/providers/direccion_activa_provider.dart';
import '../../direcciones/providers/direcciones_provider.dart';
import '../../direcciones/screens/direccion_form_screen.dart';
import '../../direcciones/screens/direcciones_screen.dart';
import '../providers/tiendas_provider.dart';
import 'menu_screen.dart';

void _abrirMenu(BuildContext context, Tienda tienda, String heroTag) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MenuScreen(tienda: tienda, heroTag: heroTag),
    ),
  );
}

/// Inicio del cliente: encabezado con la dirección, búsqueda, categorías,
/// filtros rápidos, tiendas destacadas y el listado completo.
class TiendasScreen extends ConsumerWidget {
  const TiendasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direccion = ref.watch(direccionActivaProvider);
    final inicial = ref.watch(direccionInicialProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: inicial.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Mensaje(
            icono: Icons.wifi_off_rounded,
            titulo: 'No pudimos cargar tus direcciones',
            texto: ApiError.from(e).message,
            boton: 'Reintentar',
            onBoton: () => ref.invalidate(direccionInicialProvider),
          ),
          data: (_) =>
              direccion == null ? const _SinDireccion() : const _Inicio(),
        ),
      ),
    );
  }
}

class _SinDireccion extends StatelessWidget {
  const _SinDireccion();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _Mensaje(
        icono: Icons.add_location_alt_rounded,
        titulo: '¿A dónde te llevamos tu pedido?',
        texto: 'Agrega una dirección para ver las tiendas cercanas.',
        boton: 'Agregar dirección',
        onBoton: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const DireccionFormScreen(),
            ),
          );
        },
      ),
    );
  }
}

class _Inicio extends ConsumerWidget {
  const _Inicio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiendas = ref.watch(tiendasProvider);
    final filtros = ref.watch(filtrosProvider);
    final hayBusqueda =
        ref.watch(busquedaProvider).isNotEmpty ||
        ref.watch(categoriaProvider) != null ||
        filtros.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () =>
          recargarSilencioso(() => ref.refresh(tiendasProvider.future)),
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _Encabezado()),
          const SliverToBoxAdapter(child: _Categorias()),
          const SliverToBoxAdapter(child: _FiltrosRapidos()),
          ...tiendas.when<List<Widget>>(
            loading: () => const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Mensaje(
                  icono: Icons.wifi_off_rounded,
                  titulo: 'No pudimos cargar las tiendas',
                  texto: ApiError.from(e).message,
                  boton: 'Reintentar',
                  onBoton: () => ref.invalidate(tiendasProvider),
                ),
              ),
            ],
            data: (lista) {
              final visibles = filtrarTiendas(lista, filtros);
              if (visibles.isEmpty) {
                return [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Mensaje(
                      icono: Icons.search_off_rounded,
                      titulo: 'Sin resultados',
                      texto: hayBusqueda
                          ? 'Prueba con otra búsqueda o quita los filtros.'
                          : 'No hay tiendas cerca de esta dirección.',
                    ),
                  ),
                ];
              }
              final destacadas =
                  visibles
                      .where((t) => t.abierta && (t.calificacion ?? 0) >= 4)
                      .toList()
                    ..sort(
                      (a, b) =>
                          (b.calificacion ?? 0).compareTo(a.calificacion ?? 0),
                    );
              return [
                if (destacadas.isNotEmpty && !hayBusqueda) ...[
                  const SliverToBoxAdapter(
                    child: _TituloSeccion(titulo: 'Destacadas'),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 214,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: destacadas.length > 8
                            ? 8
                            : destacadas.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, i) =>
                            _TarjetaDestacada(tienda: destacadas[i]),
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: _TituloSeccion(
                    titulo: hayBusqueda ? 'Resultados' : 'Todas las tiendas',
                    extra: '${visibles.length}',
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  // En tabletas u horizontal, las tiendas van en cuadrícula.
                  sliver: SliverLayoutBuilder(
                    builder: (context, medidas) =>
                        medidas.crossAxisExtent >= 700
                        ? SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 420,
                                  mainAxisExtent: 250,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _TarjetaTienda(tienda: visibles[i]),
                              childCount: visibles.length,
                            ),
                          )
                        : SliverList.separated(
                            itemCount: visibles.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) =>
                                _TarjetaTienda(tienda: visibles[i]),
                          ),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

/// Encabezado de color con la dirección, el saludo y la barra de búsqueda.
class _Encabezado extends ConsumerWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direccion = ref.watch(direccionActivaProvider);
    final usuario = ref.watch(authProvider).usuario;
    final nombre = (usuario?.nombre ?? '').trim().split(' ').first;
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final arriba = MediaQuery.paddingOf(context).top;
    const blanco = Colors.white;

    return Stack(
      children: [
        Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, arriba + 12, 20, 52),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    esquema.primary,
                    Color.lerp(esquema.primary, Colors.black, 0.45)!,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const DireccionesScreen(seleccionar: true),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: blanco),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Entregar en',
                                  style: tema.textTheme.labelSmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  direccion?.alias ?? 'Elige una dirección',
                                  overflow: TextOverflow.ellipsis,
                                  style: tema.textTheme.titleMedium?.copyWith(
                                    color: blanco,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: blanco,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre.isEmpty
                                  ? '¿Qué se te antoja hoy?'
                                  : 'Hola, $nombre',
                              style: tema.textTheme.headlineSmall?.copyWith(
                                color: blanco,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pide a las tiendas de Celaya y recíbelo en minutos.',
                              style: tema.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: blanco.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delivery_dining_rounded,
                          size: 36,
                          color: blanco,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
        const Positioned(left: 16, right: 16, bottom: 0, child: _Busqueda()),
      ],
    );
  }
}

class _Busqueda extends ConsumerWidget {
  const _Busqueda();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(busquedaControllerProvider);
    final q = ref.watch(busquedaProvider);
    final tema = Theme.of(context);
    void buscar() =>
        ref.read(busquedaProvider.notifier).cambiar(controller.text.trim());

    return Material(
      color: tema.cardTheme.color,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: tema.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => buscar(),
                decoration: const InputDecoration(
                  hintText: 'Buscar tiendas o antojos',
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            if (q.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Borrar búsqueda',
                onPressed: () {
                  controller.clear();
                  ref.read(busquedaProvider.notifier).cambiar('');
                },
              ),
            FilledButton(
              onPressed: buscar,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: const Text('Buscar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mosaicos de categorías (las del catálogo del admin).
class _Categorias extends ConsumerWidget {
  const _Categorias();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorias =
        ref.watch(categoriasProvider).valueOrNull ?? categoriasBase;
    final elegida = ref.watch(categoriaProvider);
    final notifier = ref.read(categoriaProvider.notifier);
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 18, 6, 0),
        children: [
          _Mosaico(
            icono: Icons.apps_rounded,
            nombre: 'Todas',
            elegido: elegida == null,
            onTap: () => notifier.cambiar(null),
          ),
          for (final c in categorias)
            _Mosaico(
              icono: iconoCategoria(c.codigo),
              nombre: c.nombre,
              elegido: elegida == c.codigo,
              onTap: () =>
                  notifier.cambiar(elegida == c.codigo ? null : c.codigo),
            ),
        ],
      ),
    );
  }
}

class _Mosaico extends StatelessWidget {
  const _Mosaico({
    required this.icono,
    required this.nombre,
    required this.elegido,
    required this.onTap,
  });

  final IconData icono;
  final String nombre;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: tema.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 86,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: elegido
                    ? esquema.primary
                    : esquema.outlineVariant.withValues(alpha: 0.5),
                width: elegido ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: elegido ? esquema.primary : esquema.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icono,
                    color: elegido
                        ? esquema.onPrimary
                        : esquema.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltrosRapidos extends ConsumerWidget {
  const _FiltrosRapidos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(filtrosProvider);
    final notifier = ref.read(filtrosProvider.notifier);
    Widget chip(FiltroRapido f, IconData icono, String texto) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icono, size: 18),
        label: Text(texto),
        selected: filtros.contains(f),
        onSelected: (_) => notifier.alternar(f),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          chip(FiltroRapido.abiertas, Icons.storefront_rounded, 'Abiertas'),
          chip(FiltroRapido.rapidas, Icons.timer_outlined, 'Menos de 30 min'),
          chip(FiltroRapido.cercanas, Icons.near_me_outlined, 'Más cerca'),
          chip(FiltroRapido.mejores, Icons.star_rounded, 'Mejor calificadas'),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.titulo, this.extra});

  final String titulo;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        children: [
          Expanded(child: Text(titulo, style: tema.textTheme.titleLarge)),
          if (extra != null)
            Text(
              extra!,
              style: tema.textTheme.labelLarge?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Etiqueta pequeña sobre las fotos (tiempo, calificación, "Cerrada").
class _Insignia extends StatelessWidget {
  const _Insignia({required this.texto, this.icono, this.colorIcono});

  final String texto;
  final IconData? icono;
  final Color? colorIcono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 15, color: colorIcono ?? Colors.black87),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

String _detalle(Tienda t) => [
  '${t.tiempoPreparacionMin} min',
  if (t.distanciaKm != null) '${t.distanciaKm!.toStringAsFixed(1)} km',
].join(' · ');

class _TarjetaDestacada extends StatelessWidget {
  const _TarjetaDestacada({required this.tienda});

  final Tienda tienda;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tag = 'destacada-${tienda.id}';
    return SizedBox(
      width: 240,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: () => _abrirMenu(context, tienda, tag),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: tag,
                    child: ImagenRed(
                      url: tienda.imagenUrl,
                      icono: iconoCategoria(tienda.categoria),
                      ancho: double.infinity,
                      alto: 124,
                    ),
                  ),
                  if (tienda.calificacion != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _Insignia(
                        texto: tienda.calificacion!.toStringAsFixed(1),
                        icono: Icons.star_rounded,
                        colorIcono: Colors.amber.shade700,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Text(
                  tienda.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                child: Text(
                  _detalle(tienda),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaTienda extends ConsumerWidget {
  const _TarjetaTienda({required this.tienda});

  final Tienda tienda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorias =
        ref.watch(categoriasProvider).valueOrNull ?? categoriasBase;
    final tema = Theme.of(context);
    final tag = 'tienda-${tienda.id}';
    final descripcion = tienda.descripcion ?? '';
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _abrirMenu(context, tienda, tag),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: tag,
                  child: ImagenRed(
                    url: tienda.imagenUrl,
                    icono: iconoCategoria(tienda.categoria),
                    ancho: double.infinity,
                    alto: 150,
                  ),
                ),
                if (!tienda.abierta)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: const _Insignia(
                        texto: 'Cerrada por ahora',
                        icono: Icons.schedule_rounded,
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _Insignia(
                    texto: '${tienda.tiempoPreparacionMin} min',
                    icono: Icons.timer_outlined,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tienda.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.titleMedium,
                        ),
                      ),
                      if (tienda.calificacion != null) ...[
                        Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          tienda.calificacion!.toStringAsFixed(1),
                          style: tema.textTheme.labelLarge,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      nombreCategoria(categorias, tienda.categoria),
                      if (tienda.distanciaKm != null)
                        '${tienda.distanciaKm!.toStringAsFixed(1)} km',
                    ].join(' · '),
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (descripcion.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      descripcion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensaje centrado con ícono (vacío, error o sin dirección).
class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icono,
    required this.titulo,
    required this.texto,
    this.boton,
    this.onBoton,
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final String? boton;
  final VoidCallback? onBoton;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: tema.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icono,
                size: 40,
                color: tema.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: tema.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            if (boton != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onBoton, child: Text(boton!)),
            ],
          ],
        ),
      ),
    );
  }
}
