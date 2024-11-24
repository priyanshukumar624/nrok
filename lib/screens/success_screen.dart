import 'package:flutter/material.dart';

class RegistrationSuccessPage extends StatelessWidget {
  final String email;

  RegistrationSuccessPage({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Registration Successful")),
      body: Center(
        child: Text(
          "Welcome You are successfully registered!\nEmail: $email",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
