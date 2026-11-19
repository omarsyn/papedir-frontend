// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comunes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Coordenadas _$CoordenadasFromJson(Map<String, dynamic> json) => Coordenadas(
  lat: (json['lat'] as num).toDouble(),
  lng: (json['lng'] as num).toDouble(),
);

Map<String, dynamic> _$CoordenadasToJson(Coordenadas instance) =>
    <String, dynamic>{'lat': instance.lat, 'lng': instance.lng};

PaginaMeta _$PaginaMetaFromJson(Map<String, dynamic> json) => PaginaMeta(
  page: (json['page'] as num).toInt(),
  limit: (json['limit'] as num).toInt(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$PaginaMetaToJson(PaginaMeta instance) =>
    <String, dynamic>{
      'page': instance.page,
      'limit': instance.limit,
      'total': instance.total,
    };
