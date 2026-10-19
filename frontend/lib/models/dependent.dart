class Dependent {
  final String id;
  final String name;
  final double commonThreshold;
  final bool isPrimary;
  final int safeMessagesCount;

  Dependent({
    required this.id,
    required this.name,
    required this.commonThreshold,
    required this.isPrimary,
    required this.safeMessagesCount,
  });

  factory Dependent.fromJson(Map<String, dynamic> json) {
    return Dependent(
      id: json['id'],
      name: json['name'],
      commonThreshold: json['common_threshold'].toDouble(),
      isPrimary: json['is_primary'],
      safeMessagesCount: json['safe_messages_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'common_threshold': commonThreshold,
      'is_primary': isPrimary,
      'safe_messages_count': safeMessagesCount,
    };
  }
}