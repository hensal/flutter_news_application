import 'dart:convert';
import 'dart:typed_data';
import 'package:demo_app/news_details.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Model class for News
class News {
  final int id;
  final String title;
  final String description;
  final String category;
  final String publishedAt;
  final Uint8List image;

  News({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.publishedAt,
    required this.image,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    String imageData = json['image'];

    Uint8List? imageBytes;
    try {
      imageBytes = base64Decode(imageData.replaceAll(RegExp(r'\s+'), ''));
    } catch (e) {
      debugPrint("Error decoding base64: $e"); 
      imageBytes = null; 
    }

    return News(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      publishedAt: json['published_at'],
      image: imageBytes ?? Uint8List(0), 
    );
  }
}

// Service class to fetch news based on category
class NewsService {
  static const String baseUrl = 'http://localhost:3000'; 

  // Fetch news based on category
  static Future<List<News>> fetchNewsByCategory(String category) async {
    final response = await http.get(Uri.parse('$baseUrl/news1?category=$category'));

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((newsJson) => News.fromJson(newsJson)).toList();
    } else {
      throw Exception('Failed to load news');
    }
  }
}

// Widget for displaying Finance News
class FinanceNews extends StatelessWidget {
  const FinanceNews({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<News>>(
      future: NewsService.fetchNewsByCategory('finance'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No finance news available'));
        } else {
          final newsList = snapshot.data!;
          return ListView.builder(
            itemCount: newsList.length,
            itemBuilder: (context, index) {
              final news = newsList[index];
              String formattedDate = _formatDate(news.publishedAt);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewsDetails(
                        title: news.title,
                        description: news.description,
                        imageBytes: news.image,
                        publishedAt: formattedDate,
                      ),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // IMAGE ON THE LEFT
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            news.image,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10), 

                        // TEXT CONTENT ON THE RIGHT
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // TITLE
                              Text(
                                news.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),

                              // DESCRIPTION
                              Text(
                                news.description,
                                style: const TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),

                              // PUBLISHED DATE
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                  const SizedBox(width: 5),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }

  // Date formatting function
  String _formatDate(String date) {
    if (date.isEmpty) return 'Unknown date';
    try {
      return DateFormat('MMMM dd, yyyy hh:mm a')
          .format(DateTime.parse(date).toLocal());
    } catch (e) {
      return 'Invalid date';
    }
  }
}
