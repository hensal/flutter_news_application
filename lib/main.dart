import 'package:demo_app/add_news.dart';
import 'package:demo_app/entertainment_news.dart';
import 'package:demo_app/finace_news.dart';
import 'package:demo_app/forgot_password.dart';
import 'package:demo_app/login_screen.dart';
import 'package:demo_app/others_news.dart';
import 'package:demo_app/recent_news.dart';
import 'package:demo_app/reset_password_screen.dart';
import 'package:demo_app/search_news.dart';
import 'package:demo_app/service/login_service.dart';
import 'package:demo_app/sign_up_screen.dart';
import 'package:demo_app/sports_news.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GoRouter _router = GoRouter(
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Home(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/create-account',
        builder: (context, state) => const CreateAccountPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final String? email = state.uri.queryParameters['email'];
          return ResetPasswordPage(email: email ?? '');
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) {
          final searchQuery = state.uri.queryParameters['query'] ?? '';
          print('Received search query: $searchQuery'); // Debugging
          return SearchNews(searchQuery: searchQuery);
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const RecentNews(), // Home page
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late Future<Map<String, dynamic>?> userInfoFuture;
  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController
        .dispose(); // Dispose the controller to prevent memory leaks
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    userInfoFuture = _loadUserLoginStatus();
  }

  Future<Map<String, dynamic>?> _loadUserLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool loggedIn = prefs.getBool('isUserLoggedIn') ?? false;

    if (loggedIn) {
      int? userId = prefs.getInt('userId');
      print("Fetching user info for userId: $userId"); // Debugging
      if (userId == null) return null;

      var authService = AuthService();
      var userData = await authService.getUserInfo();
      print("User data fetched: $userData"); // Debugging

      return userData;
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return SafeArea(
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          drawer: FutureBuilder<Map<String, dynamic>?>(
            future: userInfoFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Drawer(
                    child: Center(child: CircularProgressIndicator()));
              }

              Map<String, dynamic>? userInfo = snapshot.data;
              bool isUserLoggedIn = userInfo != null;

              return Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    UserAccountsDrawerHeader(
                      accountName: Text(userInfo?['name'] ?? 'Guest User'),
                      accountEmail:
                          Text(userInfo?['email'] ?? 'guest@example.com'),
                      currentAccountPicture: CircleAvatar(
                        backgroundImage: userInfo?['profilePic'] != null
                            ? NetworkImage(userInfo!['profilePic'])
                            : null,
                        child: userInfo?['profilePic'] == null
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                    ),
                    ListTile(
                      title: const Text('Recent News'),
                      onTap: () {},
                    ),
                    ListTile(
                      title: const Text('Sports News'),
                      onTap: () {},
                    ),
                    ListTile(
                      title: const Text('Finance News'),
                      onTap: () {},
                    ),
                    if (isUserLoggedIn)
                      ListTile(
                        title: const Text('Logout'),
                        onTap: () async {
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          await prefs.remove('isUserLoggedIn');
                          await prefs.remove('userId');

                          setState(() {
                            userInfoFuture = Future.value(null);
                          });

                          context.go('/login');
                        },
                      ),
                  ],
                ),
              );
            },
          ),
          appBar: AppBar(
            leading: Builder(
              builder: (BuildContext context) {
                return IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                );
              },
            ),
            title: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Search apps & ...',
                      hintStyle: const TextStyle(fontSize: 17),
                      fillColor: const Color.fromRGBO(227, 230, 238, 1.0),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search_rounded),
                        onPressed: () {
                          print('Search button pressed'); // Debugging log
                          String searchQuery = searchController.text.trim();

                          if (searchQuery.isNotEmpty) {
                            print(
                                'Navigating to /search with query: $searchQuery'); // Debugging log
                            context
                                .go('/search?query=$searchQuery'); // Navigate
                          } else {
                            print('Search query is empty, not navigating.');
                            // Show SnackBar when the search field is empty
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter a search query!"),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => const AddNewsSheet(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  iconSize: screenWidth * 0.08,
                ),
                FutureBuilder<Map<String, dynamic>?>(
                  future: userInfoFuture,
                  builder: (context, snapshot) {
                    bool isUserLoggedIn = snapshot.data != null;

                    return IconButton(
                      onPressed: () {
                        if (!isUserLoggedIn) {
                          context.go('/login');
                        } else {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Logout'),
                                content: const Text('Do you want to logout?'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () async {
                                      SharedPreferences prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.remove('isUserLoggedIn');
                                      await prefs.remove('userId');

                                      setState(() {
                                        userInfoFuture = Future.value(null);
                                      });
                                      context.go('/login');
                                    },
                                    child: const Text('Yes'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('No'),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      icon: const Icon(Icons.account_circle),
                      iconSize: screenWidth * 0.08,
                    );
                  },
                ),
              ],
            ),
            bottom: const TabBar(
              isScrollable: true,
              labelPadding: EdgeInsets.symmetric(horizontal: 25),
              tabs: [
                Tab(text: 'RecentNews'),
                Tab(text: 'SportsNews'),
                Tab(text: 'FinaceNews'),
                Tab(text: 'Entertainments'),
                Tab(text: 'Others'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              RecentNews(),
              SportsNews(),
              FinanceNews(),
              EntertainmentNews(),
              OthersNews(),
            ],
          ),
        ),
      ),
    );
  }
}
