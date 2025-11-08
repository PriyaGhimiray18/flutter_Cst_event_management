import 'package:flutter/material.dart';
import '../models/notification_model.dart';

class NotificationListItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;
  final VoidCallback? onRemove;

  const NotificationListItem({
    super.key,
    required this.notification,
    this.onTap,
    this.onMarkAsRead,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        if (!notification.isRead || notification.isNew) {
          onMarkAsRead?.call();
        }
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: notification.backgroundColor.withOpacity(0.15),
                  radius: 24,
                  child: Icon(
                    notification.iconData,
                    color: notification.backgroundColor,
                  ),
                ),
                if (notification.isNew)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        notification.formattedTimestamp,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (!notification.isNew)
                        TextButton.icon(
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove'),
                        )
                      else
                        Container(),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


