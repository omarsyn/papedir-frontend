import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/formato.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/tienda_activa.dart';
import '../../core/widgets/mensajes.dart';
import '../../core/widgets/vista_async.dart';

/// Cupón de la sucursal. El descuento lo absorbe la tienda.
class Cupon {
  const Cupon({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.valor,
    required this.minimoCompra,
    required this.usos,
    required this.activo,
    this.descripcion,
    this.maximoDescuento,
    this.usosMaximos,
    this.fin,
    this.soloPrimerPedido = false,
  });

  final String id;
  final String codigo;
  final String tipo;
  final double valor;
  final double minimoCompra;
  final int usos;
  final bool activo;
  final String? descripcion;
  final double? maximoDescuento;
  final int? usosMaximos;
  final DateTime? fin;
  final bool soloPrimerPedido;

  String get resumen {
    final desc = tipo == 'porcentaje'
        ? '${valor.toStringAsFixed(0)} % de descuento'
        : '${dinero(valor)} de descuento';
    return [
      desc,
      if (maximoDescuento != null) 'máx. ${dinero(maximoDescuento!)}',
      if (minimoCompra > 0) 'compra mín. ${dinero(minimoCompra)}',
      if (soloPrimerPedido) 'solo primer pedido',
    ].join(' · ');
  }

  factory Cupon.fromJson(Map<String, dynamic> j) {
    double? n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');
    return Cupon(
      id: '${j['id']}',
      codigo: '${j['codigo']}',
      tipo: '${j['tipo'] ?? 'monto'}',
      valor: n(j['valor']) ?? 0,
      minimoCompra: n(j['minimoCompra']) ?? 0,
      usos: (j['usos'] as num?)?.toInt() ?? 0,
      activo: (j['activo'] as bool?) ?? true,
      descripcion: j['descripcion'] as String?,
      maximoDescuento: n(j['maximoDescuento']),
      usosMaximos: (j['usosMaximos'] as num?)?.toInt(),
      fin: j['fin'] == null
          ? null
          : DateTime.tryParse('${j['fin']}')?.toLocal(),
      soloPrimerPedido: (j['soloPrimerPedido'] as bool?) ?? false,
    );
  }
}

class CuponesNotifier extends AutoDisposeAsyncNotifier<List<Cupon>> {
  @override
  Future<List<Cupon>> build() async {
    ref.watch(tiendaActivaProvider);
    final r = await conApiError(
      () => ref.read(dioProvider).get<List<dynamic>>('/tiendas/mia/cupones'),
    );
    return [for (final c in r.data ?? const []) Cupon.fromJson(asMapa(c))];
  }

  Future<void> activar(Cupon c, bool activo) async {
    await conApiError(
      () => ref
          .read(dioProvider)
          .patch<void>(
            '/tiendas/mia/cupones/${c.id}',
            data: {'activo': activo},
          ),
    );
    ref.invalidateSelf();
  }

  Future<void> crear(Map<String, dynamic> datos) async {
    await conApiError(
      () =>
          ref.read(dioProvider).post<void>('/tiendas/mia/cupones', data: datos),
    );
    ref.invalidateSelf();
  }
}

final cuponesProvider =
    AsyncNotifierProvider.autoDispose<CuponesNotifier, List<Cupon>>(
      CuponesNotifier.new,
    );

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

