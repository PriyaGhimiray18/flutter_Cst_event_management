// Part 2 of SupabaseHelper - Notification methods
import 'dart:convert';
import 'package:cst_event_management/helpers/supabase_auth_helper.dart';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../config/supabase_config.dart';

/// SupabaseHelper class for managing notifications and admin operations
class SupabaseHelper {
  // Private variables
  String _accessToken = '';

  /// Initialize the helper with access token
  void initialize(String accessToken) {
    _accessToken = accessToken;
  }

  /// Check if the user has a valid session
  bool hasValidSession() {
    return _accessToken.isNotEmpty;
  }

  /// Create a notification in the database
  Future<void> createNotification(AppNotification notification) async {
    try {
      final url = Uri.parse('${SupabaseConfig.restApiUrl}/notifications');
      final response = await http.post(
        url,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(notification.toJson()),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to create notification: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to create notification: $e');
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final url = Uri.parse('${SupabaseConfig.restApiUrl}/notifications?id=eq.$notificationId');
      final response = await http.patch(
        url,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'is_read': true, 'is_new': false}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to mark notification as read');
      }
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final url = Uri.parse('${SupabaseConfig.restApiUrl}/notifications?id=eq.$notificationId');
      final response = await http.delete(
        url,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to delete notification');
      }
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  /// Create a notification when an event status changes (approved/declined)
  Future<void> createEventStatusNotification(String eventId, String status) async {
    try {
      final url = Uri.parse('${SupabaseConfig.restApiUrl}/events?select=*&id=eq.$eventId');
      final response = await http.get(
        url,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonArray = jsonDecode(response.body) as List;

        if (jsonArray.isNotEmpty) {
          final eventJson = jsonArray[0];
          final requesterId = eventJson['requester_id'] as String? ?? '';
          final eventTitle = eventJson['title'] as String? ?? 'Your Event';

          if (requesterId.isNotEmpty) {
            final notificationType = status == 'approved' ? 'event_approved' : 'event_declined';
            final title = status == 'approved' ? 'Event Approved!' : 'Event Declined';
            final message = status == 'approved'
                ? 'Your event \'$eventTitle\' has been approved and is now live!'
                : 'Your event \'$eventTitle\' was declined.';

            final notification = AppNotification(
              userId: requesterId,
              eventId: eventId,
              eventTitle: eventTitle,
              type: notificationType,
              title: title,
              message: message,
            );

            await createNotification(notification);
          }
        }
      }
    } catch (e) {
      // Log error instead of using print
      rethrow;
    }
  }

  Future<void> promoteUserToAdmin(String userEmail) async {
    if (!hasValidSession()) {
      throw Exception('Admin not authenticated');
    }

    try {
      final rpcUrl = Uri.parse('${SupabaseConfig.rpcUrl}/admin_promote_user');
      final response = await http.post(
        rpcUrl,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({'target_email': userEmail}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to promote via RPC: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to promote user: $e');
    }
  }

  Future<List<User>> getAllUsers() async {
    if (!hasValidSession()) {
      throw Exception('Admin not authenticated');
    }

    try {
      final url = Uri.parse('${SupabaseConfig.rpcUrl}/get_all_users');
      final response = await http.post(
        url,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}), // Empty body for RPC function with no parameters
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = response.body;
        print('getAllUsers: Raw response body: $responseBody');
        
        if (responseBody.isEmpty) {
          print('getAllUsers: Empty response from RPC');
          return [];
        }
        
        try {
          final jsonArray = jsonDecode(responseBody) as List;
          print('getAllUsers: Received ${jsonArray.length} users from RPC');
          
          final users = <User>[];
          for (var json in jsonArray) {
            try {
              final user = User.fromJson(json as Map<String, dynamic>);
              users.add(user);
              print('getAllUsers: Parsed user - ${user.name} (${user.email}) - Role: ${user.role}');
            } catch (e, stackTrace) {
              print('Error parsing user JSON: $json');
              print('Error: $e');
              print('Stack trace: $stackTrace');
              // Continue with other users even if one fails
            }
          }
          
          print('getAllUsers: Successfully parsed ${users.length} out of ${jsonArray.length} users');
          return users;
        } catch (e, stackTrace) {
          print('Error decoding JSON response: $e');
          print('Response body: $responseBody');
          print('Stack trace: $stackTrace');
          throw Exception('Failed to parse users response: $e');
        }
      } else {
        print('getAllUsers: HTTP ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch users: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in getAllUsers: $e');
      throw Exception('Failed to fetch users: $e');
    }
  }

  Future<void> markAsInterested(String eventId) async {
    if (!hasValidSession()) throw Exception('Authentication required');

    final authHelper = await SupabaseAuthHelper.getInstance();
    final user = await authHelper.getCurrentUser();
    if (user == null) throw Exception('User not found');

    // Use on_conflict to avoid unique constraint errors on repeated interest
    final url = Uri.parse('${SupabaseConfig.restApiUrl}/event_participants?on_conflict=event_id,user_id');
    final response = await http.post(
      url,
      headers: {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal,resolution=ignore-duplicates',
      },
      body: jsonEncode({'event_id': eventId, 'user_id': user.id}),
    );

    // Treat 409 (duplicate) as success
    if (!((response.statusCode >= 200 && response.statusCode < 300) || response.statusCode == 409)) {
      throw Exception('Failed to mark as interested: ${response.body}');
    }
  }

  Future<void> markAsNotInterested(String eventId) async {
    if (!hasValidSession()) throw Exception('Authentication required');

    final authHelper = await SupabaseAuthHelper.getInstance();
    final user = await authHelper.getCurrentUser();
    if (user == null) throw Exception('User not found');

    final url = Uri.parse(
        '${SupabaseConfig.restApiUrl}/event_participants?event_id=eq.$eventId&user_id=eq.${user.id}');
    final response = await http.delete(
      url,
      headers: {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to mark as not interested: ${response.body}');
    }
  }

  Future<List<Event>> getUserInterestedEvents() async {
    if (!hasValidSession()) throw Exception('Authentication required');

    final authHelper = await SupabaseAuthHelper.getInstance();
    final user = await authHelper.getCurrentUser();
    if (user == null) throw Exception('User not found');

    // 1. Get event_ids the user is interested in
    final participantsUrl = Uri.parse(
        '${SupabaseConfig.restApiUrl}/event_participants?user_id=eq.${user.id}&select=event_id');
    final participantsResponse = await http.get(
      participantsUrl,
      headers: {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (participantsResponse.statusCode < 200 || participantsResponse.statusCode >= 300) {
      throw Exception('Failed to get interested event IDs: ${participantsResponse.body}');
    }

    final List<dynamic> participantsJson = jsonDecode(participantsResponse.body);
    if (participantsJson.isEmpty) return [];

    final eventIds = participantsJson.map((p) => p['event_id'] as String).toList();

    // 2. Fetch the full event details for those IDs
    final eventsUrl = Uri.parse(
        '${SupabaseConfig.restApiUrl}/events?select=id,title,description,location,category,date,time,image_url,status,requester_id,requester_name,requester_email,created_at&id=in.(${eventIds.join(',')})');
    final eventsResponse = await http.get(
      eventsUrl,
      headers: {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (eventsResponse.statusCode >= 200 && eventsResponse.statusCode < 300) {
      final List<dynamic> eventsJson = jsonDecode(eventsResponse.body);
      return eventsJson.map((json) => Event.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch interested events: ${eventsResponse.body}');
    }
  }

  Future<List<Event>> getEventsByStatus(String status) async {
    if (!hasValidSession()) {
      throw Exception('Authentication required');
    }

    try {
      final url = Uri.parse('${SupabaseConfig.restApiUrl}/events?select=id,title,description,location,category,date,time,image_url,status,requester_id,requester_name,requester_email,created_at&status=eq.$status');
      final response = await http.get(
        url,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonArray = jsonDecode(response.body) as List;
        return jsonArray.map((json) => Event.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch events: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch events: $e');
    }
  }

  Future<int> getEventParticipantCount(String eventId) async {
    if (!hasValidSession()) {
      throw Exception('Authentication required');
    }

    try {
      // Request 1 row and read total from Content-Range header
      final url = Uri.parse(
          '${SupabaseConfig.restApiUrl}/event_participants?event_id=eq.$eventId&select=event_id');
      final response = await http.get(
        url,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
          'Prefer': 'count=exact',
          'Range': '0-0',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final contentRange = response.headers['content-range'] ?? response.headers['content-Range'];
        if (contentRange != null && contentRange.contains('/')) {
          final totalStr = contentRange.split('/').last.trim();
          final total = int.tryParse(totalStr);
          if (total != null) return total;
        }
        // Fallback: parse body length
        try {
          final List<dynamic> bodyList = jsonDecode(response.body) as List<dynamic>;
          return bodyList.length; // will be 0 or 1 due to Range
        } catch (_) {
          return 0;
        }
      } else {
        print('Failed to get participant count for event $eventId: ${response.statusCode} ${response.body}');
        return 0;
      }
    } catch (e) {
      print('Error getting participant count: $e');
      return 0;
    }
  }

  /// Fetch participant counts for many events in a single request
  Future<Map<String, int>> getParticipantCountsForEvents(List<String> eventIds) async {
    if (eventIds.isEmpty) return {};
    if (!hasValidSession()) {
      throw Exception('Authentication required');
    }

    final Map<String, int> counts = {};
    for (final eventId in eventIds) {
      try {
        final count = await getEventParticipantCount(eventId);
        counts[eventId] = count;
      } catch (e) {
        print('Error getting participant count for event $eventId: $e');
        counts[eventId] = 0; // Default to 0 on error
      }
    }
    return counts;
  }

  Future<void> removePastEvents() async {
    if (!hasValidSession()) {
      throw Exception('Authentication required');
    }
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      final url = Uri.parse('${SupabaseConfig.restApiUrl}/events?date=lt.$yesterday');
      await http.delete(
        url,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
        },
      );
      // No error thrown if delete fails, as it's a cleanup task
    } catch (e) {
      print('Error removing past events: $e');
    }
  }

  Future<List<AppNotification>> getNotifications() async {
    if (!hasValidSession()) throw Exception('Authentication required');

    final authHelper = await SupabaseAuthHelper.getInstance();
    final user = await authHelper.getCurrentUser();
    if (user == null) throw Exception('User not found');

    final url = Uri.parse(
        '${SupabaseConfig.restApiUrl}/notifications?user_id=eq.${user.id}&order=created_at.desc');
    final response = await http.get(
      url,
      headers: {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final List<dynamic> json = jsonDecode(response.body);
      return json.map((json) => AppNotification.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch notifications: ${response.body}');
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    if (!hasValidSession()) throw Exception('Authentication required');

    final authHelper = await SupabaseAuthHelper.getInstance();
    final user = await authHelper.getCurrentUser();
    if (user == null) throw Exception('User not found');

    final url = Uri.parse(
        '${SupabaseConfig.restApiUrl}/notifications?user_id=eq.${user.id}');
    final response = await http.patch(
      url,
      headers: {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'is_read': true, 'is_new': false}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to mark all notifications as read');
    }
  }

  Future<void> updateEventStatus(String eventId, String newStatus) async {
    if (!hasValidSession()) {
      throw Exception('Authentication required');
    }
    try {
      final url = Uri.parse('${SupabaseConfig.restApiUrl}/events?id=eq.$eventId');
      final response = await http.patch(
        url,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({'status': newStatus}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to update event status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to update event status: $e');
    }
  }
}
