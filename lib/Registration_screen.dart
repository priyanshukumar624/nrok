import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

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

  // Handle Google Sign-In for Registration or Login
  Future<void> handleGoogleAuth(BuildContext context, String action) async {
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

        // Define backend URL based on action
        String url = action == 'register'
            ? 'http://192.168.1.4:8080/register'
            : 'http://192.168.1.4:8080/login';

        // Send the request to the backend
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );

        print('Response Status: ${response.statusCode}');
        print('Response Body: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (action == 'register') {
            if (data['status'] == 'success') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      RegistrationSuccessPage(email: user.email),
                ),
              );
            } else if (data['status'] == 'error' &&
                data['message'] == 'User already exists') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserExistsPage(email: user.email),
                ),
              );
            }
          } else if (action == 'login') {
            if (data['status'] == 'success') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginSuccessPage(email: user.email),
                ),
              );
            } else if (data['status'] == 'error' &&
                data['message'] == 'User does not exist') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserDoesNotExistPage(
                    email: user.email,
                    onRegisterWithGoogle:
                        handleGoogleAuth, // Pass function here
                  ),
                ),
              );
            }
          }
        } else if (response.statusCode == 400) {
          // Handle both "User already exists" and "User does not exist" cases
          final jsonResponse = jsonDecode(response.body);

          if (jsonResponse['message'] == 'User already exists') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    UserExistsPage(email: jsonResponse['email']),
              ),
            );
          } else if (jsonResponse['message'] == 'User does not exist') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserDoesNotExistPage(
                  email: jsonResponse['email'],
                  onRegisterWithGoogle: handleGoogleAuth, // Pass function
                ),
              ),
            );
          }
        } else {
          _showErrorDialog(
            context,
            "Failed to connect to backend. Status: ${response.statusCode}\nResponse Body: ${response.body}",
          );
        }
      } else {
        print("Google Sign-In cancelled by user.");
      }
    } catch (e) {
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
      appBar: AppBar(title: Text("Google Authentication")),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator() // Show loading spinner while processing
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => handleGoogleAuth(context, 'register'),
                    child: Text("Register with Google"),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => handleGoogleAuth(context, 'login'),
                    child: Text("Login with Google"),
                  ),
                ],
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

// Login Success Page
class LoginSuccessPage extends StatelessWidget {
  final String email;
  LoginSuccessPage({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login Successful")),
      body: Center(
        child: Text("You are successfully logged in!\nEmail: $email"),
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

// User Does Not Exist Page
class UserDoesNotExistPage extends StatelessWidget {
  final String email;
  final Function(BuildContext, String) onRegisterWithGoogle; // Add callback

  UserDoesNotExistPage({
    required this.email,
    required this.onRegisterWithGoogle, // Pass callback when creating this page
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("User Does Not Exist")),
      body: Center(
        child: Column(
          // Use Column to arrange the text and button vertically
          mainAxisAlignment:
              MainAxisAlignment.center, // Center the content vertically
          children: [
            Text(
              "User does not exist in the database Would you like to Register!\nEmail: $email",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20), // Add spacing between text and button
            ElevatedButton(
              onPressed: () => onRegisterWithGoogle(
                  context, 'register'), // Use passed callback
              child: Text("Register with Google"),
            ),
          ],
        ),
      ),
    );
  }
}
