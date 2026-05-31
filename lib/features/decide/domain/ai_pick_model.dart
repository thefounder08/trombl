/// In-memory model for an AI-generated pick. Plain Dart — no code-gen needed.
class AiPick {
  const AiPick({
    required this.id,
    required this.userId,
    this.sessionId,
    required this.vibe,
    required this.pickText,
    required this.reasonText,
    this.tag = 'solo',
    this.rerolled = false,
    this.accepted = false,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String? sessionId;
  final String vibe;
  final String pickText;
  final String reasonText;
  final String tag;
  final bool rerolled;
  final bool accepted;
  final DateTime? createdAt;

  factory AiPick.fromJson(Map<String, dynamic> json) => AiPick(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        sessionId: json['session_id'] as String?,
        vibe: json['vibe'] as String,
        pickText: json['pick_text'] as String,
        reasonText: json['reason_text'] as String,
        tag: json['tag'] as String? ?? 'solo',
        rerolled: json['rerolled'] as bool? ?? false,
        accepted: json['accepted'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  AiPick copyWith({String? id, bool? rerolled, bool? accepted}) => AiPick(
        id: id ?? this.id,
        userId: userId,
        sessionId: sessionId,
        vibe: vibe,
        pickText: pickText,
        reasonText: reasonText,
        tag: tag,
        rerolled: rerolled ?? this.rerolled,
        accepted: accepted ?? this.accepted,
        createdAt: createdAt,
      );
}
