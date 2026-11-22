import 'enums.dart';

class MensajePedido {
  final String id;
  final String pedidoId;
  final String autorId;
  final Rol autorRol;
  final String texto;
  final DateTime creadoEn;

  const MensajePedido({
    required this.id,
    required this.pedidoId,
    required this.autorId,
    required this.autorRol,
    required this.texto,
    required this.creadoEn,
  });

  factory MensajePedido.fromJson(Map<String, dynamic> json) {
    final rolRaw = (json['autorRol'] ?? '').toString().toLowerCase();
    final rol = Rol.values.firstWhere(
      (r) => r.name.toLowerCase() == rolRaw,
      orElse: () => Rol.cliente,
    );

    return MensajePedido(
      id: (json['id'] ?? '').toString(),
      pedidoId: (json['pedidoId'] ?? '').toString(),
      autorId: (json['autorId'] ?? '').toString(),
      autorRol: rol,
      texto: (json['texto'] ?? '').toString(),
      creadoEn:
          DateTime.tryParse((json['creadoEn'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pedidoId': pedidoId,
    'autorId': autorId,
    'autorRol': autorRol.name,
    'texto': texto,
    'creadoEn': creadoEn.toIso8601String(),
  };

  String get etiquetaRol {
    switch (autorRol.name) {
      case 'repartidor':
        return 'Repartidor';
      case 'soporte':
      case 'admin':
        return 'Soporte';
      default:
        return 'Cliente';
    }
  }
}