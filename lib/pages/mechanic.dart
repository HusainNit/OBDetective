import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/signin.dart';
import 'package:flutter_application_1/firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

final FirestoreServices firestoreServices = FirestoreServices();

TextEditingController search = TextEditingController();
TextEditingController Speciality = TextEditingController();
TimeOfDay? availableFrom;
TimeOfDay? availableTo;
bool editable = false;
String spec = "";

class MechanicDash extends StatefulWidget {
  final String userId;

  const MechanicDash({super.key, required this.userId});

  @override
  State<MechanicDash> createState() => _MechanicDashState();
}

class _MechanicDashState extends State<MechanicDash> {
  @override
  void initState() {
    super.initState();
    _loadSpec();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Color(0xFF4993EE),
          title:
              Text("Mechanic Dashboard", style: TextStyle(color: Colors.white)),
          leading: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Signin(),
                ),
              );
            },
            icon: Icon(
              Icons.keyboard_backspace_rounded,
              color: Colors.white,
              size: 30,
            ),
          )),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                            child: Text(
                              "Speciality",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                            child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    editable = false;
                                  });
                                  firestoreServices.updateMechanicSpec(
                                      widget.userId, Speciality.text);
                                  _loadSpec();
                                },
                                child: Text(
                                  "Edit",
                                  style: TextStyle(
                                      color: CupertinoColors.inactiveGray,
                                      fontWeight: FontWeight.w500),
                                )),
                          ),
                        ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                      child: Divider(
                        thickness: 2,
                      ),
                    ),
                    ListTile(
                      title: TextField(
                        controller: Speciality,
                        enabled: editable,
                        decoration: InputDecoration(hintText: spec),
                      ),
                      trailing: IconButton(
                          onPressed: () {
                            setState(() {
                              editable = true;
                            });
                          },
                          icon: Icon(Icons.edit)),
                    )
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                            child: Text(
                              "Timings",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                            child: TextButton(
                                onPressed: () {
                                  firestoreServices.updateMechanicTiming(
                                      widget.userId,
                                      availableFrom!.format(context),
                                      availableTo!.format(context));
                                },
                                child: Text(
                                  "Save",
                                  style: TextStyle(
                                      color: CupertinoColors.inactiveGray,
                                      fontWeight: FontWeight.w500),
                                )),
                          ),
                        ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                      child: Divider(
                        thickness: 2,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time,
                                  color: Colors.black),
                              label: Text(
                                availableFrom == null
                                    ? "Start Time"
                                    : _formatTimeOfDay(availableFrom!),
                                style: TextStyle(color: Colors.black87),
                              ),
                              onPressed: () => _selectTime(context, true),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.timelapse,
                                  color: Colors.black),
                              label: Text(
                                availableTo == null
                                    ? "End Time"
                                    : _formatTimeOfDay(availableTo!),
                                style: TextStyle(color: Colors.black87),
                              ),
                              onPressed: () => _selectTime(context, false),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                            child: Text(
                              "AI DTC ",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                            child: TextButton(
                                onPressed: () {
                                  RegExp exp =
                                      RegExp(r'^[PCBU]{1}[0-3]{1}[A-F0-9]{3}$');

                                  if (exp.hasMatch(search.text)) {
                                    _showGeminiResponseDialog(
                                        context, search.text);
                                  } else {
                                    search.text = "";
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text("Wrong DTC Format!"),
                                      backgroundColor: Colors.redAccent,
                                    ));
                                  }
                                },
                                child: Text(
                                  "Search",
                                  style: TextStyle(
                                      color: CupertinoColors.inactiveGray,
                                      fontWeight: FontWeight.w500),
                                )),
                          ),
                        ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                      child: Divider(
                        thickness: 2,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: TextField(
                        controller: search,
                        decoration: InputDecoration(
                            hintText: "P0001",
                            border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.grey, width: 0.5))),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSpec() async {
    final userDoc = await firestoreServices.users.doc(widget.userId).get();
    final data = userDoc.data() as Map<String, dynamic>;
    setState(() {
      spec = data['speciality'] ?? 'General Speciality';
    });
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
}

// API Key
String apiKey = 'AIzaSyDNsPrRoFRMs4tub_pK-n11617ivgL8TFA';
String apiUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

Future<String> fetchGeminiResponse(String dtc) async {
  try {
    final response = await http.post(
      Uri.parse('$apiUrl?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": "Explain the DTC code $dtc for a vehicle. "
                    "Provide:\n1. Code meaning\n2. Common causes\n"
                    "3. Symptoms\n4. Diagnostic steps\n"
                    "5. Possible solutions\n"
                    "Format as clear bullet points with headings."
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.2,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
        }
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return _parseGeminiResponse(responseData);
    } else {
      print('API Error: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  } catch (e) {
    print('Exception caught: $e');
    return "Error getting information: ${e.toString()}\n\n"
        "Please check your API key and internet connection and try again.";
  }
}

String _parseGeminiResponse(Map<String, dynamic> response) {
  try {
    final candidates = response['candidates'];
    if (candidates == null || candidates.isEmpty) {
      return "No response from Gemini API";
    }

    final content = candidates[0]['content'];
    if (content == null) {
      return "Malformed API response";
    }

    final parts = content['parts'];
    if (parts == null || parts.isEmpty) {
      return "No content in response";
    }

    return parts[0]['text'] ?? "No text in response";
  } catch (e) {
    return "Error parsing response: $e";
  }
}

Future<void> _showGeminiResponseDialog(BuildContext context, String dtc) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text("Fetching DTC Info"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Getting information about $dtc..."),
        ],
      ),
    ),
  );

  String geminiResponse;
  try {
    geminiResponse = await fetchGeminiResponse(dtc);
  } catch (e) {
    geminiResponse = "Failed to get DTC information: $e";
  }

  if (!context.mounted) return;
  Navigator.of(context).pop(); // Close loading dialog

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("DTC $dtc Information"),
      content: SingleChildScrollView(
        child: Text(geminiResponse),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Close"),
        ),
      ],
    ),
  );
}

String _formatTimeOfDay(TimeOfDay timeOfDay) {
  final hour = timeOfDay.hour.toString().padLeft(2, '0');
  final minute = timeOfDay.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
