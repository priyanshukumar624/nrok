import 'package:flutter/material.dart';
import 'Registration_screen.dart'; // Import the RegistrationScreen

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: RegistrationScreen(), // Set the RegistrationScreen as the home screen
    );
  }
}
