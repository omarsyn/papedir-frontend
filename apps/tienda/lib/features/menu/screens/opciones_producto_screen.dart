import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/tema.dart';
import '../../../core/widgets/mensajes.dart';
import '../providers/opciones_editor_provider.dart';

/// Opciones que el cliente elige al pedir un producto: tamaño, salsas,
/// extras... Se editan aquí y se guardan todas juntas.
class OpcionesProductoScreen extends ConsumerWidget {
  const OpcionesProductoScreen({super.key, required this.producto});

  final Producto producto;

  Future<void> _guardar(BuildContext context, WidgetRef ref) async {
    final error = await ref
        .read(editorOpcionesProvider(producto.id).notifier)
        .guardar();
    if (!context.mounted) return;
    if (error != null) {
      mostrarMensaje(context, error);
      return;
    }
    mostrarMensaje(context, 'Opciones guardadas');
    Navigator.of(context).pop();
  }

  Future<void> _grupo(
    BuildContext context,
    WidgetRef ref, {
    int? indice,
  }) async {
    final notifier = ref.read(editorOpcionesProvider(producto.id).notifier);
    final actual = indice == null
        ? null
        : ref.read(editorOpcionesProvider(producto.id)).grupos[indice];
    final g = await _dialogoGrupo(context, actual);
    if (g == null) return;
    if (indice == null) {
      notifier.agregarGrupo(g);
    } else {
      notifier.editarGrupo(indice, g);
    }
  }

  Future<void> _opcion(
    BuildContext context,
    WidgetRef ref,
    int gi, {
    int? oi,
  }) async {
    final notifier = ref.read(editorOpcionesProvider(producto.id).notifier);
    final grupo = ref.read(editorOpcionesProvider(producto.id)).grupos[gi];
    final o = await _dialogoOpcion(
      context,
      oi == null ? null : grupo.opciones[oi],
    );
    if (o == null) return;
    if (oi == null) {
      notifier.agregarOpcion(gi, o);
    } else {
      notifier.editarOpcion(gi, oi, o);
    }
  }

