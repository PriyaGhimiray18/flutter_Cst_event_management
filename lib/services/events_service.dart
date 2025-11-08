import '../models/event_model.dart';

abstract class EventsService {
  Future<User> getCurrentUser();
  Future<String?> uploadImage(String localPathOrUrl);
  Future<EventModel> createEvent(EventModel event);
}

class User {
  final String id;
  final String name;
  final String email;
  User({required this.id, required this.name, required this.email});
}

class MockEventsService implements EventsService {
  int _id = 1;

  @override
  Future<User> getCurrentUser() async {
    return User(id: 'u_1', name: 'John Doe', email: 'john@example.com');
  }

  @override
  Future<String?> uploadImage(String localPathOrUrl) async {
    // Pretend upload succeeds and returns a CDN URL
    return 'https://cdn.example.com/${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  @override
  Future<EventModel> createEvent(EventModel event) async {
    return EventModel(
      id: (_id++).toString(),
      title: event.title,
      description: event.description,
      location: event.location,
      category: event.category,
      date: event.date,
      time: event.time,
      imageUrl: event.imageUrl,
      status: event.status,
      requesterId: event.requesterId,
      requesterName: event.requesterName,
      requesterEmail: event.requesterEmail,
    );
  }
}


