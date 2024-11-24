import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

// Main Registration Page
class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isLoading = false;

  // Show error dialog
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Error"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // Register user with Google Sign-In
  Future<void> registerUser(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _googleSignIn.signIn();

      if (user != null) {
        print('User Name: ${user.displayName}');
        print('User Email: ${user.email}');

        final requestBody = jsonEncode({
          'name': user.displayName,
          'email': user.email,
        });

        print('Request Body: $requestBody'); // Log the request body

        // Send the request to the backend
        final response = await http.post(
          Uri.parse('http://192.168.1.4:8080/register'), // Use correct backend URL
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );

        print('Response Status: ${response.statusCode}');
        print('Response Body: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['status'] == 'success') {
            // If registration is successful, navigate to the success page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RegistrationSuccessPage(email: user.email),
              ),
            );
          } else {
            // Handle unexpected success response
            _showErrorDialog(context, "Unexpected response from server.");
          }
        } else if (response.statusCode == 400) {
          // Handle "User already exists" case
          final jsonResponse = jsonDecode(response.body);

          if (jsonResponse['message'] == 'User already exists') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserExistsPage(email: jsonResponse['email']),
              ),
            );
          } else {
            // Handle other 400 errors
            _showErrorDialog(
              context,
              "Registration failed: ${jsonResponse['message'] ?? "Unknown error"}",
            );
          }
        } else {
          // Handle other non-200 responses
          _showErrorDialog(
            context,
            "Failed to connect to backend. Status: ${response.statusCode}\nResponse Body: ${response.body}",
          );
        }
      } else {
        // If Google Sign-In is cancelled
        print("Google Sign-In cancelled by user.");
      }
    } catch (e) {
      // Catch any exceptions during registration
      print("Error: $e");
      _showErrorDialog(context, "An error occurred: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Register with Google")),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator() // Show loading spinner while processing
            : ElevatedButton(
                onPressed: () => registerUser(context),
                child: Text("Register with Google"),
              ),
      ),
    );
  }
}

// Registration Success Page
class RegistrationSuccessPage extends StatelessWidget {
  final String email;
  RegistrationSuccessPage({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Registration Successful")),
      body: Center(
        child: Text("You are successfully registered!\nEmail: $email"),
      ),
    );
  }
}

// User Already Exists Page
class UserExistsPage extends StatelessWidget {
  final String email;
  UserExistsPage({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("User Already Exists")),
      body: Center(
        child: Text(
          "User already exists!\nEmail: $email",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
