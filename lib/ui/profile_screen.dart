import 'package:flutter/material.dart';
import '../helpers/supabase_auth_helper.dart';
import '../models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  SupabaseAuthHelper? _authHelper;
  User? _currentUser;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initProfile();
  }

  Future<void> _initProfile() async {
    _authHelper = await SupabaseAuthHelper.getInstance();
    await _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (_authHelper == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // If no session, go to login
      if (!_authHelper!.hasValidSession()) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Prefer DB-enriched profile; fallback to auth data
      User? user = await _authHelper!.getUserFromDatabase();
      user ??= await _authHelper!.getCurrentUser();

      if (mounted) {
        setState(() {
          _currentUser = user ?? User(id: 'unknown', email: 'user@example.com', name: 'User', role: 'user');
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _loading = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          _currentUser = User(id: 'unknown', email: 'user@example.com', name: 'User', role: 'user');
        });
      }
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

  Future<void> _performLogout() async {
    if (_authHelper == null) return;

    try {
      await _authHelper!.signOut();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final header = Container(
      color: theme.colorScheme.primary,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
              color: theme.colorScheme.onPrimary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Profile',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final profileCard = _loading
        ? const Center(child: CircularProgressIndicator())
        : Card(
            elevation: 0,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFFE0E0E0),
                    child: Icon(Icons.person, size: 48, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?.name ?? 'Guest',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

    final infoCard = _loading
        ? const SizedBox.shrink()
        : Card(
            elevation: 0,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Text('Personal Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.email, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), size: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentUser?.email ?? 'guest@cst.edu',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.badge, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), size: 16),
                      const SizedBox(width: 12),
                      Text(
                        'Role: ${_currentUser?.role ?? 'user'}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

    final logoutCard = _loading
        ? const SizedBox.shrink()
        : Card(
            elevation: 0,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _showLogoutDialog,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
            ),
          );

    return Scaffold(
      body: Column(
        children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  profileCard,
                  infoCard,
                  logoutCard,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
