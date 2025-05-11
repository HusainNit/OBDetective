import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/signin.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/firestore.dart';

class TowDash extends StatefulWidget {
  final String towId;
  const TowDash({Key? key, required this.towId}) : super(key: key);

  @override
  State<TowDash> createState() => _TowDashState();
}

class _TowDashState extends State<TowDash> {
  bool isAvailable = true;
  TimeOfDay? availableFrom;
  TimeOfDay? availableTo;
  late FirestoreServices firestoreServices;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    firestoreServices = FirestoreServices();
    _loadInitialAvailability();
  }

  Future<void> _loadInitialAvailability() async {
    try {
      final userDoc = await firestoreServices.users.doc(widget.towId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          isAvailable = data['isAvailable'] ?? true;

          // Load saved availability hours if they exist
          if (data['availableFrom'] != null) {
            final fromParts = (data['availableFrom'] as String).split(':');
            availableFrom = TimeOfDay(
              hour: int.parse(fromParts[0]),
              minute: int.parse(fromParts[1]),
            );
          }

          if (data['availableTo'] != null) {
            final toParts = (data['availableTo'] as String).split(':');
            availableTo = TimeOfDay(
              hour: int.parse(toParts[0]),
              minute: int.parse(toParts[1]),
            );
          }
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackbar('Error loading profile: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF4993EE),
        elevation: 0,
        title: const Text("Tow Truck Dashboard",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading:
            const Icon(Icons.electric_car, color: Colors.transparent, size: 30),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.logout,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Signin(),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
              children: [
                // Header Card
                _buildHeaderCard(),

                // Main Content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadInitialAvailability,
                    color: Color(0xFF4993EE),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView(
                        children: [
                          // Availability Card
                          _buildAvailabilityCard(),
                          const SizedBox(height: 20),

                          // Mechanics List Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Available Mechanics",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.refresh,
                                    color: Color(0xFF4993EE)),
                                onPressed: _loadInitialAvailability,
                              )
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildMechanicsList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Color(0xFF4993EE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: firestoreServices.users.doc(widget.towId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                height: 30,
                width: 30,
                child: CircularProgressIndicator(color: Color(0xFF4993EE)),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.hasError) {
            return const Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 30, color: Color(0xFF4993EE)),
                ),
                SizedBox(width: 15),
                Text(
                  "Welcome Driver",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            );
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          return Row(
            children: [
              Hero(
                tag: 'profile-${widget.towId}',
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  backgroundImage: userData['photoUrl'] != null
                      ? NetworkImage(userData['photoUrl'])
                      : null,
                  child: userData['photoUrl'] == null
                      ? const Icon(Icons.person,
                          size: 50, color: Color(0xFF4993EE))
                      : null,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Welcome Back",
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text(
                      userData['name'] ?? 'Tow Truck Driver',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildStatusIndicator(isAvailable),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusIndicator(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? "Active" : "Inactive",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Availability Status",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Switch(
                  value: isAvailable,
                  onChanged: (value) {
                    setState(() {
                      isAvailable = value;
                    });
                    firestoreServices
                        .updateTowTruckAvailability(widget.towId, value)
                        .then((_) =>
                            _showSuccessSnackbar('Status updated successfully'))
                        .catchError((error) => _showErrorSnackbar(
                            'Failed to update status: $error'));
                  },
                  activeColor: Colors.white,
                  activeTrackColor: Colors.green,
                  inactiveTrackColor: Colors.grey[300],
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            const Text("Set Availability Hours",
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, color: Colors.black),
                    label: Text(
                      availableFrom == null
                          ? "Start Time"
                          : _formatTimeOfDay(availableFrom!),
                      style: TextStyle(color: Colors.black87),
                    ),
                    onPressed: () => _selectTime(context, true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.timelapse, color: Colors.black),
                    label: Text(
                      availableTo == null
                          ? "End Time"
                          : _formatTimeOfDay(availableTo!),
                      style: TextStyle(color: Colors.black87),
                    ),
                    onPressed: () => _selectTime(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            if (availableFrom != null && availableTo != null) ...[
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveAvailabilityHours,
                  child: const Text("Save Hours"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4993EE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _saveAvailabilityHours() {
    if (availableFrom == null || availableTo == null) return;

    try {
      firestoreServices.users.doc(widget.towId).update({
        'availableFrom': '${availableFrom!.hour}:${availableFrom!.minute}',
        'availableTo': '${availableTo!.hour}:${availableTo!.minute}',
      }).then((_) {
        _showSuccessSnackbar("Availability hours updated");
      }).catchError((error) {
        _showErrorSnackbar("Failed to update hours: $error");
      });
    } catch (e) {
      _showErrorSnackbar("Error: $e");
    }
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final hour = timeOfDay.hour.toString().padLeft(2, '0');
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildMechanicsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestoreServices.getMechanicsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 10),
                  Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(color: Color(0xFF4993EE)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Icon(Icons.engineering_outlined,
                      color: Colors.grey, size: 48),
                  const SizedBox(height: 10),
                  const Text(
                    'No mechanics available at the moment',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh"),
                    onPressed: _loadInitialAvailability,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var mechanic = snapshot.data!.docs[index];
            final mechanicData = mechanic.data() as Map<String, dynamic>;

            final location = _parseLocation(mechanicData);
            final bool hasLocation = location != null;
            final double? lat = hasLocation ? location!['latitude'] : null;
            final double? lng = hasLocation ? location!['longitude'] : null;

            return Card(
              color: Colors.grey[200],
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.white,
                      backgroundImage: mechanicData['photoUrl'] != null
                          ? NetworkImage(mechanicData['photoUrl'])
                          : null,
                      child: mechanicData['photoUrl'] == null
                          ? Center(
                              child: const Icon(Icons.engineering,
                                  color: Colors.black, size: 30),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mechanicData['name'] ?? 'Mechanic',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mechanicData['specialization']?.toString() ??
                                'General Mechanic',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                mechanicData['rating']?.toStringAsFixed(1) ??
                                    '4.5',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _buildContactButton(mechanicData),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.directions,
                        color: hasLocation ? Color(0xFF4993EE) : Colors.grey,
                      ),
                      onPressed: hasLocation
                          ? () => _launchMaps(lat!, lng!)
                          : () => _showErrorSnackbar('Location not available'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  Widget _buildContactButton(Map<String, dynamic> mechanicData) {
    final phone = mechanicData['phone']?.toString();

    if (phone == null || phone.isEmpty) {
      return const Text(
        'No contact info',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    return InkWell(
      onTap: () => _launchCall(phone),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone, size: 16, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            phone,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay initialTime = isStartTime
        ? availableFrom ?? TimeOfDay.now()
        : availableTo ?? TimeOfDay.now();

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4993EE),
            ),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          availableFrom = picked;
        } else {
          availableTo = picked;
        }
      });
    }
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      _showErrorSnackbar('Could not launch maps: $e');
    }
  }

  Future<void> _launchCall(String phone) async {
    final url = 'tel:$phone';
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }
}
