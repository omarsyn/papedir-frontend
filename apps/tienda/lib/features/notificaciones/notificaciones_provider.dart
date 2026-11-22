import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/providers.dart';

/// Aviso guardado en la bandeja (todo push también queda aquí 60 días).
class Notificacion {
  const Notificacion({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    required this.datos,
    required this.leida,
    this.creadoEn,
  });

  final String id;
  final String titulo;
  final String cuerpo;
  final Map<String, String> datos;
  final bool leida;
  final DateTime? creadoEn;

  String? get pedidoId => datos['pedidoId'];

  factory Notificacion.fromJson(Map<String, dynamic> j) => Notificacion(
    id: '${j['id']}',
    titulo: '${j['titulo'] ?? ''}',
    cuerpo: '${j['cuerpo'] ?? ''}',
    datos: {
      for (final e in ((j['datos'] as Map?) ?? const {}).entries)
        '${e.key}': '${e.value}',
    },
    leida: (j['leida'] as bool?) ?? false,
    creadoEn: DateTime.tryParse('${j['creadoEn']}')?.toLocal(),
  );
}

class BandejaNotificaciones {
  const BandejaNotificaciones(this.lista, this.noLeidas);

  final List<Notificacion> lista;
  final int noLeidas;
}

Future<BandejaNotificaciones> _pedir(
  Ref ref, {
  bool soloNoLeidas = false,
  int limit = 50,
}) => conApiError(() async {
  final r = await ref
      .read(dioProvider)
      .get<Map<String, dynamic>>(
        '/notificaciones',
        queryParameters: {
          'limit': limit,
          if (soloNoLeidas) 'soloNoLeidas': true,
        },
      );
  final d = r.data ?? const {};
  return BandejaNotificaciones([
    for (final n in (d['data'] as List?) ?? const [])
      Notificacion.fromJson(Map<String, dynamic>.from(n as Map)),
  ], (d['noLeidas'] as num?)?.toInt() ?? 0);
});

/// Bandeja completa (pantalla de notificaciones).
final notificacionesProvider =
    FutureProvider.autoDispose<BandejaNotificaciones>((ref) => _pedir(ref));

/// Número para el globito de la campana; se revisa cada 30 s.
final noLeidasProvider = FutureProvider.autoDispose<int>((ref) async {
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final b = await _pedir(ref, soloNoLeidas: true, limit: 1);
  return b.noLeidas;
});

class NotificacionesAcciones {
  NotificacionesAcciones(this._ref);

  final Ref _ref;

  Future<void> leer(String id) async {
    try {
      await _ref.read(dioProvider).post<void>('/notificaciones/$id/leer');
    } catch (_) {}
    _refrescar();
  }

  Future<void> leerTodas() async {
    try {
      await _ref.read(dioProvider).post<void>('/notificaciones/leer-todas');
    } catch (_) {}
    _refrescar();
  }

  void _refrescar() {
    _ref.invalidate(notificacionesProvider);
    _ref.invalidate(noLeidasProvider);
  }
}

final notificacionesAccionesProvider = Provider<NotificacionesAcciones>(
  NotificacionesAcciones.new,
);
