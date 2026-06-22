import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../domain/notification_model.dart';

class NotificationRepository {
  NotificationRepository(this._client);
  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<List<AppNotification>> recentNotifications({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => AppNotification.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> unreadCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    try {
      final rows = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', uid)
          .eq('is_read', false);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await _client.from('notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', notificationId);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (_) {}
  }
}
