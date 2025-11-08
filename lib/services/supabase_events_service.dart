import 'dart:io';

import 'package:cst_event_management/models/event_model.dart';
import 'package:cst_event_management/services/events_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class SupabaseEventsService implements EventsService {
  final supabase.SupabaseClient _client;

  SupabaseEventsService() : _client = supabase.Supabase.instance.client;

  @override
  Future<User> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }
    return User(id: user.id, name: user.userMetadata?['name'] ?? '', email: user.email ?? '');
  }

  @override
  Future<String?> uploadImage(String localPathOrUrl) async {
    final file = File(localPathOrUrl);
    final path = file.path.split('/').last;
    final response = await _client.storage.from('event-images').upload(
          path,
          file,
          fileOptions: supabase.FileOptions(cacheControl: '3600', upsert: false),
        );
    return response;
  }

  @override
  Future<EventModel> createEvent(EventModel event) async {
    final response = await _client.from('events').insert(event.toJson()).select();
    return EventModel.fromJson(response[0]);
  }
}
