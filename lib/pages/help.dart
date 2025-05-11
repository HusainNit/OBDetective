import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_application_1/firestore.dart';

final FirestoreServices firestoreServices = FirestoreServices();

void main() {
  runApp(const MaterialApp(home: Help()));
}

class Help extends StatefulWidget {
  const Help({super.key});

  @override
  State<Help> createState() => _HelpState();
}

class _HelpState extends State<Help> {
  String _locationMessage = 'Fetching location...';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      setState(() {
        _locationMessage = 'Location permission denied';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationMessage = 'Location services are disabled';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationMessage = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationMessage = 'Location permissions permanently denied';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _locationMessage =
            "Your Location: \n${position.latitude.toStringAsFixed(4)}° ${position.latitude > 0 ? 'N' : 'S'} : ${position.longitude.toStringAsFixed(4)}° ${position.longitude > 0 ? 'E' : 'W'}";
      });
    } catch (e) {
      setState(() {
        _locationMessage = 'Error getting location: $e';
      });
    }
  }

  Future<void> _sendWhatsAppMessage(String name, String phoneNumber) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available yet')),
      );
      return;
    }

    final message =
        'Hi $name, Help me I\'m stuck here. This is my current location: https://www.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = "https://wa.me/$phoneNumber?text=$encodedMessage";

    launchUrl(Uri.parse(whatsappUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF4993EE),
        centerTitle: true,
        title:
            const Text("Contact Help ", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(
            Icons.keyboard_backspace_rounded,
            color: Colors.white,
            size: 30,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // Status display for location
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _locationMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
                stream: firestoreServices.getAllTowTrucksStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  //if we have data, get all the docs
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    List towList = snapshot.data!.docs;

                    // display as a list
                    return ListView.builder(
                        itemCount: towList.length,
                        itemBuilder: (context, index) {
                          // get each individual doc
                          DocumentSnapshot document = towList[index];

                          //get data of each doc
                          Map<String, dynamic> data =
                              document.data() as Map<String, dynamic>;
                          String name = data['name'];
                          String telephone = data['phone'];

                          // display as a list tile
                          return Card(
                            color: Colors.grey[200],
                            margin: const EdgeInsets.all(7),
                            elevation: 2,
                            child: ListTile(
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(telephone),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(
                                          text:
                                              'For help, please contact $name at $telephone'));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Contact info copied to clipboard'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy,
                                        color: Colors.grey),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _sendWhatsAppMessage(name, telephone);
                                    },
                                    icon: const Icon(Icons.message,
                                        color: Colors.green),
                                  ),
                                ],
                              ),
                              leading: const Icon(
                                Icons.local_taxi,
                                color: Colors.black,
                                size: 35,
                              ),
                            ),
                          );
                        });
                  }
                  // if there are no results
                  else {
                    return const Center(child: Text('No tow trucks available'));
                  }
                }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Color(0xFF4993EE),
        onPressed: _getCurrentLocation,
        label: const Text(
          "Refresh Location",
          style: TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}
