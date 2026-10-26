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
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Dependente').toString(),
      commonThreshold: ((json['common_threshold'] ?? 0.50) as num).toDouble(),
      isPrimary: json['is_primary'] != false,
      safeMessagesCount: ((json['safe_messages_count'] ?? 0) as num).toInt(),
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