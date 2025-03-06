import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NewsService {
  Future<void> addNews({
    required String title,
    required String description,
    required String category,
    required Uint8List? imageBytes,
  }) async {
    var uri = Uri.parse("http://localhost:3000/news");
    var request = http.MultipartRequest("POST", uri);

    // Add fields
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['category'] = category;

    // Add the image file only if it is not null
    if (imageBytes != null) {
      // Ensure you're adding the image correctly using MultipartFile.fromBytes
      request.files.add(http.MultipartFile.fromBytes(
        'image', // Field name should match the server-side field
        imageBytes,
        filename:
            'image.jpg', // Add a filename if necessary, even if the file is binary
      ));
    }

    var response = await request.send();

    if (response.statusCode != 201) {
      throw Exception("Failed to add news: ${response.statusCode}");
    }
  }

Future<List<Map<String, dynamic>>> fetchNews() async {
  var uri = Uri.parse("http://localhost:3000/news");
  var response = await http.get(uri);

  if (response.statusCode == 200) {
    print('API Response: ${response.body}'); // Debugging print
    List<dynamic> data = json.decode(response.body);

    return data.map((news) {
      String base64Image = news['image'] ?? ''; 
      String description = news['description'] ?? ''; 
      String title = news['title'] ?? ''; 
      String category = news['category'] ?? ''; 
      String publishedAt = news['published_at'] ?? ''; 

      // Decode base64 string to bytes only if it's not empty
      Uint8List imageBytes = base64Image.isNotEmpty
          ? base64Decode(base64Image.replaceAll(RegExp(r'\s+'), ''))
          : Uint8List(0); // Empty list if no image

      return {
        'id': news['id'],
        'title': title,
        'description': description,
        'category': category,
        'published_at': publishedAt, 
        'image': imageBytes, 
        'like_count': news['like_count'] ?? 0, // ✅ Fetch like_count properly
      };
    }).toList();
  } else {
    throw Exception("Failed to load news");
  }
}

  Future<List<dynamic>> searchNews(String query) async {
    const String baseUrl = 'http://localhost:3000';

    if (query.trim().isEmpty) return []; //Prevent empty search

    print("Sending search query: $query"); // ✅ Debug Log

    try {
      final response = await http.get(Uri.parse(
          "$baseUrl/news-search?search=${Uri.encodeComponent(query)}"));

      print("Raw API Response: ${response.body}"); // ✅ Debug Log

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        print("Parsed API Data: $data"); // ✅ Debug Log
        return data;
      } else {
        print("Error: ${response.statusCode}");
        return [];
      }
    } catch (error) {
      print("Error fetching search results: $error");
      return [];
    }
  }

  Future<Map<String, dynamic>?> likeNews(int newsId) async {
    const String apiUrl = 'http://localhost:3000/like-news';
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token'); //Retrieve the JWT token

    if (token == null) {
      print('User not logged in');
      return null;
    }

    //Make the POST request with the correct Authorization header and body
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token", //Add the Bearer token
      },
      body: jsonEncode({'news_id': newsId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Likes updated: ${data['likeCount']}');
      return data; // Return the full response including likeCount and action
    } else {
      print('Failed to update likes: ${response.body}');
      return null;
    }
  }

  Future<bool> checkIfLiked(int userId, int newsId) async {
    final response = await http.get(
      Uri.parse(
          'http://localhost:3000/check-like?userId=$userId&newsId=$newsId'),
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['liked'] ?? false;
    } else {
      throw Exception('Failed to check like status');
    }
  }

  Future<bool> sendComment(int userId, int newsId, String commentText) async {
    const String apiUrl12 = 'http://localhost:3000';
    try {
      // Get the saved token from shared preferences (assuming you saved it during login)
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token'); // Get token from prefs

      if (token == null) {
        print('No authentication token found');
        return false; // If no token, return false
      }

      final response = await http.post(
        Uri.parse('$apiUrl12/comments'),
        body: json.encode({
          'news_id': newsId,
          'comment_text': commentText,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Add token to Authorization header
        },
      ); 
      if (response.statusCode == 200) {
        return true; // Comment added successfully
      } else {
        return false; // Failed to add comment
      }
    } catch (e) {
      print("Error sending comment: $e");
      return false; // Handle network error or other issues
    }
  }

// Fetch comments for a specific news article
  Future<List<Map<String, dynamic>>> fetchComments(int newsId) async {
    const String baseUrl = 'http://localhost:3000';
    final response = await http.get(Uri.parse('$baseUrl/comments/$newsId'));

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      if (data['success']) {
        return List<Map<String, dynamic>>.from(data['comments']);
      } else {
        throw Exception('Failed to load comments');
      }
    } else {
      throw Exception('Failed to load comments');
    }
  }

  // Delete comment API
  Future<bool> deleteComment(int commentId) async {
    const String baseUrl = 'http://localhost:3000';
    final prefs = await SharedPreferences.getInstance();
    final int? loggedInUserId = prefs.getInt('userId');

    if (loggedInUserId == null) {
      print('User not logged in');
      return false;
    }
    final response = await http.delete(
      Uri.parse('$baseUrl/comments/$commentId'),
      headers: {
        'Content-Type': 'application/json', // Ensure the server knows it's JSON
      },
      body: json.encode({
        'userId': loggedInUserId, // Send the logged-in user's ID in the body
      }),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      print('Failed to delete comment: ${response.statusCode}');
      return false;
    }
  }

  Future<Map<String, dynamic>?> updateComment(
      int commentId, String newCommentText) async {
    String apiUrl = 'http://localhost:3000/comments/$commentId';
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token'); // Retrieve the JWT token

    if (token == null) {
      print('User not logged in');
      return null;
    }
    final userId = prefs.getInt('userId'); // Get the logged-in user's ID
    final response = await http.put(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Add the Bearer token
      },
      body: jsonEncode({
        'userId': userId,
        'newCommentText': newCommentText,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Comment updated: ${data['message']}');
      return data;
    } else {
      print('Failed to update comment: ${response.body}');
      return null;
    }
  }
}
