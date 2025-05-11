import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/pages/cars.dart';
import 'package:flutter_application_1/pages/mechanic.dart';
import 'package:flutter_application_1/pages/signup.dart';
import 'package:flutter_application_1/firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_application_1/pages/towDash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const Signin());
}

final FirestoreServices firestoreServices = FirestoreServices();
final TextEditingController _emailController = TextEditingController();
final TextEditingController _passwordController = TextEditingController();

class Signin extends StatefulWidget {
  const Signin({super.key});

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      // Basic validation
      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = 'Email and password cannot be empty';
          _isLoading = false;
        });
        return;
      }

      // Direct Firestore query for user authentication
      final QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userSnapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = 'User not found';
          _isLoading = false;
        });
        return;
      }

      // Get the first matching document
      final userDoc = userSnapshot.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;
      final userId = userDoc.id; // Get the document ID

      // Verify password
      if (userData['password'] != password) {
        setState(() {
          _errorMessage = 'Incorrect password';
          _isLoading = false;
        });
        return;
      }
      // Route user based on userType
      if (!mounted) return;

      // Check user type and navigate to appropriate page
      final String userType = userData['userType'] ?? '';

      if (userType == 'mechanical') {
        // Navigate to MechanicDashboard for mechanical users
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => MechanicDash(userId: userId)));
      } else if (userType == 'tow') {
        // Navigate to tow truck dashboard for tow users
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => TowDash(towId: userId)));
      } else {
        // Default navigation to Car page for regular users
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => Car(userId: userId)));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
      print('Error during sign in: $e');
    }
  }

  String genreateRandomUserId() {
    return Random().nextInt(10000).toString();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OBD Detective',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
      ),
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height - 600,
                ),
                Icon(Icons.time_to_leave_rounded,
                    size: 100, color: const Color(0xFF000000)),

                // title
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text(
                    'OBDetective',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 30,
                        fontWeight: FontWeight.bold),
                  ),
                ),

                // Text field for Email
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7,
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Email',
                      hintStyle: TextStyle(color: Colors.black54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Text field for password
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7,
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Colors.black54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                    ),
                  ),
                ),

                // Error message
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                const SizedBox(height: 20),

                // Sign in button
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all(const Color(0xFF4993EE)),
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        )),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Log in',
                            style: TextStyle(color: Colors.white, fontSize: 25),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Text Don't have an account
                const Text(
                  'Don\'t have an account?',
                  style: TextStyle(color: Colors.black),
                ),

                // link for new account
                TextButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const Signup()));
                  },
                  child: const Text(
                    'Sign up',
                    style: TextStyle(
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
