import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // For token storage

class AuthService {
  static const String baseUrl = 'http://localhost:3000';
    final String baseUrl1 = "http://localhost:3000/user-info"; // Change this to your API URL

  // Save the token to shared preferences after successful login
Future<Map<String, dynamic>> login(String email, String password) async {
  final url = Uri.parse('$baseUrl/login');

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Store token and userId in shared preferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('auth_token', data['token']); // Save the token
      prefs.setInt('userId', data['userId']); // Save userId from the response

      return {'success': true, 'message': 'Login successful', 'token': data['token']};
    } else {
      return {'success': false, 'message': 'Invalid credentials'};
    }
  } catch (e) {
    return {'success': false, 'message': 'Server error: $e'};
  }
}


  // Retrieve token from shared preferences
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('userId'); // Retrieve stored user ID

    if (userId == null) {
      return null; // No user logged in
    }

    final response = await http.get(Uri.parse("$baseUrl1?userId=$userId"),
        headers: {"Content-Type": "application/json"});

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print("Error fetching user: ${response.body}");
      return null;
    }
  }
}


