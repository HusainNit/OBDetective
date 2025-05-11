// Now, let's create a page to list mechanics and launch a map when pressed

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/firestore.dart';

class MechanicsListPage extends StatelessWidget {
  final FirestoreServices _firestoreServices = FirestoreServices();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:
            Text('Available Mechanics', style: TextStyle(color: Colors.white)),
        elevation: 2,
        backgroundColor: Color(0xFF4993EE),
        leading: IconButton(
           icon: Icon(
                  Icons.keyboard_backspace_rounded, color: Colors.white,
                  size: 30,
               ), 
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreServices.getMechanicsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No mechanics available'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var mechanic = snapshot.data!.docs[index];
              final mechanicData = mechanic.data() as Map<String, dynamic>;

              // Extract fields based on your user creation method
              String name = mechanicData['name'] ?? 'Unknown';
              String phone = mechanicData['phone'] ?? 'No phone';
              String email = mechanicData['email'] ?? 'No email';
              String start = mechanicData['start'] ?? '8:00';
              String end = mechanicData['end'] ?? '20:00';
              String spec = mechanicData['speciality'] ?? 'General Speciality';

              final location = _parseLocation(mechanicData);
            

              final bool hasLocation = location != null;
              final double? lat = hasLocation ? location!['latitude'] : null;
              final double? lng = hasLocation ? location!['longitude'] : null;
             
              return Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(0xFF4993EE),
                        child: Icon(Icons.build, color: Colors.white),
                      ),
                      title: Text(name,
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(phone),
                    ),

                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text("Speciality: $spec", style: TextStyle(fontSize: 14)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text("Timing: $start to $end", style: TextStyle(fontSize: 14)),
                    ),
                    ButtonBar(
                      alignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.call, color: Colors.black),
                          label: Text('Call',
                              style: TextStyle(color: Colors.black)),
                          onPressed: () => _makePhoneCall(phone),
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.location_on, color: Colors.black),
                          label: Text('Map',
                              style: TextStyle(color: Colors.black)),
                          onPressed: () {
                            if (lat != null && lng != null) {
                              _launchMaps(lat, lng);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Location not available for this mechanic')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Map<String, dynamic>? _parseLocation(Map<String, dynamic> data) {
    try {
      if (data['location'] is Map) {
        final location = data['location'] as Map<String, dynamic>;
        if (location['latitude'] != null && location['longitude'] != null) {
          return location;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing location: $e');
      return null;
    }
  }
 

  Future<void> _launchMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {}
  }

  void _makePhoneCall(String phoneNumber) async {
    final url = 'tel:$phoneNumber';

    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error making phone call: $e');
    }
  }
}
