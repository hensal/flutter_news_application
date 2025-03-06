import 'dart:convert';
import 'dart:typed_data';
import 'package:demo_app/service/news_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:demo_app/news_details.dart'; // Import the NewsDetails screen

class SearchNews extends StatefulWidget {
  final String searchQuery;

  const SearchNews({super.key, required this.searchQuery});

  @override
  _SearchNewsState createState() => _SearchNewsState();
}

class _SearchNewsState extends State<SearchNews> {
  final TextEditingController searchController = TextEditingController();
  final NewsService newsService = NewsService();
  List<dynamic> searchResults = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    searchController.text =
        widget.searchQuery; // Update text when searchQuery is passed
    fetchSearchResults(widget.searchQuery);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.searchQuery != searchController.text) {
      searchController.text = widget.searchQuery;
      fetchSearchResults(widget.searchQuery);
    }
  }

  Future<void> fetchSearchResults(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      isLoading = true;
      searchResults = []; // Clear old results
    });

    List<dynamic> results = await newsService.searchNews(query);

    setState(() {
      searchResults = results;
      isLoading = false;
    });

    print("Final search results: $searchResults"); // Debugging
  }

void onSearch() {
  String query = searchController.text.trim();

  if (query.isEmpty) {
    print("Showing Snackbar for empty search"); // Debugging
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Search field is empty!"),
        duration: Duration(seconds: 2),
      ),
    );
    return; // Stop execution
  }

  fetchSearchResults(query);
}
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          GoRouter.of(context).go('/'); // Navigates back to RecentNews
        },
      ),
      title: TextField(
        controller: searchController,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'Search news...',
          hintStyle: const TextStyle(fontSize: 17),
          fillColor: const Color.fromRGBO(227, 230, 238, 1.0),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide.none,
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: onSearch,
          ),
        ),
        onSubmitted: (value) => onSearch(),
      ),
    ),
    body: Builder(
      builder: (BuildContext context) {
        return isLoading
            ? const Center(child: CircularProgressIndicator())
            : searchResults.isEmpty
                ? const Center(child: Text("No results found"))
                : ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final news = searchResults[index];
                      String imageData = news['image'];
                      Uint8List? imageBytes;
                      try {
                        imageBytes = base64Decode(
                            imageData.replaceAll(RegExp(r'\s+'), ''));
                      } catch (e) {
                        debugPrint("Error decoding base64: $e");
                        imageBytes = null;
                      }

                      return ListTile(
                        leading: (imageBytes != null)
                            ? Image.memory(
                                imageBytes,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image, size: 100),
                        title: Text(
                          news['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(news['description'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 5),
                            Text("Published: ${news['published_at']}"),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NewsDetails(
                                title: news['title'],
                                description: news['description'],
                                imageBytes: imageBytes ??
                                    Uint8List(0),
                                publishedAt: news['published_at'],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
              },
          ),
        );
    }
}
