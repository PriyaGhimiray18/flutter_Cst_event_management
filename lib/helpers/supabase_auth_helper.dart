import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../config/supabase_config.dart';

/// Helper class for Supabase authentication operations
class SupabaseAuthHelper {
  static SupabaseAuthHelper? _instance;
  String? _accessToken;
  SharedPreferences? _prefs;

  SupabaseAuthHelper._();

  static Future<SupabaseAuthHelper> getInstance() async {
    if (_instance == null) {
      _instance = SupabaseAuthHelper._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _accessToken = _prefs?.getString('access_token');
    } catch (e) {
      print('Error initializing SupabaseAuthHelper: $e');
    }
  }

  

  /// Sign in with email and password
  Future<User> signIn(String email, String password) async {
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/token?grant_type=password');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.supabaseAnonKey,
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseJson = jsonDecode(response.body);
        final accessToken = responseJson['access_token'] as String?;

        if (accessToken != null && accessToken.isNotEmpty) {
          _accessToken = accessToken;
          await _prefs?.setString('access_token', accessToken);

          // Decode JWT to get user id, email, and role quickly without extra network calls
          final decoded = _decodeJwt(accessToken);
          final String userId = decoded['sub'] ?? '';
          final String jwtEmail = decoded['email'] ?? email;
          String role = 'user'; // Default role

          String name = '';

          if (userId.isEmpty) {
            throw Exception('Failed to decode user from token');
          }

          // Fetch user from the database to get the most up-to-date role
          try {
            final dbUrl = Uri.parse('${SupabaseConfig.restApiUrl}/users?id=eq.$userId&select=name,role');
            final dbResponse = await http.get(
              dbUrl,
              headers: {
                'apikey': SupabaseConfig.supabaseAnonKey,
                'Authorization': 'Bearer $accessToken',
              },
            );

            if (dbResponse.statusCode == 200) {
              final usersArray = jsonDecode(dbResponse.body) as List;
              if (usersArray.isNotEmpty) {
                final dbUser = usersArray[0];
                role = dbUser['role'] ?? 'user';
                name = dbUser['name'] ?? '';
              }
            }
          } catch (e) {
            print('Error fetching user role from DB: $e');
            // Fallback to role from token if DB call fails
            if (decoded['user_metadata'] != null && decoded['user_metadata'] is Map && (decoded['user_metadata'] as Map)['role'] != null) {
              role = (decoded['user_metadata'] as Map)['role'] as String;
            }
          }

          // Derive a friendly name from email if not present in token
          if (name.isEmpty && decoded['user_metadata'] != null && decoded['user_metadata'] is Map && (decoded['user_metadata'] as Map)['name'] != null) {
            name = (decoded['user_metadata'] as Map)['name'] as String? ?? '';
          }
          if (name.isEmpty) {
            if (jwtEmail.contains('@')) {
              name = jwtEmail.split('@')[0];
            } else {
              name = 'User';
            }
          }

          // Cache user basics for faster subsequent app starts
          await _prefs?.setString('user_id', userId);
          await _prefs?.setString('user_email', jwtEmail);
          await _prefs?.setString('user_name', name);
          await _prefs?.setString('user_role', role);

          return User(id: userId, email: jwtEmail, name: name, role: role);
        } else {
          throw Exception('No access token received');
        }
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          final errorMsg = errorBody['error_description'] ?? errorBody['message'] ?? errorBody['error'] ?? 'Login failed';
          throw Exception(errorMsg);
        } catch (e) {
          throw Exception('Login failed with status ${response.statusCode}: ${response.body}');
        }
      }
    } on SocketException {
      throw Exception('Network error: Cannot connect to server. Please check your internet connection.');
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Login error: $e');
    }
  }

  /// Sign up with email, password, name, and role
  Future<User> signUp(String email, String password, String name, String role) async {
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/signup');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.supabaseAnonKey,
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'user_metadata': {
            'name': name,
            'role': role,
          },
        }),
      );

      print('Signup response status: ${response.statusCode}');
      print('Signup response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseJson = jsonDecode(response.body);
        final userJson = responseJson['user'];
        final userId = userJson['id'] as String;

        if (responseJson['access_token'] != null) {
          _accessToken = responseJson['access_token'];
          await _prefs?.setString('access_token', _accessToken!);
          await _prefs?.setString('user_id', userId);
        }

        // Insert user record in database
        await _insertUserRecord(userId, email, name, role);

        return User(id: userId, email: email, name: name, role: role);
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          final errorMsg = errorBody['error_description'] ?? errorBody['message'] ?? errorBody['error'] ?? 'Registration failed';
          throw Exception(errorMsg);
        } catch (e) {
          throw Exception('Registration failed with status ${response.statusCode}: ${response.body}');
        }
      }
    } on SocketException {
      throw Exception('Network error: Cannot connect to server. Please check your internet connection.');
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Registration error: $e');
    }
  }

  /// Insert user record into users table
  Future<void> _insertUserRecord(String userId, String email, String name, String role) async {
    try {
      final url = Uri.parse('${SupabaseConfig.restApiUrl}/users');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.supabaseAnonKey,
          if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          'id': userId,
          'name': name,
          'email': email,
          'role': role,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        print('Failed to create user record: ${response.body}');
      }
    } catch (e) {
      print('Error creating user record: $e');
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      _accessToken = null;
      await _prefs?.remove('access_token');
      await _prefs?.remove('user_id');
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  /// Get the current authenticated user
  Future<User?> getCurrentUser() async {
    // Try cached user first for speed
    final cachedId = _prefs?.getString('user_id');
    final cachedEmail = _prefs?.getString('user_email');
    final cachedName = _prefs?.getString('user_name');
    final cachedRole = _prefs?.getString('user_role');
    if (cachedId != null && cachedEmail != null && cachedName != null && cachedRole != null) {
      return User(id: cachedId, email: cachedEmail, name: cachedName, role: cachedRole);
    }

    if (_accessToken == null) {
      return null;
    }

    try {
      final authUrl = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/user');
      final authResponse = await http.get(
        authUrl,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (authResponse.statusCode == 200) {
        final userJson = jsonDecode(authResponse.body);
        print('Auth user JSON: $userJson');
        final userId = userJson['id'] as String;
        final email = userJson['email'] as String;

        String name = '';
        String role = 'user';

        if (userJson['user_metadata'] != null) {
          name = userJson['user_metadata']['name'] ?? '';
          role = userJson['user_metadata']['role'] ?? 'user';
        }

        // Check database for most up-to-date role
        final dbUrl = Uri.parse('${SupabaseConfig.restApiUrl}/users?id=eq.$userId&select=name,role');
        final dbResponse = await http.get(
          dbUrl,
          headers: {
            'apikey': SupabaseConfig.supabaseAnonKey,
            'Authorization': 'Bearer $_accessToken',
          },
        );

        if (dbResponse.statusCode == 200) {
          final usersArray = jsonDecode(dbResponse.body) as List;
          if (usersArray.isNotEmpty) {
            final dbUser = usersArray[0];
            print('DB user JSON: $dbUser');
            name = dbUser['name'] ?? name;
            role = dbUser['role'] ?? role;
          }
        }

        final user = User(id: userId, email: email, name: name, role: role);
        // Cache for future fast access
        await _prefs?.setString('user_id', userId);
        await _prefs?.setString('user_email', email);
        await _prefs?.setString('user_name', name);
        await _prefs?.setString('user_role', role);
        return user;
      }
    } catch (e) {
      print('Error getting current user: $e');
    }

    return null;
  }

  /// Get user from database
  Future<User?> getUserFromDatabase() async {
    if (_accessToken == null) {
      throw Exception('Authentication required');
    }

    try {
      final authUrl = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/user');
      final authResponse = await http.get(
        authUrl,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'apikey': SupabaseConfig.supabaseAnonKey,
        },
      );

      if (authResponse.statusCode < 200 || authResponse.statusCode >= 300) {
        throw Exception('Failed to get user info from auth');
      }

      final authUserJson = jsonDecode(authResponse.body);
      final userId = authUserJson['id'] as String;
      final authEmail = authUserJson['email'] as String;

      String authRole = 'user';
      if (authUserJson['user_metadata'] != null) {
        authRole = authUserJson['user_metadata']['role'] ?? 'user';
      }

      final dbUrl = Uri.parse('${SupabaseConfig.restApiUrl}/users?select=name,email,role&id=eq.$userId');
      final dbResponse = await http.get(
        dbUrl,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (dbResponse.statusCode >= 200 && dbResponse.statusCode < 300) {
        final usersArray = jsonDecode(dbResponse.body) as List;
        if (usersArray.isNotEmpty) {
          final userRecord = usersArray[0];
          String name = userRecord['name'] ?? '';
          String email = userRecord['email'] ?? authEmail;
          String role = userRecord['role'] ?? 'user';

          if (name.isEmpty) {
            if (authEmail.contains('@')) {
              String emailPrefix = authEmail.split('@')[0];
              name = emailPrefix;
              if (name.isEmpty) name = 'User';
            } else {
              name = 'User';
            }
          }

          return User(id: userId, email: email, name: name, role: role);
        }
      }

      // Fallback to auth data
      String name = 'User';
      if (authEmail.contains('@')) {
        String emailPrefix = authEmail.split('@')[0];
        name = emailPrefix;
        if (name.isEmpty) name = 'User';
      }
      return User(id: userId, email: authEmail, name: name, role: authRole);
    } catch (e) {
      return User(id: 'unknown', email: 'user@example.com', name: 'User', role: 'user');
    }
  }

  /// Check if user is admin
  Future<bool> isCurrentUserAdmin() async {
    final currentUser = await getCurrentUser();
    return currentUser != null && currentUser.role == 'admin';
  }

  String? getAccessToken() => _accessToken;

  /// Check if has valid session
  bool hasValidSession() {
    return _accessToken != null && _accessToken!.isNotEmpty;
  }

  Future<void> createEvent(Map<String, dynamic> eventData, File? image) async {
    if (!hasValidSession()) {
      throw Exception('Authentication required');
    }

    try {
      String? imageUrl;
      if (image != null) {
        final imagePath = 'event_images/${DateTime.now().millisecondsSinceEpoch}.${image.path.split('.').last}';
        final storageUrl = Uri.parse('${SupabaseConfig.supabaseUrl}/storage/v1/object/events/$imagePath');
        
        final uploadResponse = await http.post(
          storageUrl,
          headers: {
            'apikey': SupabaseConfig.supabaseAnonKey,
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'image/*',
          },
          body: await image.readAsBytes(),
        );

        if (uploadResponse.statusCode >= 200 && uploadResponse.statusCode < 300) {
          imageUrl = '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/events/$imagePath';
        } else {
          throw Exception('Failed to upload image: ${uploadResponse.body}');
        }
      }

      final url = Uri.parse('${SupabaseConfig.restApiUrl}/events');
      final response = await http.post(
        url,
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({
          ...eventData,
          if (imageUrl != null) 'image_url': imageUrl,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to create event: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }
}

/// JWT utilities
Map<String, dynamic> _decodeJwt(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    final payload = utf8.decode(base64.decode(normalized));
    final dynamic jsonMap = jsonDecode(payload);
    if (jsonMap is Map<String, dynamic>) {
      return jsonMap;
    }
  } catch (_) {
    // ignore
  }
  return {};
}
