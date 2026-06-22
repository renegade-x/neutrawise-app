// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leaderboard_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LeaderboardEntry _$LeaderboardEntryFromJson(Map<String, dynamic> json) =>
    _LeaderboardEntry(
      userId: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      xp: (json['xp'] as num).toInt(),
      level: (json['level'] as num).toInt(),
      rank: (json['rank'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LeaderboardEntryToJson(_LeaderboardEntry instance) =>
    <String, dynamic>{
      'id': instance.userId,
      'name': instance.name,
      'avatar_url': instance.avatarUrl,
      'xp': instance.xp,
      'level': instance.level,
      'rank': instance.rank,
    };
