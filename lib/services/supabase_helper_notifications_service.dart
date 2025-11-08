import 'dart:convert';
import 'package:cst_event_management/models/notification_model.dart';
import 'package:cst_event_management/services/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cst_event_management/config/supabase_config.dart';
import 'package:cst_event_management/helpers/supabase_auth_helper.dart';

class SupabaseHelperNotificationsService implements NotificationsService {

  @override
  Future<String?> getCurrentUserIdPublic() async {
    // Prefer auth helper (REST) to ensure we have a user even if Supabase client session isn't set
    final auth = await SupabaseAuthHelper.getInstance();
    final user = await auth.getCurrentUser();
    return user?.id;
  }

  @override
  Future<List<AppNotification>> getUserNotifications(String userId) async {
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

  @override
  Future<void> markNotificationAsRead(String id) async {
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

  @override
  Future<void> markAllNotificationsAsRead() async {
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

  @override
  Future<void> deleteNotification(String id) async {
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
}