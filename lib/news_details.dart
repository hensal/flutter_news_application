import 'dart:typed_data';
import 'package:flutter/material.dart';

class NewsDetails extends StatelessWidget {
  final String title;
  final String description;
  final Uint8List imageBytes;
  final String publishedAt;

  const NewsDetails({
    super.key,
    required this.title,
    required this.description,
    required this.imageBytes,
    required this.publishedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.memory(
              imageBytes,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 5),
                Text(publishedAt, style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
