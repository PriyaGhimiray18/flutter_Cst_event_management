import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cst_event_management/ui/event_detail_screen.dart';
import 'package:cst_event_management/helpers/supabase_helper_part2.dart';
import 'package:cst_event_management/helpers/supabase_auth_helper.dart';
import 'package:cst_event_management/models/event.dart';
import 'package:cst_event_management/models/user.dart';
import 'package:cst_event_management/ui/widgets/event_card_admin.dart';

import 'package:cst_event_management/ui/widgets/event_card_user.dart';

enum AdminTab { pending, approved, rejected, analytics }
enum AdminScreen { dashboard, profile }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminTab _tab = AdminTab.pending;
  AdminScreen _currentScreen = AdminScreen.dashboard;
  SupabaseHelper? _helper;
  bool _loading = true;
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  int _totalParticipants = 0;
  String _welcomeName = '';
  String _userEmail = '';
  List<Event> _events = <Event>[];
  List<Event> _allEvents = <Event>[];
  User? _currentUser;

  // Analytics state
  bool _analyticsMonthly = true; // true = monthly, false = yearly
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      if (token.isEmpty) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final auth = await SupabaseAuthHelper.getInstance();
      final user = await auth.getCurrentUser();
      if (user == null || user.role != 'admin') {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }
      _welcomeName = user.name;
      _userEmail = user.email;
      _currentUser = user;

      final helper = SupabaseHelper();
      helper.initialize(token);
      _helper = helper;

      await _fetchAllEvents();
      await _refreshCounts();
      await _loadEventsForTab(_tab);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load admin data: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchAllEvents() async {
    if (_helper == null) return;
    final pending = await _helper!.getEventsByStatus('pending');
    final approved = await _helper!.getEventsByStatus('approved');
    final rejected = await _helper!.getEventsByStatus('rejected');
    _allEvents = [...pending, ...approved, ...rejected];

    int totalParticipants = 0;
    for (var event in approved) {
      final count = await getEventParticipantCount(event.id!);
      totalParticipants += count;
      event.attendees = count;
    }
    _totalParticipants = totalParticipants;
  }

  Future<int> getEventParticipantCount(String eventId) async {
    if (_helper == null) return 0;
    return await _helper!.getEventParticipantCount(eventId);
  }

  Future<void> _refreshCounts() async {
    if (_helper == null) return;
    final pending = await _helper!.getEventsByStatus('pending');
    final approved = await _helper!.getEventsByStatus('approved');
    final rejected = await _helper!.getEventsByStatus('rejected');
    setState(() {
      _pendingCount = pending.length;
      _approvedCount = approved.length;
      _rejectedCount = rejected.length;
    });
  }

  Future<void> _loadEventsForTab(AdminTab tab) async {
    if (tab == AdminTab.analytics) {
      await _fetchAllEvents();
      setState(() {
        _events = [];
      });
      return;
    }
    
    if (_helper == null) return;
    setState(() => _loading = true);
    final status = tab == AdminTab.pending
        ? 'pending'
        : tab == AdminTab.approved
            ? 'approved'
            : 'rejected';
    try {
      final list = await _helper!.getEventsByStatus(status);
      // Exclude past events from display (but keep counts aggregated from all)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final visibleList = list.where((e) {
        final dt = DateTime.tryParse(e.date);
        if (dt == null) return false;
        final eventDay = DateTime(dt.year, dt.month, dt.day);
        return !eventDay.isBefore(today);
      }).toList();
      if (status == 'approved') {
        for (var event in visibleList) {
          final count = await getEventParticipantCount(event.id!);
          event.attendees = count;
        }
      }
      // Sort events to show urgent ones first
      visibleList.sort((a, b) {
        if (a.isUrgent && !b.isUrgent) return -1;
        if (!a.isUrgent && b.isUrgent) return 1;
        return 0; // You can add secondary sort criteria here if needed
      });
      setState(() => _events = visibleList);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load events: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String eventId, String newStatus) async {
    if (_helper == null) return;
    setState(() => _loading = true);
    try {
      await _helper!.updateEventStatus(eventId, newStatus);
      await _helper!.createEventStatusNotification(eventId, newStatus);
      await _fetchAllEvents();
      await _refreshCounts();
      await _loadEventsForTab(_tab);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update event: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _performLogout() async {
    final auth = await SupabaseAuthHelper.getInstance();
    try {
      await auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onInterested(String eventId) async {
    if (_helper == null) return;
    setState(() => _loading = true);
    try {
      await _helper!.markAsInterested(eventId);
      // Refresh participant count for the specific event to reflect immediately
      final newCount = await _helper!.getEventParticipantCount(eventId);
      // Update in current tab list
      final int idx = _events.indexWhere((e) => e.id == eventId);
      if (idx != -1) {
        _events[idx].attendees = newCount;
      }
      // Update in all events used by analytics
      final int allIdx = _allEvents.indexWhere((e) => e.id == eventId);
      if (allIdx != -1) {
        _allEvents[allIdx].attendees = newCount;
      }
      // Recompute total participants for analytics (approved only)
      _totalParticipants = _allEvents
          .where((e) => e.isApproved)
          .fold<int>(0, (sum, e) => sum + (e.attendees));
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as interested: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Dashboard',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Manage event approvals and view analytics',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _currentScreen = _currentScreen == AdminScreen.dashboard
                  ? AdminScreen.profile
                  : AdminScreen.dashboard;
            }),
            icon: const Icon(Icons.person_outline, color: Colors.white),
          ),
        ],
      ),
      body: _currentScreen == AdminScreen.dashboard
          ? _buildDashboardView(context)
          : _buildProfileView(context),
    );
  }

  Widget _buildProfileView(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: const Color(0xFFF0F2F5),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: theme.colorScheme.primary,
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    child: const Icon(Icons.person, size: 48, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _welcomeName.isEmpty ? 'Admin' : _welcomeName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Administrator',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 1,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Personal Information',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.email_outlined, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), size: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _userEmail.isEmpty ? 'admin@cst.edu' : _userEmail,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.badge_outlined, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), size: 16),
                          const SizedBox(width: 12),
                          Text(
                            'Role: Administrator',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _showLogoutDialog,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardView(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: _pendingCount.toString(),
                  label: 'Pending',
                  icon: Icons.hourglass_empty,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: _approvedCount.toString(),
                  label: 'Approved',
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: _rejectedCount.toString(),
                  label: 'Rejected',
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(child: _buildTabButton(context, 'Pending', AdminTab.pending, false)),
              const SizedBox(width: 8),
              Expanded(child: _buildTabButton(context, 'Approved', AdminTab.approved, false)),
              const SizedBox(width: 8),
              Expanded(child: _buildTabButton(context, 'Rejected', AdminTab.rejected, false)),
              const SizedBox(width: 8),
              _buildTabButton(context, 'Analytics', AdminTab.analytics, true),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _tab == AdminTab.analytics
                  ? _buildAnalyticsView()
                  : _events.isEmpty
                      ? Center(child: Text('No events in this category.', style: TextStyle(color: Colors.grey.shade600)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _events.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final e = _events[index];
                            if (_tab == AdminTab.pending) {
                              return EventCardAdmin(
                                title: e.title,
                                subtitle: e.location,
                                statusChip: _StatusChip(status: e.status),
                                onApprove: () => _updateStatus(e.id ?? '', 'approved'),
                                onDecline: () => _updateStatus(e.id ?? '', 'rejected'),
                                onDetails: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const EventDetailScreen(),
                                      settings: RouteSettings(
                                        arguments: {
                                          'event': e,
                                          'isAdmin': true,
                                        },
                                      ),
                                    ),
                                  );
                                },
                                imageUrl: e.imageUrl,
                                isUrgent: e.isUrgent,
                              );
                            } else {
                              return EventCardUser(
                                category: e.category,
                                title: e.title,
                                description: '${e.attendees} ${e.attendees == 1 ? 'participant' : 'participants'}',
                                date: e.date,
                                time: e.time,
                                location: e.location,
                                organizer: e.requesterName ?? 'Unknown',
                                image: NetworkImage(e.imageUrl),
                                onInterested: () => _onInterested(e.id!),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const EventDetailScreen(),
                                      settings: RouteSettings(
                                        arguments: {
                                          'event': e,
                                          'isAdmin': true,
                                        },
                                      ),
                                    ),
                                  );
                                },
                                isUrgent: e.isUrgent,
                              );
                            }
                          },
                        ),
        ),
      ],
    );
  }

    Widget _buildAnalyticsView() {

      final theme = Theme.of(context);

  

      // Only approved events

      final approvedEvents = _allEvents.where((e) => e.isApproved).toList();

  

      // Available years from approved events

      final Set<int> years = approvedEvents.fold<Set<int>>(<int>{}, (set, e) {

        final dt = DateTime.tryParse(e.date);

        if (dt != null) set.add(dt.year);

        return set;

      });

      if (years.isEmpty) years.add(_selectedYear);

      if (!years.contains(_selectedYear)) {

        _selectedYear = years.reduce((a, b) => a > b ? a : b);

      }
      // Aggregations

      Map<String, int> categoryCounts = {};

      for (final e in approvedEvents) {

        categoryCounts[e.category] = (categoryCounts[e.category] ?? 0) + 1;

      }

      final categoryEntries = categoryCounts.entries.toList();

      // Monthly counts for selected year

      final List<int> monthlyCounts = List<int>.filled(12, 0);

      for (final e in approvedEvents) {

        final dt = DateTime.tryParse(e.date);

        if (dt != null && dt.year == _selectedYear) {

          monthlyCounts[dt.month - 1] += 1;

        }

      }

  

      // Yearly counts

      final Map<int, int> yearlyCounts = {};

      for (final e in approvedEvents) {

        final dt = DateTime.tryParse(e.date);

        if (dt != null) {

          yearlyCounts[dt.year] = (yearlyCounts[dt.year] ?? 0) + 1;

        }

      }

      final List<MapEntry<int, int>> yearlyEntries = yearlyCounts.entries.toList()

        ..sort((a, b) => a.key.compareTo(b.key));

  

      // Most popular approved event by attendees

      approvedEvents.sort((a, b) => b.attendees.compareTo(a.attendees));

      final mostPopularEvent = approvedEvents.isNotEmpty ? approvedEvents.first : null;

  

      final List<Color> categoryColors = [

        Colors.blue,

        Colors.green,

        Colors.orange,

        Colors.purple,

        Colors.red,

        Colors.teal,

        Colors.pink,

        Colors.indigo,

      ];

  

      return SingleChildScrollView(

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

        child: Column(

          children: [

            Row(

              children: [

                Expanded(

                  child: _AnalyticsStatCard(

                    label: 'Approved Events',

                    value: approvedEvents.length.toString(),

                    icon: Icons.check_circle_outline,

                    color: Colors.blue.shade700,

                  ),

                ),

                const SizedBox(width: 16),

                Expanded(

                  child: _AnalyticsStatCard(

                    label: 'Total Participants',

                    value: _totalParticipants.toString(),

                    icon: Icons.people,

                    color: Colors.green.shade700,

                  ),

                ),

              ],

            ),

  

            const SizedBox(height: 16),

  

            // Range selector: Monthly / Yearly and Year dropdown

            Card(

              elevation: 1,

              shadowColor: Colors.black12,

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

              child: Padding(

                padding: const EdgeInsets.all(12),

                child: Row(

                  children: [

                    ToggleButtons(

                      isSelected: [_analyticsMonthly, !_analyticsMonthly],

                      onPressed: (index) => setState(() => _analyticsMonthly = index == 0),

                      borderRadius: BorderRadius.circular(8),

                      children: const [

                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Monthly')),

                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Yearly')),

                      ],

                    ),

                    const Spacer(),

                    if (_analyticsMonthly)

                      DropdownButton<int>(

                        value: _selectedYear,

                        onChanged: (v) => setState(() => _selectedYear = v ?? _selectedYear),

                        items: (() {

                          final list = years.toList()..sort();

                          return list

                              .map((y) => DropdownMenuItem<int>(value: y, child: Text(y.toString())))

                              .toList();

                        })(),

                      ),

                  ],

                ),

              ),

            ),

  

            const SizedBox(height: 16),

  

            // Monthly or Yearly breakdown

            Card(

              elevation: 1,

              shadowColor: Colors.black12,

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

              child: Padding(

                padding: const EdgeInsets.all(16),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(_analyticsMonthly ? 'Approved Events by Month ($_selectedYear)' : 'Approved Events by Year',

                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),

                    const SizedBox(height: 12),

                    if (_analyticsMonthly)

                      ...List<Widget>.generate(12, (i) {

                        const monthNames = [

                          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'

                        ];

                        return _CategoryStatBar(

                          category: monthNames[i],

                          count: monthlyCounts[i],

                          total: approvedEvents.where((e) {

                            final dt = DateTime.tryParse(e.date);

                            return dt != null && dt.year == _selectedYear;

                          }).length,

                          color: categoryColors[i % categoryColors.length],

                        );

                      })

                    else

                      ...yearlyEntries.map((e) => _CategoryStatBar(

                            category: e.key.toString(),

                            count: e.value,

                            total: approvedEvents.length,

                            color: categoryColors[yearlyEntries.indexOf(e) % categoryColors.length],

                          )),

                  ],

                ),

              ),

            ),

  

            const SizedBox(height: 16),

  

            if (mostPopularEvent != null)

              Card(

                elevation: 2,

                shadowColor: Colors.amber.withOpacity(0.5),

                color: Colors.amber.shade50,

                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                child: Padding(

                  padding: const EdgeInsets.all(16),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text('👑 Most Popular Approved Event',

                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber.shade800)),

                      const SizedBox(height: 12),

                      Text(mostPopularEvent.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),

                      const SizedBox(height: 4),

                      Text(mostPopularEvent.category, style: theme.textTheme.bodyMedium),

                      const SizedBox(height: 8),

                      Row(

                        children: [

                          Icon(Icons.people, size: 16, color: Colors.grey.shade600),

                          const SizedBox(width: 4),

                          Text('${mostPopularEvent.attendees} participants', style: theme.textTheme.bodyMedium),

                        ],

                      ),

                    ],

                  ),

                ),

              ),

  

            const SizedBox(height: 16),

  

            // Category distribution among approved events

            Card(

              elevation: 1,

              shadowColor: Colors.black12,

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

              child: Padding(

                padding: const EdgeInsets.all(16),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text('Approved Events by Category', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),

                    const SizedBox(height: 12),

                    ...categoryEntries.map((entry) {

                      final index = categoryEntries.indexOf(entry);

                      return _CategoryStatBar(

                        category: entry.key,

                        count: entry.value,

                        total: approvedEvents.length,

                        color: categoryColors[index % categoryColors.length],

                      );

                    }),

                  ],

                ),

              ),

            ),

          ],

        ),

      );

    }

  

    Widget _buildTabButton(BuildContext context, String label, AdminTab tab, bool isIcon) {

      final bool selected = _tab == tab;

      if (isIcon) {

        return SizedBox(

          height: 40,

          width: 50,

          child: ElevatedButton(

            onPressed: () {

              setState(() => _tab = tab);

              _loadEventsForTab(tab);

            },

            style: ElevatedButton.styleFrom(

              foregroundColor: selected ? Colors.white : Theme.of(context).colorScheme.primary,

              backgroundColor: selected ? Theme.of(context).colorScheme.primary : Colors.white,

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

              padding: EdgeInsets.zero,

            ),

            child: const Icon(Icons.analytics_outlined, size: 20),

          ),

        );

      }

      

      return SizedBox(

        height: 40,

        child: ElevatedButton(

          onPressed: () {

            setState(() => _tab = tab);

            _loadEventsForTab(tab);

          },

          style: ElevatedButton.styleFrom(

            foregroundColor: selected ? Colors.white : Theme.of(context).colorScheme.primary,

            backgroundColor: selected ? Theme.of(context).colorScheme.primary : Colors.white,

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

            elevation: selected ? 2 : 0,

          ),

          child: Text(label),

        ),

      );

    }

  }

  

  class _StatCard extends StatelessWidget {

    final String value;

    final String label;

    final IconData icon;

    const _StatCard({required this.value, required this.label, required this.icon});

  

    @override

    Widget build(BuildContext context) {

      return Container(

        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(

          color: Colors.white.withOpacity(0.15),

          borderRadius: BorderRadius.circular(12),

        ),

        child: Row(

          children: [

            Icon(icon, color: Colors.white, size: 20),

            const SizedBox(width: 8),

            Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),

                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),

              ],

            ),

          ],

        ),

      );

    }

  }

  

  class _AnalyticsStatCard extends StatelessWidget {

    final String label;

    final String value;

    final IconData icon;

    final Color color;

  

    const _AnalyticsStatCard({required this.label, required this.value, required this.icon, required this.color});

  

    @override

    Widget build(BuildContext context) {

      return Container(

        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(

          color: color.withOpacity(0.1),

          borderRadius: BorderRadius.circular(12),

          border: Border.all(color: color.withOpacity(0.3)),

        ),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),

                Icon(icon, color: color, size: 20),

              ],

            ),

            const SizedBox(height: 8),

            Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),

          ],

        ),

      );

    }

  }

  

  class _CategoryStatBar extends StatelessWidget {

    final String category;

    final int count;

    final int total;

    final Color color;

  

    const _CategoryStatBar({required this.category, required this.count, required this.total, required this.color});

  

    @override

    Widget build(BuildContext context) {

      final double percentage = total > 0 ? count / total : 0;

      return Padding(

        padding: const EdgeInsets.only(bottom: 12.0),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                Text(category, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),

                Text(count.toString(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),

              ],

            ),

            const SizedBox(height: 6),

            LinearProgressIndicator(

              value: percentage,

              backgroundColor: Colors.grey.shade200,

              color: color,

            ),

          ],

        ),

      );

    }

  }

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color bg;
    late final Color fg;
    if (status == 'pending') {
      text = 'Pending';
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFFF9800);
    } else if (status == 'approved') {
      text = 'Approved';
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF4CAF50);
    } else {
      text = 'Rejected';
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFF44336);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusOverviewItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatusOverviewItem({required this.label, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 14))),
        Text(count.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
