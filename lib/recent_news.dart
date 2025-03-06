import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:demo_app/service/news_service.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_app/news_details.dart';

class RecentNews extends StatefulWidget {
  const RecentNews({super.key});

  @override
  _RecentNewsState createState() => _RecentNewsState();
}

class _RecentNewsState extends State<RecentNews> {
  late Future<List<Map<String, dynamic>>> newsList;
  List<bool> expandedList = [];
  late SharedPreferences prefs;
  Map<int, bool> isLikedMap = {};
  Map<int, int> likeCountMap = {};
  Map<int, bool> isCommentSectionVisible = {}; // Comment visibility
  Map<int, TextEditingController> commentControllers =
      {}; // Comment input controllers
  Map<int, List<Map<String, dynamic>>> commentsMap =
      {}; // Store comments per newsId
  Map<int, bool> isShowMoreVisible = {};
  int? loggedInUserId;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Load saved preferences and fetch news data
  _loadPreferences() async {
    prefs = await SharedPreferences.getInstance();
    loggedInUserId = prefs.getInt('userId');

    newsList = NewsService().fetchNews().then((data) {
      expandedList = List<bool>.filled(data.length, false);
      _loadLikeStates(data);
      _loadCommentsForAllNews(data); // Fetch comments for each news item
      return data;
    });

    setState(() {}); // Refresh UI once data is fetched
  }

  void _loadLikeStates(List<Map<String, dynamic>> data) async {
    for (var news in data) {
      int newsId = news['id'];

      print(
          'Fetched News ID: $newsId, Like Count from API: ${news['like_count']}');

      // ✅ Always store like_count, even if not logged in
      likeCountMap[newsId] = news['like_count'] ?? 0;

      if (loggedInUserId != null) {
        bool isLiked =
            await NewsService().checkIfLiked(loggedInUserId!, newsId);
        isLikedMap[newsId] = isLiked;
      }
      isCommentSectionVisible[newsId] = false;
      commentControllers[newsId] = TextEditingController();
      commentsMap[newsId] = [];
      isShowMoreVisible[newsId] = false;
    }
    setState(() {}); // Ensure UI updates
  }

  // Fetch comments for all news items at once
  void _loadCommentsForAllNews(List<Map<String, dynamic>> data) async {
    for (var news in data) {
      int newsId = news['id'];
      // Fetch comments only if there are no comments loaded already for that news item
      if (commentsMap[newsId]?.isEmpty ?? true) {
        await _fetchComments(newsId);
      }
    }
  }

  // Fetch comments with user name and date when comment section is expanded
  Future<void> _fetchComments(int newsId) async {
    List<Map<String, dynamic>> fetchedComments =
        await NewsService().fetchComments(newsId);
    setState(() {
      commentsMap[newsId] = fetchedComments;
    });
  }

  // Handle comment submission
  Future<void> _sendComment(int newsId, String commentText) async {
    if (commentText.isEmpty) return;

    if (loggedInUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to comment.')));
      return;
    }

    bool success =
        await NewsService().sendComment(loggedInUserId!, newsId, commentText);

    if (success) {
      commentControllers[newsId]?.clear();
      await _fetchComments(newsId); // Refresh the comment list
    } else {
      print("Failed to submit comment");
    }
  }

