import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cst_event_management/ui/widgets/event_card_user.dart';
import 'package:cst_event_management/helpers/supabase_helper_part2.dart';
import 'package:cst_event_management/helpers/supabase_auth_helper.dart';
import 'package:cst_event_management/models/event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseHelper _helper = SupabaseHelper();
  List<Event> _allEvents = <Event>[];
  List<Event> _visibleEvents = <Event>[];
  List<Event> _interestedEvents = <Event>[];
  int _notificationCount = 0;
  bool _loading = true;

  bool _browseSelected = true;
  String _selectedCategory = 'All';
  bool _showScrollToTop = false;

  final List<String> _categories = [
    'All',
    'Sports',
    'Culture',
    'Literature',
    'Social Events',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final auth = await SupabaseAuthHelper.getInstance();
      if (!auth.hasValidSession()) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final user = await auth.getCurrentUser();
      _helper.initialize(token);
      await _loadEvents();
      await _fetchNotificationCount();

      if (user != null) {
        Supabase.instance.client
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', user.id)
            .listen((_) => _fetchNotificationCount());
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _fetchNotificationCount() async {
    try {
      final notifications = await _helper.getNotifications();
      if (mounted) {
        setState(() {
          _notificationCount = notifications.where((n) => n.isNew).length;
        });
      }
    } catch (e) {
      // Do not show snackbar for notification count fetch errors
    }
  }

  void _onScroll() {
    final show = _scrollController.offset > 300;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectTab(bool browse) async {
    setState(() {
      _browseSelected = browse;
      _loading = true;
    });
    await _loadEvents();
  }

  void _selectCategory(String c) {
    setState(() => _selectedCategory = c);
    _applyFilters();
  }
  
  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      if (_browseSelected) {
        final list = await _helper.getEventsByStatus('approved');
        await _fetchParticipantCounts(list);
        _allEvents = list;
      } else {
        final list = await _helper.getUserInterestedEvents();
        await _fetchParticipantCounts(list);
        _interestedEvents = list;
      }
      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load events: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  Future<void> _fetchParticipantCounts(List<Event> events) async {
    for (var event in events) {
      if (event.id != null) {
        final count = await _helper.getEventParticipantCount(event.id!);
        if (mounted) {
          setState(() {
            event.attendees = count;
          });
        }
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    List<Event> sourceList = _browseSelected ? _allEvents : _interestedEvents;

    List<Event> filtered = sourceList;

    // Keep only events that are today or in the future
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    filtered = filtered.where((e) {
      final parsed = DateTime.tryParse(e.date);
      if (parsed == null) return false; // Exclude if date is invalid
      final eventDay = DateTime(parsed.year, parsed.month, parsed.day);
      return !eventDay.isBefore(today);
    }).toList();
    if (_selectedCategory != 'All') {
      filtered = filtered.where((e) => e.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
    }
    if (query.isNotEmpty) {
      filtered = filtered.where((e) => e.title.toLowerCase().contains(query) || e.description.toLowerCase().contains(query)).toList();
    }
    setState(() => _visibleEvents = filtered);
  }

  Future<void> _onInterested(String eventId) async {
    try {
      await _helper.markAsInterested(eventId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are now interested in this event!'), backgroundColor: Colors.green),
        );
      }
      // Refresh counts
      await _loadEvents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Modern App Bar
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, Guest!',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Discover amazing events',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                                                Stack(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pushNamed(context, '/notifications').then((_) => _fetchNotificationCount()),
                              icon: const Icon(Icons.notifications_outlined),
                              color: Colors.white,
                              iconSize: 26,
                            ),
                            if (_notificationCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '$_notificationCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pushNamed(context, '/profile'),
                          icon: const Icon(Icons.person_outline),
                          color: Colors.white,
                          iconSize: 26,
                        ),
                        IconButton(
                          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
                          icon: const Icon(Icons.logout),
                          color: Colors.white,
                          iconSize: 26,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search events...',
                          prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tabs
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: _browseSelected
                          ? ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Browse'),
                            )
                          : OutlinedButton(
                              onPressed: () => _selectTab(true),
                              child: const Text('Browse'),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: !_browseSelected
                          ? ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Interested'),
                            )
                          : OutlinedButton(
                              onPressed: () => _selectTab(false),
                              child: const Text('Interested'),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Column(
                children: [
                  // Category Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: _categories.map((c) {
                        final selected = c == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: selected,
                            onSelected: (_) => _selectCategory(c),
                            backgroundColor: Colors.white,
                            selectedColor: theme.colorScheme.primary,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : theme.colorScheme.primary,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Create Event Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/create'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Create New Event'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Events list
                  Expanded(
                    child: Stack(
                      children: [
                        if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else if (_visibleEvents.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_busy,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No events yet',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Check back later or create one!',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            controller: _scrollController,
                            itemCount: _visibleEvents.length,
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                            separatorBuilder: (_, __) => const SizedBox(height: 0),
                            itemBuilder: (context, index) {
                              _visibleEvents.sort((a, b) => b.attendees.compareTo(a.attendees));
                              final e = _visibleEvents[index];
                              final bool isPopular = _visibleEvents.indexOf(e) < 3;

                              return EventCardUser(
                                category: e.category,
                                title: e.title,
                                description: '${e.attendees} ${e.attendees == 1 ? 'participant' : 'participants'}',
                                date: e.date,
                                time: e.time,
                                location: e.location,
                                organizer: e.requesterName ?? 'Unknown',
                                image: NetworkImage(e.imageUrl!),
                                onInterested: () => _onInterested(e.id!),
                                onTap: () => Navigator.pushNamed(context, '/detail', arguments: {'event': e, 'isAdmin': false}),
                                isPopular: isPopular,
                              );
                            },
                          ),

                        if (_showScrollToTop)
                          Positioned(
                            right: 20,
                            bottom: 20,
                            child: FloatingActionButton(
                              onPressed: () => _scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                              ),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              child: const Icon(Icons.arrow_upward),
                            ),
                          ),
                      ],
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
}
