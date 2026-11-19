import 'package:json_annotation/json_annotation.dart';

part 'comunes.g.dart';

@JsonSerializable()
class Coordenadas {
  final double lat;
  final double lng;

  const Coordenadas({required this.lat, required this.lng});

  factory Coordenadas.fromJson(Map<String, dynamic> json) =>
      _$CoordenadasFromJson(json);
  Map<String, dynamic> toJson() => _$CoordenadasToJson(this);
}

@JsonSerializable()
class PaginaMeta {
  final int page;
  final int limit;
  final int total;

  const PaginaMeta({
    required this.page,
    required this.limit,
    required this.total,
  });

  factory PaginaMeta.fromJson(Map<String, dynamic> json) =>
      _$PaginaMetaFromJson(json);
  Map<String, dynamic> toJson() => _$PaginaMetaToJson(this);
}
