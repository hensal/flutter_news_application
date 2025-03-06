import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; 

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Navigate to LoginScreen using GoRouter when the logout icon is pressed
              context.go('/'); 
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Welcome to Home Screen!'),
      ),
    );
  }
}
