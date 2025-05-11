import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/home.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

// List of demo DTC codes with descriptions
final List<Map<String, String>> demoDataList = [
  {
    "code": "P0022",
    "name": "Camshaft Position - Timing Over-Retarded (Bank 2)",
    "severity": "Medium"
  },
  {
    "code": "P0300",
    "name": "Random/Multiple Cylinder Misfire Detected",
    "severity": "High"
  },
  {"code": "P0171", "name": "System Too Lean (Bank 1)", "severity": "Medium"},
  {
    "code": "P0420",
    "name": "Catalyst System Efficiency Below Threshold",
    "severity": "Medium"
  },
  {
    "code": "P0455",
    "name": "Evaporative Emission System Leak Detected",
    "severity": "Low"
  },
];

// OBD2 Parameters with demo values
final Map<String, Map<String, dynamic>> obd2Parameters = {
  "speed": {
    "value": 72,
    "unit": "km/h",
    "icon": Icons.speed,
    "min": 0,
    "max": 180,
    "normalRange": [0, 120]
  },
  "rpm": {
    "value": 2100,
    "unit": "RPM",
    "icon": Icons.speed_outlined,
    "min": 0,
    "max": 8000,
    "normalRange": [600, 3000]
  },
  "coolant_temp": {
    "value": 88,
    "unit": "°C",
    "icon": Icons.thermostat,
    "min": -40,
    "max": 120,
    "normalRange": [80, 100]
  },
  "intake_temp": {
    "value": 32,
    "unit": "°C",
    "icon": Icons.air,
    "min": -40,
    "max": 100,
    "normalRange": [10, 50]
  },
  "throttle_pos": {
    "value": 24,
    "unit": "%",
    "icon": Icons.open_in_full,
    "min": 0,
    "max": 100,
    "normalRange": [0, 90]
  },
  "maf": {
    "value": 8.2,
    "unit": "g/s",
    "icon": Icons.wind_power,
    "min": 0,
    "max": 30,
    "normalRange": [2, 15]
  },
  "engine_load": {
    "value": 45,
    "unit": "%",
    "icon": Icons.engineering,
    "min": 0,
    "max": 100,
    "normalRange": [10, 80]
  },
  "fuel_pressure": {
    "value": 350,
    "unit": "kPa",
    "icon": Icons.local_gas_station,
    "min": 0,
    "max": 800,
    "normalRange": [200, 500]
  },
};

// API Key
String apiKey = 'AIzaSyDNsPrRoFRMs4tub_pK-n11617ivgL8TFA';
String apiUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

void main() {
  runApp(const Demo());
}

class Demo extends StatelessWidget {
  const Demo({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        scaffoldBackgroundColor: Colors.grey[50],
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF4993EE),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      child: Scaffold(
        body: DemoD(title: 'OBD2 Vehicle Monitor'),
      ),
    );
  }
}

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
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _showMechanicDialog(context, dtc);
          },
          child: Text("Send to Mechanic"),
        ),
      ],
    ),
  );
}

void _showMechanicDialog(BuildContext context, String dtc) {
  final mechanics = [
    {
      "name": "Monem Auto Repair",
      "phone": "+97337799905",
      "specialty": "German Cars"
    },
    {
      "name": "Hussain Garage",
      "phone": "+97338341436",
      "specialty": "Japanese Cars"
    },
    {
      "name": "Quick Fix Mechanics",
      "phone": "+15556667777",
      "specialty": "American Cars"
    },
    {
      "name": "Euro Auto Center",
      "phone": "+97333445566",
      "specialty": "European Cars"
    },
    {
      "name": "Al Manama Diagnostics",
      "phone": "+97337122273",
      "specialty": "Electronic Diagnostics"
    },
  ];

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Send to Mechanic"),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Select a mechanic to send DTC $dtc:"),
            SizedBox(height: 16),
            Container(
              constraints: BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: mechanics.length,
                separatorBuilder: (context, index) => Divider(height: 1),
                itemBuilder: (context, index) => ListTile(
                  title: Text(mechanics[index]["name"]!),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mechanics[index]["phone"]!),
                      Text(
                        mechanics[index]["specialty"]!,
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _sendWhatsAppMessage(mechanics[index]["phone"]!, dtc);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Cancel"),
        ),
      ],
    ),
  );
}

void _sendWhatsAppMessage(String phone, String dtc) {
  final message = "Hi, I need help with DTC code: $dtc";
  final encodedMessage = Uri.encodeComponent(message);
  final whatsappUrl = "https://wa.me/$phone?text=$encodedMessage";

  launchUrl(Uri.parse(whatsappUrl));
}

