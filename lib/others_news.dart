import 'package:flutter/material.dart';

// ignore: camel_case_types
class OthersNews extends StatelessWidget {
  const OthersNews({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10,left: 5,right: 5),
      child: SizedBox(
        width: 100, // Set a specific width
        height: 100, // Set a specific height
        child: Container(
          color: Colors.white,
          child: const Center(child: Text("Nothing to show")),
        ),
      ),
    );
  }
}