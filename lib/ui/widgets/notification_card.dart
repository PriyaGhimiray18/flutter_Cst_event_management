import 'package:flutter/material.dart';

class NotificationCard extends StatelessWidget {
  final IconData icon;
  final Color iconBackgroundColor;
  final String title;
  final String message;
  final String timestamp;
  final bool isNew;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const NotificationCard({
    super.key,
    required this.icon,
    required this.iconBackgroundColor,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isNew = false,
    this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon background
              Card(
                elevation: 0,
                color: iconBackgroundColor,
                shape: const CircleBorder(),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timestamp,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),

              // New indicator and remove button
              if (isNew)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              if (isNew) const SizedBox(width: 8),
              IconButton(
                onPressed: onRemove,
                tooltip: 'Remove',
                icon: Icon(Icons.delete_outline, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
