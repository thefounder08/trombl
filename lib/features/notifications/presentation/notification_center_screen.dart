import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notification_routing.dart';
import '../../../core/theme/trombl_theme.dart';
import '../domain/notification_model.dart';
import '../providers/notification_providers.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: TromblColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    child: const Text('← back',
                        style: TextStyle(
                            color: TromblColors.textMuted, fontSize: 13)),
                  ),
                  notificationsAsync.maybeWhen(
                    data: (items) => items.any((n) => !n.isRead)
                        ? GestureDetector(
                            onTap: () async {
                              // Realtime reflects the is_read update on its
                              // own — no manual invalidation needed.
                              await ref
                                  .read(notificationRepositoryProvider)
                                  .markAllRead();
                            },
                            child: const Text('mark all read',
                                style: TextStyle(
                                    color: TromblColors.textMuted,
                                    fontSize: 13)),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 20, 22, 4),
              child: Text(
                'NOTIFICATIONS',
                style: TextStyle(
                  color: TromblColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: notificationsAsync.when(
                loading: () => const Center(
                  child: Text('one sec...',
                      style: TextStyle(
                          color: TromblColors.textMuted, fontSize: 13)),
                ),
                error: (_, _) => const Center(
                  child: Text("couldn't load ur notifications.",
                      style: TextStyle(
                          color: TromblColors.textMuted, fontSize: 13)),
                ),
                data: (items) => items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            "nothing here yet.\nwe'll nudge u when smth happens.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: TromblColors.textMuted,
                                fontSize: 14,
                                height: 1.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _NotificationTile(
                          notification: items[i],
                          onTap: () async {
                            if (!items[i].isRead) {
                              await ref
                                  .read(notificationRepositoryProvider)
                                  .markRead(items[i].id);
                            }
                            final route = resolveNotificationRoute(
                                items[i].kind, items[i].data);
                            if (context.mounted) context.go(route);
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unread
                ? TromblColors.fomo.withValues(alpha: 0.25)
                : TromblColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unread)
              Container(
                margin: const EdgeInsets.only(top: 5, right: 10),
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: TromblColors.fomo,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 17),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: unread
                          ? TromblColors.text
                          : TromblColors.textSub,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: TromblText.sans,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: const TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 12,
                      fontFamily: TromblText.sans,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: const TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 10,
                      fontFamily: TromblText.sans,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
