import 'package:flutter/material.dart';

class UserExistsPage extends StatelessWidget {
  final String email;

  // Constructor to accept the email.
  UserExistsPage({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("User Already Exists")),
      body: Center(
        child: Text(
          "User already exists!\nEmail: $email",  // Only display email
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
