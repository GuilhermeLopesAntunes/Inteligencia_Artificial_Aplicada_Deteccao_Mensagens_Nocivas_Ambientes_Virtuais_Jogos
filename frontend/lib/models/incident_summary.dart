class IncidentContextMessage {
  final String text;
  final String senderId;
  final bool isFromMinor;
  final String timestamp;

  const IncidentContextMessage({
    required this.text,
    required this.senderId,
    required this.isFromMinor,
    required this.timestamp,
  });

  factory IncidentContextMessage.fromJson(Map<String, dynamic> json) {
    return IncidentContextMessage(
      text: (json['text'] ?? '').toString(),
      senderId: (json['sender_id'] ?? 'participante').toString(),
      isFromMinor: json['is_from_minor'] == true,
      timestamp: (json['timestamp'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'sender_id': senderId,
      'is_from_minor': isFromMinor,
      'timestamp': timestamp,
    };
  }
}

class IncidentStatusTransition {
  final String fromStatus;
  final String toStatus;
  final String? note;
  final String guardianName;
  final String changedAt;

  const IncidentStatusTransition({
    required this.fromStatus,
    required this.toStatus,
    this.note,
    required this.guardianName,
    required this.changedAt,
  });

  factory IncidentStatusTransition.fromJson(Map<String, dynamic> json) {
    return IncidentStatusTransition(
      fromStatus: (json['from_status'] ?? 'DETECTADO').toString(),
      toStatus: (json['to_status'] ?? '').toString(),
      note: json['note']?.toString(),
      guardianName: (json['guardian_name'] ?? 'Responsável').toString(),
      changedAt: (json['changed_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from_status': fromStatus,
      'to_status': toStatus,
      'note': note,
      'guardian_name': guardianName,
      'changed_at': changedAt,
    };
  }
}

class IncidentSummary {
  final String id;
  final String dependentId;
  final String dependentName;
  final String category;
  final String severity;
  final double confidence;
  final bool hasLink;
  final String detectedRole;
  final String status;
  final bool integrityMismatch;
  final bool escalated;
  final String preview;
  final String createdAt;
  final String roomType;
  final String mainMessageText;
  final String mainMessageSenderId;
  final String mainMessageHash;
  final List<IncidentContextMessage> contextBefore;
  final List<IncidentContextMessage> contextAfter;
  final List<IncidentStatusTransition> statusHistory;
  final List<String> allowedTransitions;

  IncidentSummary({
    required this.id,
    required this.dependentId,
    required this.dependentName,
    required this.category,
    required this.severity,
    required this.confidence,
    required this.hasLink,
    required this.detectedRole,
    required this.status,
    required this.integrityMismatch,
    required this.escalated,
    required this.preview,
    required this.createdAt,
    this.roomType = 'conversa',
    String? mainMessageText,
    this.mainMessageSenderId = 'adversario-99',
    this.mainMessageHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    this.contextBefore = const [],
    this.contextAfter = const [],
    this.statusHistory = const [],
    this.allowedTransitions = const [],
  }) : mainMessageText = mainMessageText ?? preview;

  factory IncidentSummary.fromJson(Map<String, dynamic> json) {
    final mainMsg =
        (json['message'] ?? json['main_message']) as Map<String, dynamic>?;
    final rawPreview = (json['preview'] ?? mainMsg?['text'] ?? '').toString();
    final rawIntegrityMismatch = json['integrity_mismatch'] == true ||
        (json.containsKey('integrity_valid') && json['integrity_valid'] == false);

    final beforeList = (json['context_before'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(IncidentContextMessage.fromJson)
        .toList();

    final afterList = (json['context_after'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(IncidentContextMessage.fromJson)
        .toList();

    final historyList = (json['status_history'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(IncidentStatusTransition.fromJson)
        .toList();

    final transitionsList = (json['allowed_transitions'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return IncidentSummary(
      id: (json['id'] ?? '').toString(),
      dependentId: (json['dependent_id'] ?? '').toString(),
      dependentName: (json['dependent_name'] ?? 'Dependente').toString(),
      category: (json['category'] ?? 'CIBERBULLYING').toString(),
      severity: (json['severity'] ?? 'COMUM').toString(),
      confidence: ((json['confidence'] ?? 0.0) as num).toDouble(),
      hasLink: json['has_link'] == true,
      detectedRole: (json['detected_role'] ?? 'VITIMA').toString(),
      status: (json['status'] ?? 'DETECTADO').toString(),
      integrityMismatch: rawIntegrityMismatch,
      escalated: json['escalated'] == true,
      preview: rawPreview,
      createdAt: (json['created_at'] ?? mainMsg?['timestamp'] ?? '').toString(),
      roomType: (json['room_type'] ?? 'conversa').toString(),
      mainMessageText: (mainMsg?['text'] ?? rawPreview).toString(),
      mainMessageSenderId: (mainMsg?['sender_id'] ?? 'adversario-99').toString(),
      mainMessageHash: (mainMsg?['message_hash'] ??
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
          .toString(),
      contextBefore: beforeList,
      contextAfter: afterList,
      statusHistory: historyList,
      allowedTransitions: transitionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dependent_id': dependentId,
      'dependent_name': dependentName,
      'category': category,
      'severity': severity,
      'confidence': confidence,
      'has_link': hasLink,
      'detected_role': detectedRole,
      'status': status,
      'integrity_mismatch': integrityMismatch,
      'escalated': escalated,
      'preview': preview,
      'created_at': createdAt,
      'room_type': roomType,
    };
  }
}