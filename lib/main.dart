import 'package:cst_event_management/models/event.dart';
import 'package:cst_event_management/services/events_service.dart';
import 'package:cst_event_management/services/supabase_events_service.dart';
import 'package:cst_event_management/ui/admin_dashboard_screen.dart';
import 'package:cst_event_management/ui/event_detail_screen.dart';
import 'package:cst_event_management/ui/home_screen.dart';
import 'package:cst_event_management/ui/login_screen.dart';
import 'package:cst_event_management/ui/notifications_screen.dart';
import 'package:cst_event_management/ui/profile_screen.dart';
import 'package:cst_event_management/ui/registration_screen.dart';
import 'package:cst_event_management/ui/signup_screen.dart';
import 'package:cst_event_management/ui/create_event_screen.dart';
import 'package:cst_event_management/services/supabase_helper_notifications_service.dart';
import 'package:cst_event_management/helpers/supabase_auth_helper.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<EventsService>(
          create: (_) => SupabaseEventsService(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CST Event Management',
        theme: ThemeData(
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00BCD4)).copyWith(
            primary: const Color(0xFF00BCD4),
          ),
          primaryColor: const Color(0xFF00BCD4),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF00BCD4),
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const _StartupRouter(),
          '/home': (context) => const HomeScreen(),
          '/create': (context) => const CreateEventScreen(),
          '/detail': (context) => const EventDetailScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegistrationScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/notifications': (context) => NotificationsScreen(
                service: SupabaseHelperNotificationsService(),
              ),
          '/admin': (context) => const AdminDashboardScreen(),
        },
      ),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    try {
      final auth = await SupabaseAuthHelper.getInstance();
      if (!auth.hasValidSession()) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      final user = await auth.getCurrentUser();
      if (!mounted) return;
      if (user != null && user.role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}