  void _editComment(int newsId, int commentId, String currentCommentText) {
    // Create a TextEditingController for the comment input field
    TextEditingController _editController =
        TextEditingController(text: currentCommentText);

    // Show a dialog with a text field to edit the comment
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Comment'),
          content: TextField(
            controller: _editController,
            decoration: const InputDecoration(hintText: 'Edit your comment'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog without saving
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String updatedComment = _editController.text;
                if (updatedComment.isNotEmpty) {
                  // Make API call to update the comment
                  var response = await NewsService()
                      .updateComment(commentId, updatedComment);
                  if (response != null &&
                      response['message'] == 'Comment updated successfully') {
                    setState(() {
                      // Update the comment in the UI
                      commentsMap[newsId]![commentsMap[newsId]!.indexWhere(
                              (comment) => comment['id'] == commentId)]
                          ['comment_text'] = updatedComment;
                    });
                    Navigator.pop(context); // Close the dialog
                  } else {
                    // Handle failure case
                    print('Failed to update comment: ${response?['message']}');
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, int commentId, int newsId) async {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Prevents dismissing the dialog by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Comment'),
          content: const Text('Are you sure you want to delete this comment?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                bool success = await NewsService().deleteComment(commentId);
                if (success) {
                  setState(() {
                    commentsMap[newsId]!
                        .removeWhere((comment) => comment['id'] == commentId);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Comment deleted successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete comment')),
                  );
                }
                Navigator.of(context).pop(); // Close the dialog after action
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showShareOptions(BuildContext context, int newsId, String title,
      String description) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Share this news'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.facebook, color: Colors.blue),
                title: const Text('Share on Facebook'),
                onTap: () {
                  _shareOnFacebook(newsId, title, description);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.email, color: Colors.red),
                title: const Text('Share via Gmail'),
                onTap: () {
                  _shareOnGmail(newsId, title, description);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.blueAccent),
                title: const Text('Share on Twitter'),
                onTap: () {
                  _shareOnTwitter(newsId, title, description);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.linked_camera, color: Colors.blue),
                title: const Text('Share on LinkedIn'),
                onTap: () {
                  _shareOnLinkedIn(newsId, title, description);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Share on Facebook (Facebook App should be installed on the device)
  void _shareOnFacebook(int newsId, String title, String description) {
    String newsLink =
        "http://localhost:3000/news/$newsId"; // Replace with actual link
    String shareText = "$title\n\n$description\nRead more: $newsLink";

    Share.share(shareText, subject: title);
  }

  // Share on Gmail
  void _shareOnGmail(int newsId, String title, String description) {
    String newsLink =
        "http://localhost:3000/news/$newsId"; // Replace with actual link
    String shareText = "$title\n\n$description\nRead more: $newsLink";

    // Using the share_plus package to share via email (Gmail)
    Share.share(shareText, subject: title);
  }

  // Share on Twitter (Twitter App should be installed on the device)
  void _shareOnTwitter(int newsId, String title, String description) {
    String newsLink =
        "http://localhost:3000/news/$newsId"; // Replace with actual link
    String shareText = "$title\n\n$description\nRead more: $newsLink";

    Share.share(shareText, subject: title);
  }

  // Share on LinkedIn (LinkedIn App should be installed on the device)
  void _shareOnLinkedIn(int newsId, String title, String description) {
    String newsLink =
        "http://localhost:3000/news/$newsId"; // Replace with actual link
    String shareText = "$title\n\n$description\nRead more: $newsLink";

    Share.share(shareText, subject: title);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: newsList,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No news available'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            var news = snapshot.data![index];
            int newsId = news['id'];
            String description = news['description'] ?? '';
            String title = news['title'] ?? '';
            Uint8List imageBytes = news['image'];
            String publishedAt = news['published_at'] ?? '';
            String formattedDate = _formatDate(publishedAt);

            bool isLiked = isLikedMap[newsId] ?? false;
            int likeCount = likeCountMap[newsId] ?? 0;
            bool isExpanded = expandedList[index];
            String shortDescription =
                description.split(' ').take(10).join(' ') +
                    (description.split(' ').length > 10 ? '...' : '');

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewsDetails(
                      title: title,
                      description: description,
                      imageBytes: imageBytes,
                      publishedAt: formattedDate,
                    ),
                  ),
                );
              },
              child: Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.memory(
                          imageBytes,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isExpanded ? description : shortDescription,
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (description.split(' ').length > 10)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                expandedList[index] = !expandedList[index];
                              });
                            },
                            child: Text(isExpanded ? 'Show Less' : 'Read More'),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 18),
                            const SizedBox(width: 5),
                            Text(formattedDate),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.thumb_up,
                                  color: isLiked ? Colors.blue : Colors.grey),
                              onPressed: loggedInUserId == null
                                  ? () {
                                      // Show a message if user is not logged in
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "Please log in to like the news")),
                                      );
                                    }
                                  : () async {
                                      var response =
                                          await NewsService().likeNews(newsId);
                                      if (response != null) {
                                        setState(() {
                                          isLikedMap[newsId] =
                                              response['action'] == 'liked';
                                          likeCountMap[newsId] =
                                              response['likeCount'];
                                        });
                                      }
                                    },
                            ),
                            Text('$likeCount'),
                            IconButton(
                              icon: const Icon(Icons.comment),
                              onPressed: () async {
                                if (loggedInUserId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("Please log in to comment")),
                                  );
                                  return; // Stop execution if not logged in
                                }

                                setState(() {
                                  isCommentSectionVisible[newsId] =
                                      !isCommentSectionVisible[newsId]!;
                                });

                                if (isCommentSectionVisible[newsId]!) {
                                  await _fetchComments(newsId);
                                }
                              },
                            ),
                            Text('${commentsMap[newsId]?.length ?? 0}'),

                            IconButton(
                              icon: const Icon(Icons.share),
                              onPressed: () {
                                if (loggedInUserId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("Please log in to share")),
                                  );
                                  return; // Stop execution if not logged in
                                }

                                _showShareOptions(
                                    context, newsId, title, description);
                              },
                            ),

                            const Text(
                                '0'), // Replace with actual share count if needed
                          ],
                        ),
                        if (isCommentSectionVisible[newsId] == true) ...[
                          TextField(
                            controller: commentControllers[newsId],
                            decoration: const InputDecoration(
                                hintText: 'Write a comment...'),
                            maxLines: 3,
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _sendComment(
                                  newsId, commentControllers[newsId]!.text);
                            },
                            child: const Text('Send'),
                          ),
                          Column(
                            children: [
                              // Display comments dynamically
                              // Inside the ListView.builder for displaying comments
                              ListView.builder(
                                shrinkWrap:
                                    true, // Makes the ListView scrollable within the column
                                physics:
                                    const NeverScrollableScrollPhysics(), // Prevents the ListView from scrolling independently
                                itemCount: isShowMoreVisible[newsId]!
                                    ? commentsMap[newsId]!.length
                                    : (commentsMap[newsId]!.length > 3
                                        ? 3
                                        : commentsMap[newsId]!.length),
                                itemBuilder: (context, index) {
                                  String formattedCommentDate = _formatDate(
                                      commentsMap[newsId]![index]
                                          ['created_at']);
                                  int commentUserId =
                                      commentsMap[newsId]![index]['user_id'];

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 0),
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                commentsMap[newsId]![index]
                                                    ['user_name'],
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                commentsMap[newsId]![index]
                                                    ['comment_text'],
                                                style: TextStyle(fontSize: 14),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                formattedCommentDate,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Show the PopupMenuButton only if the logged-in user is the commenter
                                        if (loggedInUserId == commentUserId)
                                          // Inside your ListTile widget where comments are displayed
                                          PopupMenuButton<String>(
                                            onSelected: (String value) async {
                                              if (value == 'edit') {
                                                // Get the commentId and current comment text from the comments list
                                                int commentId =
                                                    commentsMap[newsId]![index]
                                                        ['id'];
                                                String currentCommentText =
                                                    commentsMap[newsId]![index]
                                                        ['comment_text'];

                                                // Call the _editComment function to allow the user to edit the comment
                                                _editComment(newsId, commentId,
                                                    currentCommentText);
                                              } else if (value == 'delete') {
                                                // Get the commentId and trigger the delete confirmation
                                                int commentId =
                                                    commentsMap[newsId]![index]
                                                        ['id'];
                                                _showDeleteConfirmationDialog(
                                                    context, commentId, newsId);
                                              }
                                            },
                                            itemBuilder:
                                                (BuildContext context) =>
                                                    <PopupMenuEntry<String>>[
                                              const PopupMenuItem<String>(
                                                value: 'edit',
                                                child: Text('Edit'),
                                              ),
                                              const PopupMenuItem<String>(
                                                value: 'delete',
                                                child: Text('Delete'),
                                              ),
                                            ],
                                            icon: const Icon(Icons.more_vert,
                                                color: Colors.black),
                                          )
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // Show More/Show Less Button
                              if (commentsMap[newsId]!.length > 3)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      isShowMoreVisible[newsId] =
                                          !isShowMoreVisible[newsId]!;
                                    });
                                  },
                                  child: Text(isShowMoreVisible[newsId]!
                                      ? 'Show Less'
                                      : 'Show More'),
                                ),
                            ],
                          )
                        ],
                      ],
                    )),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'Unknown date';
    try {
      return DateFormat('MMMM dd, yyyy hh:mm a')
          .format(DateTime.parse(date).toLocal());
    } catch (e) {
      return 'Invalid date';
    }
  }
}
