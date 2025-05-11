import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/pages/signin.dart';
import 'package:flutter_application_1/firestore.dart';
import 'package:geolocator/geolocator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const Signup());
}

class Signup extends StatelessWidget {
  const Signup({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OBD Detective',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
      ),
      home: const MultiStepSignup(),
    );
  }
}

class MultiStepSignup extends StatefulWidget {
  const MultiStepSignup({super.key});

  @override
  State<MultiStepSignup> createState() => _MultiStepSignupState();
}

class _MultiStepSignupState extends State<MultiStepSignup> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  String _userType = 'normal';

  // User information controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();

  // Location data
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

  // Firestore service
  final FirestoreServices _firestoreServices = FirestoreServices();

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = '';
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationController.text =
            '${position.latitude}, ${position.longitude}';
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: ${e.toString()}';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Check if email already exists
      final QuerySnapshot existingUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      if (existingUsers.docs.isNotEmpty) {
        setState(() {
          _errorMessage = 'Email already in use. Please use a different email.';
          _isLoading = false;
        });
        return;
      }

      // Prepare location data for mechanical users
      Map<String, dynamic>? locationData;
      if (_userType == 'mechanical' &&
          _latitude != null &&
          _longitude != null) {
        locationData = {
          'latitude': _latitude,
          'longitude': _longitude,
          'formatted': _locationController.text.trim()
        };
      }

      // Add user using FirestoreServices
      DocumentReference userRef = await _firestoreServices.addUser(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _userType,
        phone: _userType != 'normal' ? _phoneController.text.trim() : null,
        location: _userType == 'mechanical' ? locationData : null,
        speciality:  _userType == 'mechanical' ? _specialtyController.text : null,
      );

      // Navigate to sign in page after successful signup
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Signin()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Sign Up', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.time_to_leave_rounded,
                    size: 80, color: Colors.black),
                const SizedBox(height: 16),
                const Text(
                  'OBDetective',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Step indicator
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) /
                            (_userType == 'normal' ? 2 : 3),
                        backgroundColor: Colors.grey[300],
                        color: Color(0xFF4993EE),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Step ${_currentStep + 1} of ${_userType == 'normal' ? 2 : 3}',
                      style: const TextStyle(color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Error message if any
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                // Step content
                _buildCurrentStep(),

                const SizedBox(height: 24),

                // Navigation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _currentStep--;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF4993EE),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Back',
                            style: TextStyle(color: Colors.white)),
                      )
                    else
                      const SizedBox(),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_currentStep == 0) {
                                // Validate first step
                                if (_formKey.currentState!.validate()) {
                                  setState(() {
                                    _currentStep++;
                                  });
                                }
                              } else if (_currentStep == 1 &&
                                  _userType == 'normal') {
                                // Final step for normal users
                                _signUp();
                              } else if (_currentStep == 1) {
                                // Next step for other user types
                                setState(() {
                                  _currentStep++;
                                });
                              } else {
                                // Final step for other user types
                                _signUp();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4993EE),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isFinalStep() ? 'Sign Up' : 'Next',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Already have an account?',
                  style: TextStyle(color: Colors.black),
                  textAlign: TextAlign.center,
                ),
                Container(
                  margin: const EdgeInsets.only(top: 0),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Signin(),
                        ),
                      );
                    },
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.black,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isFinalStep() {
    if (_userType == 'normal') {
      return _currentStep == 1;
    } else {
      return _currentStep == 2;
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildUserTypeStep();
      case 2:
        return _buildAdditionalInfoStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Basic Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          decoration: const InputDecoration(
            labelText: 'Confirm Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildUserTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select User Type',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildUserTypeCard(
          title: 'Normal User',
          description: 'Access basic features of the application',
          icon: Icons.person,
          value: 'normal',
        ),
        const SizedBox(height: 12),
        _buildUserTypeCard(
          title: 'Mechanical',
          description: 'For garage owners and mechanics',
          icon: Icons.build,
          value: 'mechanical',
        ),
        const SizedBox(height: 12),
        _buildUserTypeCard(
          title: 'Tow Truck Owner',
          description: 'For Tow truck owners and operators',
          icon: Icons.local_shipping,
          value: 'tow',
        ),
      ],
    );
  }

  Widget _buildUserTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _userType == value;

    return InkWell(
      onTap: () {
        setState(() {
          _userType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 36,
              color: isSelected ? Colors.black : Colors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _userType,
              onChanged: (newValue) {
                setState(() {
                  _userType = newValue!;
                });
              },
              activeColor: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoStep() {
    if (_userType == 'mechanical') {
      return _buildMechanicalInfoStep();
    } else if (_userType == 'tow') {
      return _buildTowInfoStep();
    }
    return const SizedBox();
  }

  Widget _buildMechanicalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mechanical Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _specialtyController,
          decoration: const InputDecoration(
            labelText: 'Specialty',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.name,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your Specialty';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Telephone Number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your telephone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: 'Garage Location (Latitude, Longitude)',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: _isLoadingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.my_location),
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              tooltip: 'Get Current Location',
            ),
          ),
          readOnly: true, // Makes the field non-editable by keyboard
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please set your garage location';
            }
            return null;
          },
        ),
        if (_latitude != null && _longitude != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Your location has been set successfully.',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTowInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tow Truck Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Telephone Number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your telephone number';
            }
            return null;
          },
        ),
      ],
    );
  }
}
