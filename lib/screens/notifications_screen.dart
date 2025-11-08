import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../widgets/notification_list_item.dart';
import '../config/supabase_config.dart';
import '../helpers/supabase_auth_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

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

  Future<String?> _getCurrentUserIdPublic() async {
    final auth = await SupabaseAuthHelper.getInstance();
    final user = await auth.getCurrentUser();
    return user?.id;
  }

  Future<List<AppNotification>> _getUserNotifications(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      return <AppNotification>[];
    }
    final url = Uri.parse(
        '${SupabaseConfig.restApiUrl}/notifications?user_id=eq.$userId&order=created_at.desc');
    final resp = await http.get(
      url,
      headers: {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $token',
      },
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final List<dynamic> json = jsonDecode(resp.body) as List<dynamic>;
      return json
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to fetch notifications');
    }
  }

  Future<void> _markNotificationAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) return;
    final url = Uri.parse('${SupabaseConfig.restApiUrl}/notifications?id=eq.$id');
    await http.patch(
      url,
      headers: {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'is_read': true, 'is_new': false}),
    );
  }

  Future<void> _markAllNotificationsAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) return;

    final auth = await SupabaseAuthHelper.getInstance();
    final user = await auth.getCurrentUser();
    if (user == null) return;

    final url = Uri.parse('${SupabaseConfig.restApiUrl}/notifications?user_id=eq.${user.id}');
    await http.patch(
      url,
      headers: {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'is_read': true, 'is_new': false}),
    );
  }

  Future<void> _deleteNotification(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) return;
    final url = Uri.parse('${SupabaseConfig.restApiUrl}/notifications?id=eq.$id');
    final response = await http.delete(
      url,
      headers: {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to delete notification');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = await _getCurrentUserIdPublic();
      if (userId == null || userId.isEmpty) {
        setState(() {
          _notifications = <AppNotification>[];
          _loading = false;
        });
        return;
      }
      final items = await _getUserNotifications(userId);
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

  Future<void> _handleMarkAllAsRead() async {
    try {
      await _markAllNotificationsAsRead();
      setState(() {
        for (final n in _notifications) {
          n.isNew = false;
          n.isRead = true;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark all as read')),
        );
      }
    }
  }

  Future<void> _remove(AppNotification n) async {
    final idx = _notifications.indexOf(n);
    if (idx < 0) return;
    try {
      if (n.id != null && n.id!.isNotEmpty) {
        await _deleteNotification(n.id!);
      }
      setState(() {
        _notifications.removeAt(idx);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete notification')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _handleMarkAllAsRead,
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
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
              return NotificationListItem(
                notification: n,
                onTap: () {
                  if (n.eventId != null && n.eventId!.isNotEmpty) {
                    Navigator.of(context).pushNamed(
                      '/eventDetail',
                      arguments: {
                        'event_id': n.eventId,
                        'event_title': n.eventTitle,
                      },
                    );
                  }
                },
                onMarkAsRead: () async {
                  if (n.isNew) {
                    setState(() {
                      n.isNew = false;
                      n.isRead = true;
                    });
                    if (n.id != null && n.id!.isNotEmpty) {
                      await _markNotificationAsRead(n.id!);
                    }
                  }
                },
                onRemove: () => _remove(n),
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