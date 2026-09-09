import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    if (kIsWeb) {
      // In Web production, default to live Render backend API
      return 'https://safeguard-api.onrender.com';
    }
    // Local testing IP for mobile devices / emulators
    return 'http://192.168.0.166:8000';
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveSession(data);
        return data;
      } else {
        final err = jsonDecode(response.body);
        return {'error': err['detail'] ?? 'Login failed'};
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return {'error': 'Cannot reach server. Is the backend running?'};
    }
  }

  static Future<Map<String, dynamic>?> register(
    String email,
    String password,
    String childName,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'child_name': childName,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveSession(data);
        return data;
      } else {
        final err = jsonDecode(response.body);
        return {'error': err['detail'] ?? 'Registration failed'};
      }
    } catch (e) {
      debugPrint('Register error: $e');
      return {'error': 'Cannot reach server. Is the backend running?'};
    }
  }

  // FIX: Properly invalidate the server session before clearing local prefs.
  // Old logout() only deleted SharedPreferences — the backend token stayed
  // valid indefinitely, which is a security hole.
  static Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http
            .post(
              Uri.parse('$baseUrl/auth/logout'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('Logout server call failed (clearing locally anyway): $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('child_name');
    await prefs.remove('pairing_code');
  }

  static Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['access_token'] != null) {
      await prefs.setString('jwt_token', data['access_token']);
    }
    if (data['child_name'] != null) {
      await prefs.setString('child_name', data['child_name']);
    }
    if (data['pairing_code'] != null) {
      await prefs.setString('pairing_code', data['pairing_code']);
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<String> getChildName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('child_name') ?? 'My Child';
  }

  static Future<String?> getPairingCode() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('pairing_code');
    if (cached != null) return cached;
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/pairing-code'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('pairing_code', data['pairing_code']);
        return data['pairing_code'];
      }
    } catch (e) {
      debugPrint('getPairingCode error: $e');
    }
    return null;
  }

  // ── Data endpoints ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getStats() async {
    return _get('/stats');
  }

  static Future<Map<String, dynamic>?> getHistory({
    int page = 1,
    int limit = 20,
    String? riskLevel,
    bool? reviewed,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (riskLevel != null) params['risk_level'] = riskLevel;
    if (reviewed != null) params['reviewed'] = reviewed ? 'true' : 'false';
    return _get('/history', queryParams: params);
  }

  // AlertsScreen: only unreviewed HIGH risk incidents.
  static Future<Map<String, dynamic>?> getAlerts() async {
    return _get(
      '/history',
      queryParams: {'reviewed': 'false', 'risk_level': 'HIGH', 'limit': '50'},
    );
  }

  // Returns total count of ALL unreviewed incidents (any risk level).
  // Used to drive the badge on the Alerts tab so it matches what
  // AlertsScreen actually displays.
  static Future<int> getUnreviewedCount() async {
    try {
      final data = await _get(
        '/history',
        queryParams: {'reviewed': 'false', 'limit': '1'},
      );
      return data?['total'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // Returns the timestamp of the most recent incident.
  // HomeScreen uses this to determine extension connection status:
  //   < 10 min  → Active (extension is scanning)
  //   10–60 min → Idle
  //   > 60 min or null → Disconnected / no recent activity
  static Future<DateTime?> getLatestActivityTime() async {
    try {
      final data = await _get(
        '/history',
        queryParams: {'limit': '1', 'page': '1'},
      );
      final items = data?['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;
      final ts = items.first['timestamp'] as String?;
      if (ts == null) return null;
      return DateTime.parse(ts).toLocal();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSites() async {
    return _get('/sites');
  }

  static Future<bool> markReviewed(int incidentId) async {
    try {
      final token = await getToken();
      final response = await http
          .patch(
            Uri.parse('$baseUrl/incidents/$incidentId/reviewed'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 6));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('markReviewed error: $e');
      return false;
    }
  }

  // ── Blocklist endpoints ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getBlocklistStats() async {
    return _get('/blocklist/stats');
  }

  static Future<Map<String, dynamic>?> getBlockedUrls() async {
    return _get('/blocklist/blocked');
  }

  static Future<bool> addBlockedUrl(String domain, String category) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/blocklist/add'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'domain': domain, 'category': category}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('addBlockedUrl error: $e');
      return false;
    }
  }

  static Future<bool> removeBlockedUrl(String domain) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/blocklist/remove'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'domain': domain}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('removeBlockedUrl error: $e');
      return false;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> _get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      final token = await getToken();
      final uri = Uri.parse(
        '$baseUrl$endpoint',
      ).replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        return {'_auth_error': true};
      }
    } catch (e) {
      debugPrint('GET $endpoint error: $e');
    }
    return null;
  }
}
