// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tables.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MovingTable _$MovingTableFromJson(Map<String, dynamic> json) => MovingTable(
  (json['table'] as List<dynamic>)
      .map((e) => (e as List<dynamic>).map((e) => (e as num).toInt()).toList())
      .toList(),
);

Map<String, dynamic> _$MovingTableToJson(MovingTable instance) =>
    <String, dynamic>{'table': instance.table};

PruningTable _$PruningTableFromJson(Map<String, dynamic> json) => PruningTable(
  (json['table'] as List<dynamic>).map((e) => (e as num).toInt()).toList(),
  (json['stride'] as num).toInt(),
);

Map<String, dynamic> _$PruningTableToJson(PruningTable instance) =>
    <String, dynamic>{'table': instance.table, 'stride': instance.stride};