class DemoD extends StatefulWidget {
  const DemoD({super.key, required this.title});

  final String title;

  @override
  State<DemoD> createState() => _DemoDState();
}

class _DemoDState extends State<DemoD> {
  int _selectedIndex = 0;
  bool _isConnected = false;
  bool _isScanning = false;

  Color getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case "high":
        return Colors.red[100]!;
      case "medium":
        return Colors.orange[100]!;
      case "low":
        return Colors.green[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  Color getSeverityTextColor(String severity) {
    switch (severity.toLowerCase()) {
      case "high":
        return Colors.red[800]!;
      case "medium":
        return Colors.orange[800]!;
      case "low":
        return Colors.green[800]!;
      default:
        return Colors.grey[800]!;
    }
  }

  Color getParameterColor(String paramKey) {
    final param = obd2Parameters[paramKey]!;
    final value = param['value'];
    final min = param['normalRange'][0];
    final max = param['normalRange'][1];

    if (value < min || value > max) {
      return Colors.red[100]!;
    }
    return Colors.grey[50]!;
  }

  Color getParameterTextColor(String paramKey) {
    final param = obd2Parameters[paramKey]!;
    final value = param['value'];
    final min = param['normalRange'][0];
    final max = param['normalRange'][1];

    if (value < min || value > max) {
      return Colors.red[800]!;
    }
    return Colors.grey[800]!;
  }

  void _connectToOBD() {
    setState(() {
      _isScanning = true;
    });

    // Simulate connection process
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _isConnected = true;
        _isScanning = false;
      });
    });
  }

  void _disconnectOBD() {
    setState(() {
      _isConnected = false;
    });
  }

  void _simulateDriving() {
    // Simulate changing values while driving
    if (!_isConnected) return;

    setState(() {
      obd2Parameters['speed']!['value'] =
          (obd2Parameters['speed']!['value'] + 5) % 120;
      obd2Parameters['rpm']!['value'] =
          (obd2Parameters['rpm']!['value'] + 100) % 3500;
      obd2Parameters['coolant_temp']!['value'] =
          85 + (DateTime.now().second % 10);
      obd2Parameters['throttle_pos']!['value'] =
          (obd2Parameters['throttle_pos']!['value'] + 2) % 50;
      obd2Parameters['engine_load']!['value'] =
          (obd2Parameters['engine_load']!['value'] + 3) % 80;
    });
  }

  @override
  void initState() {
    super.initState();
    // Start simulating data changes
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isConnected) {
        _simulateDriving();
      }
    });
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Connection status card
          Card(
            elevation: 2,
            color: Colors.grey[200],
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: _isConnected ? Colors.blue : Colors.grey,
                        size: 30,
                      ),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isConnected ? "Connected to OBD2" : "Disconnected",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _isConnected
                                ? "Vehicle data available"
                                : "Connect to view live data",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      if (!_isConnected)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isScanning ? null : _connectToOBD,
                          child: _isScanning
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text("Connect",
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold)),
                        )
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _disconnectOBD,
                          child: Text("Disconnect",
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  if (_isConnected) ...[
                    SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: 1.0,
                      backgroundColor: Colors.green[50],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // Main vehicle parameters
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildParameterCard("speed"),
              _buildParameterCard("rpm"),
              _buildParameterCard("coolant_temp"),
              _buildParameterCard("engine_load"),
            ],
          ),

          SizedBox(height: 24),

          // Secondary parameters
          Text(
            "Additional Parameters",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildSmallParameterCard("intake_temp"),
              _buildSmallParameterCard("throttle_pos"),
              _buildSmallParameterCard("maf"),
              _buildSmallParameterCard("fuel_pressure"),
            ],
          ),

          SizedBox(height: 24),

          // DTC Status
          Card(
            color: Colors.grey[200],
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        "Diagnostic Trouble Codes",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Spacer(),
                      Chip(
                        label: Text("${demoDataList.length} Active"),
                        backgroundColor: Colors.red[50],
                        labelStyle: TextStyle(color: Colors.red[800]),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Your vehicle has ${demoDataList.length} active trouble codes. "
                    "Some parameters may be affected.",
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedIndex = 1; // Switch to DTC tab
                        });
                      },
                      child: Text("View DTC Codes",
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildParameterCard(String paramKey) {
    final param = obd2Parameters[paramKey]!;
    final isWarning = param['value'] < param['normalRange'][0] ||
        param['value'] > param['normalRange'][1];

    return Card(
      elevation: 2,
      color: getParameterColor(paramKey),
      child: Container(
        padding: EdgeInsets.all(5),
        margin: EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(param['icon'],
                    size: 24, color: getParameterTextColor(paramKey)),
                Text(
                  paramKey.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: getParameterTextColor(paramKey),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isWarning) ...[
                  Icon(Icons.warning, size: 16, color: Colors.red),
                ],
              ],
            ),
            Text(
              "${param['value']} ${param['unit']}",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: getParameterTextColor(paramKey),
              ),
            ),
            LinearProgressIndicator(
              value: (param['value'] - param['min']) /
                  (param['max'] - param['min']),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isWarning ? Colors.orange : Colors.blue,
              ),
            ),
            Spacer(),
            Center(
              child: Column(
                children: [
                  Text(
                    "${param['min']}${param['unit']}",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    "Normal: ${param['normalRange'][0]} - ${param['normalRange'][1]}${param['unit']}",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    "${param['max']}${param['unit']}",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallParameterCard(String paramKey) {
    final param = obd2Parameters[paramKey]!;
    final isWarning = param['value'] < param['normalRange'][0] ||
        param['value'] > param['normalRange'][1];

    return Card(
      elevation: 1,
      color: getParameterColor(paramKey),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(param['icon'],
                    size: 16, color: getParameterTextColor(paramKey)),
                if (isWarning) ...[
                  SizedBox(width: 4),
                  Icon(Icons.warning, size: 12, color: Colors.red),
                ],
              ],
            ),
            SizedBox(height: 4),
            Text(
              paramKey.replaceAll('_', ' '),
              style: TextStyle(
                fontSize: 10,
                color: getParameterTextColor(paramKey),
              ),
            ),
            Text(
              "${param['value']} ${param['unit']}",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: getParameterTextColor(paramKey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDtcTab() {
    return Column(
      children: [
        // Header with nice typography
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text(
                "ACTIVE DTC CODES",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              Spacer(),
              Text(
                "Live Data",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),

        // DTC Code List
        Expanded(
          child: ListView.builder(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: demoDataList.length,
            itemBuilder: (context, index) {
              final dtcData = demoDataList[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        _showGeminiResponseDialog(context, dtcData["code"]!),
                    splashColor: Colors.blue.withOpacity(0.1),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // DTC Code with chip style
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  dtcData["code"]!,
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),

                              Spacer(),

                              // Severity indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: getSeverityColor(dtcData["severity"]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  dtcData["severity"]!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: getSeverityTextColor(
                                        dtcData["severity"]!),
                                  ),
                                ),
                              ),

                              SizedBox(width: 8),

                              // Action button
                              IconButton.filledTonal(
                                onPressed: () => _showMechanicDialog(
                                    context, dtcData["code"]!),
                                icon: Icon(Icons.send_rounded, size: 20),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.grey[50],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 12),

                          // Code description
                          Text(
                            dtcData["name"]!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          SizedBox(height: 8),

                          // Info text
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text(
                                "Tap for details",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Demo Mode"),
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
          actions: [
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("About OBD2 Monitor"),
                    content: Text(
                        "This app connects to your vehicle's OBD2 port to monitor live data "
                        "and read Diagnostic Trouble Codes (DTCs).\n\n"
                        "Features:\n"
                        "- Real-time vehicle parameters\n"
                        "- DTC code explanations\n"
                        "- Mechanic contact integration\n\n"
                        "Note: This is a demo version using simulated data."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text("Close"),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardTab(),
          _buildDtcTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey[200],
        selectedItemColor: Color(0xFF4993EE),
        unselectedItemColor: const Color.fromARGB(106, 117, 117, 117),
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.error_outline),
            label: "DTC Codes",
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              backgroundColor: Color(0xFF4993EE),
              onPressed: () {
                // Refresh data action
                setState(() {
                  if (_isConnected) {
                    _simulateDriving();
                  }
                });
              },
              child: Icon(Icons.refresh, color: Colors.white),
              tooltip: "Refresh Data",
            )
          : FloatingActionButton(
              backgroundColor: Color(0xFF4993EE),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Container(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Enter DTC Code",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: "Example: P0300",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.code,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showGeminiResponseDialog(context, "P0300");
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                          ),
                          child: Text("Look Up Code"),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Icon(Icons.add, color: Colors.white),
              tooltip: "Enter DTC Code",
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
