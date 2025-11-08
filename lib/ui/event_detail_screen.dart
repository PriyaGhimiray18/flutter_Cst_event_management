import 'package:cst_event_management/helpers/supabase_auth_helper.dart';
import 'package:cst_event_management/helpers/supabase_helper_part2.dart';
import 'package:cst_event_management/models/event.dart';
import 'package:flutter/material.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Event _event;
  bool _isAdmin = false;
  bool _isInterested = false;
  int _participantCount = 0;
  bool _loading = true;
  final SupabaseHelper _helper = SupabaseHelper();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _event = args['event'] as Event;
        _isAdmin = args['isAdmin'] ?? false;
        _initializeAndFetch();
      } else {
        setState(() {
          _loading = false;
        });
      }
    });
  }

  Future<void> _initializeAndFetch() async {
    try {
      final authHelper = await SupabaseAuthHelper.getInstance();
      final token = authHelper.getAccessToken();
      if (token != null && token.isNotEmpty) {
        _helper.initialize(token);
      }
    } catch (_) {}
    await _fetchEventDetails();
  }

  Future<void> _fetchEventDetails() async {
    setState(() {
      _loading = true;
    });
    try {
      final authHelper = await SupabaseAuthHelper.getInstance();
      final user = await authHelper.getCurrentUser();
      if (user != null) {
        final interestedEvents = await _helper.getUserInterestedEvents();
        _isInterested = interestedEvents.any((e) => e.id == _event.id);
      }
      _participantCount = await _helper.getEventParticipantCount(_event.id!);
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _toggleInterested() async {
    setState(() {
      _loading = true;
    });
    try {
      // Ensure helper is initialized before making requests
      if (!_helper.hasValidSession()) {
        final authHelper = await SupabaseAuthHelper.getInstance();
        final token = authHelper.getAccessToken();
        if (token != null && token.isNotEmpty) {
          _helper.initialize(token);
        }
      }
      // Only allow marking as interested
      if (!_isInterested) {
        await _helper.markAsInterested(_event.id!);
        // Refresh the count from server to avoid drift
        _participantCount = await _helper.getEventParticipantCount(_event.id!);
        setState(() {
          _isInterested = true;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

        final timeParts = _event.time.split(':');
    final time = timeParts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(timeParts[0]) ?? 0,
            minute: int.tryParse(timeParts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 0, minute: 0);

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: media.padding.bottom + 16),
        child: Column(
          children: [
            // Header with image, back button, optional status badge, title + category
            SizedBox(
              height: 280,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Header image/background
                  Image.network(
                    _event.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF90CAF9), Color(0xFF64B5F6)],
                        ),
                      ),
                    ),
                  ),
                  // Back button
                  Positioned(
                    top: media.padding.top + 8,
                    left: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Status badge (admin only)
                  if (_isAdmin)
                    Positioned(
                      top: media.padding.top + 12,
                      right: 12,
                      child: _StatusBadge(status: _event.status),
                    ),
                  // Bottom title and category chip
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _event.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                  color: Color(0x80000000),
                                  offset: Offset(2, 2),
                                  blurRadius: 4)
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _event.category,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content card (overlaps header by 40dp)
            Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 8,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Event Details Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.event,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Event Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Information Grid
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // Date & Time
                              _DetailRow(
                                icon: Icons.calendar_today,
                                iconColor: const Color(0xFF2196F3),
                                title: 'Date & Time',
                                value: _event.date,
                                subtitle: time.format(context),
                              ),
                              const Divider(height: 24),
                              // Location
                              _DetailRow(
                                icon: Icons.location_on,
                                iconColor: const Color(0xFFFF5722),
                                title: 'Location',
                                value: _event.location,
                              ),
                              const Divider(height: 24),
                              // Participants
                              _DetailRow(
                                icon: Icons.people,
                                iconColor: const Color(0xFF4CAF50),
                                title: 'Participants',
                                value: '$_participantCount ${_participantCount == 1 ? 'person' : 'people'} interested',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Description Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.description,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Description',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _event.description,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF555555),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Requester Information (Admin only)
                        if (_isAdmin) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F9FC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Requester Information',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF333333))),
                                const SizedBox(height: 8),
                                Text(
                                    'Requested by: ${_event.requesterName}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF333333))),
                                const SizedBox(height: 2),
                                Text(_event.requesterEmail,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF666666))),
                                const SizedBox(height: 4),
                                Text(
                                    'Submitted: ${_event.createdAt ?? 'N/A'}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF999999))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Actions (User or Admin)
                        if (_event.isApproved || _event.isDeclined)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isInterested ? null : _toggleInterested,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isInterested
                                    ? Colors.grey.shade300
                                    : theme.colorScheme.primary,
                                foregroundColor: _isInterested
                                    ? Colors.grey.shade600
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: _isInterested ? 0 : 2,
                              ),
                              icon: Icon(
                                _isInterested ? Icons.check_circle : Icons.favorite,
                                size: 20,
                              ),
                              label: Text(
                                _isInterested ? 'Already Interested' : 'Mark as Interested',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        else if (_isAdmin)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFF44336),
                                    side: const BorderSide(color: Color(0xFFF44336), width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.close, size: 20),
                                  label: const Text(
                                    'Decline',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CAF50),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  icon: const Icon(Icons.check_circle, size: 20),
                                  label: const Text(
                                    'Approve',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
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

class _StatusBadge extends StatelessWidget {
  final String status; // PENDING, APPROVED, DECLINED
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    late final Color bg;
    late final Color fg;
    late final String text;
    
    if (s == 'approved') {
      bg = const Color(0xFF4CAF50);
      fg = Colors.white;
      text = 'Approved';
    } else if (s == 'declined') {
      bg = const Color(0xFFF44336);
      fg = Colors.white;
      text = 'Declined';
    } else {
      bg = const Color(0xFFFFA000);
      fg = Colors.white;
      text = 'Pending';
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
