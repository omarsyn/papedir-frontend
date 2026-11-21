class Vehiculo {
  final String tipo; // 'moto' | 'bicicleta' | 'auto'
  final String? marca;
  final String? modelo;
  final String color;
  final String? placa; // Obligatoria salvo en bicicleta

  const Vehiculo({
    required this.tipo,
    this.marca,
    this.modelo,
    required this.color,
    this.placa,
  });

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      tipo: json['tipo'] as String,
      marca: json['marca'] as String?,
      modelo: json['modelo'] as String?,
      color: json['color'] as String,
      placa: json['placa'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo': tipo,
      if (marca != null && marca!.trim().isNotEmpty) 'marca': marca!.trim(),
      if (modelo != null && modelo!.trim().isNotEmpty) 'modelo': modelo!.trim(),
      'color': color.trim(),
      if (tipo != 'bicicleta' && placa != null && placa!.trim().isNotEmpty)
        'placa': placa!.trim().toUpperCase(),
    };
  }
}