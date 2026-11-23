import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/tienda_activa.dart';
import '../../core/widgets/mensajes.dart';
import '../../core/widgets/vista_async.dart';

/// Turno de atención. `dia`: 0 = domingo … 6 = sábado (hora de Celaya).
class Turno {
  const Turno({required this.dia, required this.abre, required this.cierra});

  final int dia;
  final String abre;
  final String cierra;

  factory Turno.fromJson(Map<String, dynamic> j) => Turno(
    dia: (j['dia'] as num?)?.toInt() ?? 0,
    abre: '${j['abre']}',
    cierra: '${j['cierra']}',
  );

  Map<String, dynamic> toJson() => {'dia': dia, 'abre': abre, 'cierra': cierra};
}

class HorarioEditable {
  const HorarioEditable({
    required this.usarHorario,
    required this.turnos,
    this.abiertaAhora,
    this.cambios = false,
    this.guardando = false,
  });

  final bool usarHorario;
  final List<Turno> turnos;
  final bool? abiertaAhora;
  final bool cambios;
  final bool guardando;

  HorarioEditable copyWith({
    bool? usarHorario,
    List<Turno>? turnos,
    bool? cambios,
    bool? guardando,
  }) => HorarioEditable(
    usarHorario: usarHorario ?? this.usarHorario,
    turnos: turnos ?? this.turnos,
    abiertaAhora: abiertaAhora,
    cambios: cambios ?? this.cambios,
    guardando: guardando ?? this.guardando,
  );

  factory HorarioEditable.fromJson(Map<String, dynamic> j) => HorarioEditable(
    usarHorario: (j['usarHorario'] as bool?) ?? false,
    turnos: [
      for (final t in (j['turnos'] as List?) ?? const [])
        Turno.fromJson(asMapa(t)),
    ],
    abiertaAhora: j['abiertaAhora'] as bool?,
  );
}

/// Horario semanal de la sucursal (GET/PUT /tiendas/mia/horario).
class HorarioNotifier extends AutoDisposeAsyncNotifier<HorarioEditable> {
  @override
  Future<HorarioEditable> build() async {
    ref.watch(tiendaActivaProvider);
    final r = await conApiError(
      () => ref
          .read(dioProvider)
          .get<Map<String, dynamic>>('/tiendas/mia/horario'),
    );
    return HorarioEditable.fromJson(r.data ?? const {});
  }

  void _cambiar(HorarioEditable h) => state = AsyncData(h);

  void usarHorario(bool v) =>
      _cambiar(state.requireValue.copyWith(usarHorario: v, cambios: true));

  void agregar(Turno t) {
    final h = state.requireValue;
    _cambiar(h.copyWith(turnos: [...h.turnos, t], cambios: true));
  }

  void quitar(Turno t) {
    final h = state.requireValue;
    _cambiar(
      h.copyWith(
        turnos: h.turnos.where((x) => !identical(x, t)).toList(),
        cambios: true,
      ),
    );
  }

  Future<void> guardar() async {
    final h = state.requireValue;
    _cambiar(h.copyWith(guardando: true));
    try {
      final r = await conApiError(
        () => ref
            .read(dioProvider)
            .put<Map<String, dynamic>>(
              '/tiendas/mia/horario',
              data: {
                'usarHorario': h.usarHorario,
                'turnos': [for (final t in h.turnos) t.toJson()],
              },
            ),
      );
      _cambiar(HorarioEditable.fromJson(r.data ?? const {}));
    } catch (_) {
      _cambiar(h.copyWith(guardando: false));
      rethrow;
    }
  }
}

final horarioProvider =
    AsyncNotifierProvider.autoDispose<HorarioNotifier, HorarioEditable>(
      HorarioNotifier.new,
    );

const _dias = [
  (1, 'Lunes'),
  (2, 'Martes'),
  (3, 'Miércoles'),
  (4, 'Jueves'),
  (5, 'Viernes'),
  (6, 'Sábado'),
  (0, 'Domingo'),
];

String _hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class HorarioScreen extends ConsumerWidget {
  const HorarioScreen({super.key});

  Future<void> _agregar(BuildContext context, WidgetRef ref, int dia) async {
    final abre = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Hora en que abre',
    );
    if (abre == null || !context.mounted) return;
    final cierra = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 22, minute: 0),
      helpText: 'Hora en que cierra (00:00 = medianoche)',
    );
    if (cierra == null) return;
    var fin = _hhmm(cierra);
    if (fin == '00:00') fin = '24:00';
    ref
        .read(horarioProvider.notifier)
        .agregar(Turno(dia: dia, abre: _hhmm(abre), cierra: fin));
  }

  Future<void> _guardar(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(horarioProvider.notifier).guardar();
      if (context.mounted) mostrarMensaje(context, 'Horario guardado');
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final horario = ref.watch(horarioProvider);
    final h = horario.valueOrNull;
    final notifier = ref.read(horarioProvider.notifier);
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Horario'),
        actions: [
          if (h != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonal(
                onPressed: !h.cambios || h.guardando
                    ? null
                    : () => _guardar(context, ref),
                child: Text(h.guardando ? 'Guardando…' : 'Guardar'),
              ),
            ),
        ],
      ),
      body: VistaAsync<HorarioEditable>(
        valor: horario,
        onReintentar: () => ref.invalidate(horarioProvider),
        builder: (h) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                value: h.usarHorario,
                onChanged: notifier.usarHorario,
                title: const Text('Recibir pedidos solo en mi horario'),
                subtitle: Text(
                  h.usarHorario
                      ? 'Fuera de estos turnos la tienda aparece cerrada.'
                      : 'Apagado: solo cuenta el interruptor de abrir/cerrar.',
                ),
              ),
            ),
            if (h.abiertaAhora != null && !h.cambios)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: h.abiertaAhora! ? Colors.green : esquema.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      h.abiertaAhora!
                          ? 'Ahora mismo recibes pedidos'
                          : 'Ahora mismo no recibes pedidos',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            for (final (dia, nombre) in _dias)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nombre,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _agregar(context, ref, dia),
                            icon: const Icon(Icons.add),
                            label: const Text('Turno'),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final t in h.turnos.where((t) => t.dia == dia))
                            InputChip(
                              label: Text('${t.abre} – ${t.cierra}'),
                              onDeleted: () => notifier.quitar(t),
                            ),
                          if (!h.turnos.any((t) => t.dia == dia))
                            Text(
                              'Cerrado',
                              style: TextStyle(color: esquema.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