class CuponesScreen extends ConsumerWidget {
  const CuponesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cupones = ref.watch(cuponesProvider);
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis cupones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NuevoCuponScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Cupón'),
      ),
      body: VistaAsync<List<Cupon>>(
        valor: cupones,
        onReintentar: () => ref.invalidate(cuponesProvider),
        builder: (lista) => lista.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Crea un cupón (por ejemplo BIENVENIDA, 10 %) para atraer '
                    'clientes. El descuento sale de tu venta.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                itemCount: lista.length,
                itemBuilder: (_, i) {
                  final c = lista[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: SwitchListTile(
                      value: c.activo,
                      onChanged: (v) async {
                        try {
                          await ref
                              .read(cuponesProvider.notifier)
                              .activar(c, v);
                        } catch (e) {
                          if (context.mounted) mostrarError(context, e);
                        }
                      },
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: esquema.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              c.codigo,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: esquema.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        [
                          c.resumen,
                          'Usado ${c.usos}'
                              '${c.usosMaximos == null ? '' : ' de ${c.usosMaximos}'}'
                              ' veces',
                          if (c.fin != null) 'Vence el ${_fecha(c.fin!)}',
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Formulario de cupón nuevo (sin setState).
class _CamposCupon {
  final form = GlobalKey<FormState>();
  final codigo = TextEditingController();
  final descripcion = TextEditingController();
  final valor = TextEditingController();
  final minimo = TextEditingController();
  final maximo = TextEditingController();
  final usos = TextEditingController();

  void dispose() {
    for (final c in [codigo, descripcion, valor, minimo, maximo, usos]) {
      c.dispose();
    }
  }
}

final _camposCuponProvider = Provider.autoDispose<_CamposCupon>((ref) {
  final c = _CamposCupon();
  ref.onDispose(c.dispose);
  return c;
});

class _OpcionesCupon {
  const _OpcionesCupon({
    this.tipo = 'porcentaje',
    this.soloPrimerPedido = false,
    this.fin,
    this.guardando = false,
  });

  final String tipo;
  final bool soloPrimerPedido;
  final DateTime? fin;
  final bool guardando;

  _OpcionesCupon copyWith({
    String? tipo,
    bool? soloPrimerPedido,
    DateTime? fin,
    bool quitarFin = false,
    bool? guardando,
  }) => _OpcionesCupon(
    tipo: tipo ?? this.tipo,
    soloPrimerPedido: soloPrimerPedido ?? this.soloPrimerPedido,
    fin: quitarFin ? null : (fin ?? this.fin),
    guardando: guardando ?? this.guardando,
  );
}

final _opcionesCuponProvider = StateProvider.autoDispose<_OpcionesCupon>(
  (_) => const _OpcionesCupon(),
);

double? _num(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

class NuevoCuponScreen extends ConsumerWidget {
  const NuevoCuponScreen({super.key});

  Future<void> _guardar(BuildContext context, WidgetRef ref) async {
    final c = ref.read(_camposCuponProvider);
    if (!(c.form.currentState?.validate() ?? false)) return;
    final o = ref.read(_opcionesCuponProvider.notifier);
    final op = o.state;
    o.state = op.copyWith(guardando: true);
    try {
      await ref.read(cuponesProvider.notifier).crear({
        'codigo': c.codigo.text.trim().toUpperCase(),
        if (c.descripcion.text.trim().isNotEmpty)
          'descripcion': c.descripcion.text.trim(),
        'tipo': op.tipo,
        'valor': _num(c.valor.text),
        if (op.tipo == 'porcentaje' && _num(c.maximo.text) != null)
          'maximoDescuento': _num(c.maximo.text),
        'minimoCompra': _num(c.minimo.text) ?? 0,
        if (int.tryParse(c.usos.text.trim()) != null)
          'usosMaximos': int.parse(c.usos.text.trim()),
        'soloPrimerPedido': op.soloPrimerPedido,
        if (op.fin != null)
          'fin': DateTime(
            op.fin!.year,
            op.fin!.month,
            op.fin!.day,
            23,
            59,
          ).toUtc().toIso8601String(),
        'activo': true,
      });
      if (!context.mounted) return;
      mostrarMensaje(context, 'Cupón creado');
      Navigator.of(context).pop();
    } on ApiError catch (e) {
      o.state = o.state.copyWith(guardando: false);
      if (!context.mounted) return;
      mostrarMensaje(
        context,
        e.codigo == 'CUPON_DUPLICADO'
            ? 'Ya existe un cupón con ese código'
            : e.message,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(_camposCuponProvider);
    final op = ref.watch(_opcionesCuponProvider);
    final o = ref.read(_opcionesCuponProvider.notifier);
    final pct = op.tipo == 'porcentaje';

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo cupón')),
      body: Form(
        key: c.form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: c.codigo,
              maxLength: 20,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Código',
                hintText: 'Ej. BIENVENIDA',
                helperText: 'De 4 a 20 letras o números',
              ),
              validator: (v) =>
                  RegExp(r'^[A-Za-z0-9]{4,20}$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'De 4 a 20 letras o números, sin espacios',
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: c.descripcion,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'porcentaje',
                  label: Text('Porcentaje'),
                  icon: Icon(Icons.percent),
                ),
                ButtonSegment(
                  value: 'monto',
                  label: Text('Monto fijo'),
                  icon: Icon(Icons.attach_money),
                ),
              ],
              selected: {op.tipo},
              onSelectionChanged: (s) => o.state = op.copyWith(tipo: s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: c.valor,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: pct ? 'Porcentaje de descuento' : 'Descuento',
                prefixText: pct ? null : '\$ ',
                suffixText: pct ? '%' : null,
              ),
              validator: (v) {
                final n = _num(v ?? '');
                if (n == null || n <= 0) return 'Escribe un valor';
                if (pct && n > 100) return 'Máximo 100 %';
                return null;
              },
            ),
            if (pct) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: c.maximo,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Descuento máximo (opcional)',
                  prefixText: '\$ ',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: c.minimo,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Compra mínima (opcional)',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: c.usos,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Usos en total (opcional)',
                helperText: 'Vacío = sin límite',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: op.soloPrimerPedido,
              onChanged: (v) => o.state = op.copyWith(soloPrimerPedido: v),
              title: const Text('Solo para el primer pedido del cliente'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(
                op.fin == null
                    ? 'Sin vencimiento'
                    : 'Vence el ${_fecha(op.fin!)}',
              ),
              trailing: op.fin == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      tooltip: 'Quitar vencimiento',
                      icon: const Icon(Icons.close),
                      onPressed: () => o.state = op.copyWith(quitarFin: true),
                    ),
              onTap: () async {
                final hoy = DateTime.now();
                final f = await showDatePicker(
                  context: context,
                  firstDate: hoy,
                  lastDate: hoy.add(const Duration(days: 365)),
                  initialDate: op.fin ?? hoy.add(const Duration(days: 30)),
                );
                if (f != null) o.state = o.state.copyWith(fin: f);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: op.guardando ? null : () => _guardar(context, ref),
              child: Text(op.guardando ? 'Guardando…' : 'Crear cupón'),
            ),
          ],
        ),
      ),
    );
  }
}
