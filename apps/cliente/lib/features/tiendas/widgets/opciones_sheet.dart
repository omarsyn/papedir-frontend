import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/tema.dart';
import '../../../core/widgets/imagen_red.dart';
import '../../carrito/providers/carrito_provider.dart';
import '../providers/opciones_provider.dart';

/// Abre la hoja para elegir las opciones de [producto]. Devuelve lo elegido,
/// o null si el cliente la cerró sin agregar.
Future<List<OpcionElegida>?> elegirOpciones(
  BuildContext context,
  Producto producto,
) => showModalBottomSheet<List<OpcionElegida>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.75,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    builder: (_, scroll) => _HojaOpciones(producto: producto, scroll: scroll),
  ),
);

class _HojaOpciones extends ConsumerWidget {
  const _HojaOpciones({required this.producto, required this.scroll});

  final Producto producto;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = producto;
    final seleccion = ref.watch(seleccionOpcionesProvider(p.id));
    final notifier = ref.read(seleccionOpcionesProvider(p.id).notifier);
    final elegidas = opcionesElegidas(p, seleccion);
    final pendientes = gruposPendientes(p, seleccion);
    final total = p.precio + elegidas.fold(0.0, (s, o) => s + o.precioExtra);
    final tema = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(
              Disenio.margen,
              0,
              Disenio.margen,
              Disenio.margen,
            ),
            children: [
              Row(
                children: [
                  ImagenRed(
                    url: p.imagenUrl,
                    icono: Icons.fastfood_outlined,
                    ancho: 72,
                    alto: 72,
                    radio: Disenio.radioChico,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nombre, style: tema.textTheme.titleLarge),
                        if ((p.descripcion ?? '').isNotEmpty)
                          Text(
                            p.descripcion!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.bodySmall,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          dinero(p.precio),
                          style: tema.textTheme.titleMedium?.copyWith(
                            color: tema.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              for (final g in p.grupos)
                _Grupo(
                  grupo: g,
                  marcadas: seleccion[g.id] ?? const {},
                  falta: pendientes.contains(g),
                  onTap: (o) => notifier.alternar(g, o),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Disenio.margen,
              8,
              Disenio.margen,
              Disenio.margen,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: pendientes.isEmpty
                    ? () => Navigator.of(context).pop(elegidas)
                    : null,
                child: Text(
                  pendientes.isEmpty
                      ? 'Agregar · ${dinero(total)}'
                      : 'Elige ${pendientes.first.nombre.toLowerCase()}',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({
    required this.grupo,
    required this.marcadas,
    required this.falta,
    required this.onTap,
  });

  final GrupoOpciones grupo;
  final Set<String> marcadas;
  final bool falta;
  final ValueChanged<OpcionProducto> onTap;

  String get _regla {
    if (grupo.maximo <= 1) return grupo.obligatorio ? 'Elige 1' : 'Opcional';
    if (grupo.minimo == grupo.maximo) return 'Elige ${grupo.maximo}';
    if (grupo.minimo > 0) return 'Elige de ${grupo.minimo} a ${grupo.maximo}';
    return 'Hasta ${grupo.maximo}';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final unaSola = grupo.maximo <= 1;
    final lleno = !unaSola && marcadas.length >= grupo.maximo;

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(grupo.nombre, style: tema.textTheme.titleMedium),
                    Text(
                      _regla,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (grupo.obligatorio)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: falta
                        ? esquema.errorContainer
                        : esquema.primaryContainer,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    falta ? 'Obligatorio' : 'Listo',
                    style: tema.textTheme.labelSmall?.copyWith(
                      color: falta
                          ? esquema.onErrorContainer
                          : esquema.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final o in grupo.opciones)
                  _FilaOpcion(
                    opcion: o,
                    marcada: marcadas.contains(o.id),
                    unaSola: unaSola,
                    bloqueada:
                        !o.disponible || (lleno && !marcadas.contains(o.id)),
                    onTap: () => onTap(o),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaOpcion extends StatelessWidget {
  const _FilaOpcion({
    required this.opcion,
    required this.marcada,
    required this.unaSola,
    required this.bloqueada,
    required this.onTap,
  });

  final OpcionProducto opcion;
  final bool marcada;
  final bool unaSola;
  final bool bloqueada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final icono = unaSola
        ? (marcada ? Icons.radio_button_checked : Icons.radio_button_unchecked)
        : (marcada ? Icons.check_box : Icons.check_box_outline_blank);
    final extra = opcion.precioExtra > 0
        ? '+${dinero(opcion.precioExtra)}'
        : null;
    return ListTile(
      enabled: !bloqueada,
      onTap: bloqueada ? null : onTap,
      leading: Icon(
        icono,
        color: marcada ? esquema.primary : esquema.onSurfaceVariant,
      ),
      title: Text(opcion.nombre),
      subtitle: opcion.disponible ? null : const Text('Agotado'),
      trailing: extra == null ? null : Text(extra),
    );
  }
}
