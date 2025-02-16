import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as locationPackage;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController mapController;
  locationPackage.LocationData? currentLocation;
  TextEditingController destinationController = TextEditingController();
  List<Map<String, dynamic>> dummyHelpers = [
    {'name': 'Helper 1', 'id': '1'},
    {'name': 'Helper 2', 'id': '2'},
    {'name': 'Roadside Assist', 'id': '3'},
  ];
  List<LatLng> routePoints = [];
  LatLng? destination;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _requestPermission();
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    final location = locationPackage.Location();
    try {
      // Enable location service
      await location.serviceEnabled();
      await location.requestService();

      // Get location updates
      location.onLocationChanged.listen((locationData) {
        setState(() {
          currentLocation = locationData;
          if (mapController != null) {
            mapController.move(
              LatLng(locationData.latitude!, locationData.longitude!),
              14,
            );
          }
        });
      });
    } catch (e) {
      print("Location error: $e");
    }
  }

  void _updateCamera() {
    if (currentLocation != null) {
      mapController.move(
        LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        14,
      );
    }
  }

  Future<void> _searchDestination() async {
    if (destinationController.text.isEmpty) return;

    try {
      final response = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${destinationController.text}&format=json'));

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final firstResult = results.first;
          setState(() {
            destination = LatLng(
              double.parse(firstResult['lat']),
              double.parse(firstResult['lon']),
            );
          });
          _getDirections(destination!);
        }
      }
    } catch (e) {
      print("Error geocoding: $e");
    }
  }

  Future<void> _getDirections(LatLng destination) async {
    if (currentLocation == null) return;

    final start =
        LatLng(currentLocation!.latitude!, currentLocation!.longitude!);

    try {
      final response = await http.get(Uri.parse(
          'http://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${destination.longitude},${destination.latitude}?overview=full'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok') {
          _drawPolyline(data);
        }
      }
    } catch (e) {
      print("Error getting directions: $e");
    }
  }

  void _drawPolyline(Map<String, dynamic> data) {
    final geometry = data['routes'][0]['geometry'];
    setState(() {
      routePoints = _decodePolyline(geometry);
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  void _sendRequest() {
    if (dummyHelpers.isNotEmpty) {
      final helper = dummyHelpers.first;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Request Sent'),
          content: Text('Assistance request sent to ${helper['name']}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Roadside Assistance')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              controller: destinationController,
              decoration: InputDecoration(
                hintText: 'Enter destination',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _searchDestination,
                ),
              ),
              onSubmitted: (_) => _searchDestination(),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: currentLocation != null
                    ? LatLng(
                        currentLocation!.latitude!, currentLocation!.longitude!)
                    : LatLng(26.2285, 50.5860), // Manama, Bahrain coordinates
                initialZoom: 12,
                minZoom: 3,
                maxZoom: 18,
                keepAlive: true,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                  enableMultiFingerGestureRace: true,
                ),
                onTap: (tapPosition, point) {
                  setState(() {
                    destination = point;
                    destinationController.text =
                        "${point.latitude}, ${point.longitude}";
                    if (currentLocation != null) {
                      _getDirections(point);
                    }
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.obdetective',
                ),
                MarkerLayer(
                  markers: [
                    if (currentLocation != null)
                      Marker(
                        point: LatLng(currentLocation!.latitude!,
                            currentLocation!.longitude!),
                        width: 40,
                        height: 40,
                        child: Icon(Icons.location_on, color: Colors.red),
                      ),
                    if (destination != null)
                      Marker(
                        point: destination!,
                        width: 40,
                        height: 40,
                        child: Icon(Icons.flag, color: Colors.green),
                      ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    if (routePoints.isNotEmpty)
                      Polyline(
                        points: routePoints,
                        color: Colors.blue,
                        strokeWidth: 4,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _sendRequest,
              child: Text('Request Assistance'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