  Future<bool> _salirSinGuardar(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Salir sin guardar?'),
          content: const Text('Perderás los cambios en las opciones.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salir'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(editorOpcionesProvider(producto.id));
    final notifier = ref.read(editorOpcionesProvider(producto.id).notifier);
    final tema = Theme.of(context);

    return PopScope(
      canPop: !estado.cambios,
      onPopInvokedWithResult: (salio, _) async {
        if (salio) return;
        if (await _salirSinGuardar(context) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Opciones'),
              Text(producto.nombre, style: tema.textTheme.bodySmall),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonal(
                onPressed: estado.guardando || !estado.cambios
                    ? null
                    : () => _guardar(context, ref),
                child: estado.guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _grupo(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Grupo'),
        ),
        body: estado.grupos.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 64,
                        color: tema.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text('Sin opciones', style: tema.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text(
                        'Agrega grupos como "Salsa: elige 1" o '
                        '"Extras: hasta 3". El cliente los elegirá al pedir.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  Disenio.margen,
                  Disenio.margen,
                  Disenio.margen,
                  96,
                ),
                children: [
                  for (var gi = 0; gi < estado.grupos.length; gi++)
                    _TarjetaGrupo(
                      grupo: estado.grupos[gi],
                      onEditar: () => _grupo(context, ref, indice: gi),
                      onQuitar: () => notifier.quitarGrupo(gi),
                      onAgregarOpcion: () => _opcion(context, ref, gi),
                      onEditarOpcion: (oi) => _opcion(context, ref, gi, oi: oi),
                      onDisponible: (oi) => notifier.alternarDisponible(gi, oi),
                      onQuitarOpcion: (oi) => notifier.quitarOpcion(gi, oi),
                    ),
                ],
              ),
      ),
    );
  }
}

class _TarjetaGrupo extends StatelessWidget {
  const _TarjetaGrupo({
    required this.grupo,
    required this.onEditar,
    required this.onQuitar,
    required this.onAgregarOpcion,
    required this.onEditarOpcion,
    required this.onDisponible,
    required this.onQuitarOpcion,
  });

  final GrupoEditable grupo;
  final VoidCallback onEditar;
  final VoidCallback onQuitar;
  final VoidCallback onAgregarOpcion;
  final ValueChanged<int> onEditarOpcion;
  final ValueChanged<int> onDisponible;
  final ValueChanged<int> onQuitarOpcion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(grupo.nombre, style: tema.textTheme.titleMedium),
              subtitle: Text(grupo.regla),
              trailing: PopupMenuButton<String>(
                onSelected: (op) => op == 'editar' ? onEditar() : onQuitar(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'editar', child: Text('Editar grupo')),
                  PopupMenuItem(value: 'quitar', child: Text('Quitar grupo')),
                ],
              ),
            ),
            const Divider(height: 1),
            for (var oi = 0; oi < grupo.opciones.length; oi++)
              ListTile(
                dense: true,
                onTap: () => onEditarOpcion(oi),
                title: Text(
                  grupo.opciones[oi].nombre,
                  style: grupo.opciones[oi].disponible
                      ? null
                      : const TextStyle(decoration: TextDecoration.lineThrough),
                ),
                subtitle: Text(
                  grupo.opciones[oi].precioExtra > 0
                      ? '+${dinero(grupo.opciones[oi].precioExtra)}'
                      : 'Sin costo extra',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: grupo.opciones[oi].disponible,
                      onChanged: (_) => onDisponible(oi),
                    ),
                    IconButton(
                      tooltip: 'Quitar',
                      icon: const Icon(Icons.close),
                      onPressed: () => onQuitarOpcion(oi),
                    ),
                  ],
                ),
              ),
            if (grupo.opciones.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text('Agrega al menos una opción.'),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: TextButton.icon(
                  onPressed: onAgregarOpcion,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar opción'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int? _entero(String? v) => int.tryParse((v ?? '').trim());

/// Diálogo para crear o editar un grupo (sin setState: los valores van en
/// variables locales que el Form valida al aceptar).
Future<GrupoEditable?> _dialogoGrupo(
  BuildContext context,
  GrupoEditable? actual,
) async {
  final form = GlobalKey<FormState>();
  var nombre = actual?.nombre ?? '';
  var minimo = '${actual?.minimo ?? 1}';
  var maximo = '${actual?.maximo ?? 1}';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(actual == null ? 'Nuevo grupo' : 'Editar grupo'),
      scrollable: true,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: nombre,
              autofocus: true,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Salsa, Tamaño, Extras',
              ),
              onChanged: (v) => nombre = v,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: minimo,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Mínimo a elegir',
                helperText: '0 = opcional',
              ),
              onChanged: (v) => minimo = v,
              validator: (v) => _entero(v) == null ? 'Escribe un número' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: maximo,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Máximo a elegir',
                helperText: '1 = solo una opción',
                helperMaxLines: 2,
              ),
              onChanged: (v) => maximo = v,
              validator: (v) {
                final max = _entero(v);
                if (max == null || max < 1) return 'Debe ser 1 o más';
                if ((_entero(minimo) ?? 0) > max) {
                  return 'No puede ser menor que el mínimo';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState?.validate() ?? false) {
              Navigator.pop(ctx, true);
            }
          },
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
  if (ok != true) return null;
  return GrupoEditable(
    nombre: nombre.trim(),
    minimo: _entero(minimo) ?? 0,
    maximo: _entero(maximo) ?? 1,
  );
}

Future<OpcionEditable?> _dialogoOpcion(
  BuildContext context,
  OpcionEditable? actual,
) async {
  final form = GlobalKey<FormState>();
  var nombre = actual?.nombre ?? '';
  var precio = actual == null || actual.precioExtra == 0
      ? ''
      : actual.precioExtra.toStringAsFixed(2);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(actual == null ? 'Nueva opción' : 'Editar opción'),
      scrollable: true,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: nombre,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Verde, Grande, Queso extra',
              ),
              onChanged: (v) => nombre = v,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: precio,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Precio extra (opcional)',
                prefixText: '\$ ',
              ),
              onChanged: (v) => precio = v,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = double.tryParse(t);
                return n == null || n < 0 ? 'Precio no válido' : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState?.validate() ?? false) {
              Navigator.pop(ctx, true);
            }
          },
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
  if (ok != true) return null;
  return OpcionEditable(
    nombre: nombre.trim(),
    precioExtra: double.tryParse(precio.trim()) ?? 0,
    disponible: actual?.disponible ?? true,
  );
}
