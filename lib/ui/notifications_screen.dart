import 'package:flutter/material.dart';
import 'package:cst_event_management/models/notification_model.dart';
import 'package:cst_event_management/services/notifications_service.dart';
import 'package:cst_event_management/ui/widgets/notification_card.dart';

class NotificationsScreen extends StatefulWidget {
  final NotificationsService service;

  const NotificationsScreen({super.key, required this.service});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = <AppNotification>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = await widget.service.getCurrentUserIdPublic();
      if (userId == null || userId.isEmpty) {
        setState(() {
          _notifications = <AppNotification>[];
          _loading = false;
        });
        return;
      }
      final items = await widget.service.getUserNotifications(userId);
      setState(() {
        _notifications = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load notifications';
        _loading = false;
      });
    }
  }

  int get _newCount => _notifications.where((n) => n.isNew).length;

  Future<void> _markAllAsRead() async {
    for (final n in _notifications) {
      if (n.isNew) {
        n.isNew = false;
        n.isRead = true;
        if (n.id != null && n.id!.isNotEmpty) {
          await widget.service.markNotificationAsRead(n.id!);
        }
      }
    }
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    }
  }

  Future<void> _remove(AppNotification n) async {
    final idx = _notifications.indexOf(n);
    if (idx < 0) return;
    if (n.id != null && n.id!.isNotEmpty) {
      await widget.service.deleteNotification(n.id!);
    }
    setState(() {
      _notifications.removeAt(idx);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_notifications.isEmpty) {
      return _EmptyState();
    }
    return Column(
      children: [
        if (_newCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$_newCount new'),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: _notifications.length,
            itemBuilder: (context, index) {
              final n = _notifications[index];
              return NotificationCard(
                icon: n.type == 'event_approved' ? Icons.check_circle : Icons.cancel,
                iconBackgroundColor: n.type == 'event_approved' ? Colors.green : Colors.red,
                title: n.title,
                message: n.message,
                timestamp: n.formattedTimestamp,
                isNew: n.isNew,
                onRemove: () => _remove(n),
                onTap: () async {
                  if (n.isNew) {
                    setState(() {
                      n.isNew = false;
                      n.isRead = true;
                    });
                    if (n.id != null && n.id!.isNotEmpty) {
                      await widget.service.markNotificationAsRead(n.id!);
                    }
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            'No notifications',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'You are all caught up! Check back later.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}