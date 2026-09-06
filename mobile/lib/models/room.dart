enum MediaSourceType { youtube, local, screenShare }

extension MediaSourceTypeX on MediaSourceType {
  String get wire => switch (this) {
        MediaSourceType.youtube => 'youtube',
        MediaSourceType.local => 'local',
        MediaSourceType.screenShare => 'screen_share',
      };

  String get label => switch (this) {
        MediaSourceType.youtube => 'YouTube Link',
        MediaSourceType.local => 'From Device',
        MediaSourceType.screenShare => 'Screen Share',
      };

  static MediaSourceType fromWire(String value) => switch (value) {
        'local' => MediaSourceType.local,
        'screen_share' => MediaSourceType.screenShare,
        _ => MediaSourceType.youtube,
      };
}

class Room {
  final String id;
  final String code;
  final String name;
  final String hostUserId;
  final String hostName;
  final MediaSourceType sourceType;
  final String? sourceValue;

  const Room({
    required this.id,
    required this.code,
    required this.name,
    required this.hostUserId,
    required this.hostName,
    required this.sourceType,
    this.sourceValue,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        hostUserId: json['hostUserId'] as String,
        hostName: json['hostName'] as String? ?? 'Host',
        sourceType: MediaSourceTypeX.fromWire(json['sourceType'] as String? ?? 'youtube'),
        sourceValue: json['sourceValue'] as String?,
      );
}
