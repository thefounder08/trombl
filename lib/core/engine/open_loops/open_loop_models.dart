/// An unfinished commitment the user has acknowledged.
class OpenLoop {
  const OpenLoop({
    required this.id,
    required this.userId,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.category,
  });

  factory OpenLoop.fromJson(Map<String, dynamic> json) => OpenLoop(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        status: json['status'] as String? ?? 'open',
        priority: (json['priority'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.parse(json['created_at'] as String),
        category: json['category'] as String?,
      );

  final String id;
  final String userId;
  final String title;
  final String status;   // 'open' | 'done' | 'ignored'
  final int priority;    // 1=low … 3=high
  final DateTime createdAt;
  final String? category;

  bool get isOpen => status == 'open';

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'status': status,
        'priority': priority,
        'created_at': createdAt.toIso8601String(),
        if (category != null) 'category': category,
      };
}
