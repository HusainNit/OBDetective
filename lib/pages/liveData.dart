import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:http/http.dart' as http;

// API key for Gemini API
String apiKey = 'AIzaSyDNsPrRoFRMs4tub_pK-n11617ivgL8TFA';
String apiUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
bool _isRefreshingDTC = false;

class DatahandlerECU extends StatefulWidget {
  const DatahandlerECU({super.key, required this.connection});

  final BluetoothConnection connection;

  @override
  State<DatahandlerECU> createState() => DatahandlerECUState();
}

class DatahandlerECUState extends State<DatahandlerECU> {
  // Connection and data handling
  BluetoothStreamSink get output => widget.connection.output;
  BluetoothConnection get connection => widget.connection;
  StreamSubscription? _readSubscription;
  final List<String> _receivedInput = [];
  Map<String, String> _commandResponses = {};

  // UI state variables
  String errorMessage = '';
  bool _isECUConnected = false;
  bool hasError = false;
  bool _isLoading = false;

  // Command handling
  bool _waitForResponse = false;
  Completer _receivedSignal = Completer();
  String _currentCommand = '';

  // Timers
  Timer? _timeoutTimer;
  Timer? _connectionMonitor;
  Timer? _dataRefreshTimer;

  // OBD Commands
  final List<String> _initCommands = [
    "ATZ", // Reset to defaults
    "ATE0", // Echo off
    "ATL0", // Sets the line feed to 1
    "ATS0", // Sets the space character to 0
    "ATH1", // Sets the header to 1
    "ATSP0", // Set protocol to auto
  ];

  // Live data PIDs
  final Map<String, String> _livePIDs = {
    "0105": "Engine Coolant Temperature",
    "010c": "Engine RPM",
    "010d": "Vehicle Speed",
    "010f": "Intake Air Temperature",
    "0111": "Throttle Position",
    "012f": "Fuel Level",
    "010a": "Fuel Pressure",
    "0142": "Voltage",
  };

  static const int COMMAND_TIMEOUT = 5000; // 5 seconds timeout

  @override
  void initState() {
    super.initState();
    _setupBluetoothListener();
    startConnectionMonitoring();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _connectionMonitor?.cancel();
    _dataRefreshTimer?.cancel();
    widget.connection.dispose();
    _readSubscription?.cancel();
    super.dispose();
  }

  void _setupBluetoothListener() {
    _readSubscription = widget.connection.input?.listen((event) {
      if (mounted) {
        String response = ascii.decode(event).trim();
        setState(() => _receivedInput.add(response));
        if (_waitForResponse) {
          _commandResponses[_currentCommand] = response;
          _waitForResponse = false;
          _timeoutTimer?.cancel();
          if (!_receivedSignal.isCompleted) {
            _receivedSignal.complete();
          }
        }
      }
    });
  }

  void sendData(String text) {
    try {
      output.add(ascii.encode("$text\r"));
    } catch (e) {
      setState(() {
        errorMessage = 'Error sending data: $e';
        hasError = true;
      });
    }
  }

  Future<void> connectToECU() async {
    setState(() {
      _isLoading = true;
    });

    _waitForResponse = false;
    bool allCommandsSuccessful = true;

    // Reset previous command responses
    _commandResponses.clear();

    // Send initialization commands
    for (String command in _initCommands) {
      bool success = await _sendCommandWithTimeout(command);
      if (!success) {
        allCommandsSuccessful = false;
        break;
      }
      await Future.delayed(Duration(milliseconds: 300));
    }

    // If initialization was successful, fetch initial data
    if (allCommandsSuccessful) {
      // Read DTCs
      await _sendCommandWithTimeout("03");

      // Read initial data points
      for (String pid in _livePIDs.keys) {
        await _sendCommandWithTimeout(pid);
        await Future.delayed(Duration(milliseconds: 300));
      }

      // Setup periodic data refresh
      _setupDataRefresh();
    }

    setState(() {
      _isECUConnected = allCommandsSuccessful;
      _isLoading = false;
    });

    if (!allCommandsSuccessful) {
      setState(() {
        errorMessage =
            'Failed to connect to ECU. Please check connections and try again.';
        hasError = true;
      });
    }
  }

  Future<bool> _sendCommandWithTimeout(String command) async {
    _currentCommand = command;
    _waitForResponse = true;
    _receivedSignal = Completer();

    try {
      _timeoutTimer = Timer(Duration(milliseconds: COMMAND_TIMEOUT), () {
        if (!_receivedSignal.isCompleted) {
          _waitForResponse = false;
          _commandResponses[_currentCommand] = "Timeout";
          _receivedSignal.completeError("Timeout");
        }
      });

      sendData(command);
      await _receivedSignal.future;
      return !(_commandResponses[command]?.contains("ERROR") ?? false) &&
          _commandResponses[command] != "Timeout";
    } catch (e) {
      print('Command failed: $command - Error: $e');
      return false;
    } finally {
      _timeoutTimer?.cancel();
      _waitForResponse = false;
    }
  }

  void _setupDataRefresh() {
    _dataRefreshTimer?.cancel();
    _dataRefreshTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      if (!_isECUConnected) {
        timer.cancel();
        return;
      }

      // Refresh critical data more frequently
      await _sendCommandWithTimeout("010c"); // RPM
      await _sendCommandWithTimeout("010d"); // Speed
      await _sendCommandWithTimeout("0111"); // Throttle

      // Every 10 seconds, refresh other data
      if (timer.tick % 5 == 0) {
        for (String pid in _livePIDs.keys) {
          if (pid != "010c" && pid != "010d" && pid != "0111") {
            await _sendCommandWithTimeout(pid);
            await Future.delayed(Duration(milliseconds: 200));
          }
        }
      }
    });
  }

  void startConnectionMonitoring() {
    _connectionMonitor = Timer.periodic(Duration(seconds: 5), (timer) async {
      if (!widget.connection.isConnected) {
        setState(() {
          _isECUConnected = false;
          errorMessage = 'Bluetooth connection lost. Please reconnect.';
          hasError = true;
        });
        _connectionMonitor?.cancel();
        _dataRefreshTimer?.cancel();
      }
    });
  }

  String translateOBDResponse(String pid, String response) {
    if (response == 'N/A' ||
        response.contains('ERROR') ||
        response == 'Timeout') {
      return response;
    }

    try {
      String hex = response.trim().replaceAll('>', '');

      // Validate response format
      if (hex.length < 11) {
        return 'Invalid data format';
      }

      int A = int.parse(hex.substring(9, 11), radix: 16);

      // Check for specific PIDs that need two bytes
      if (pid == '010c') {
        // RPM
        if (hex.length < 13) return 'Invalid data format';
        int B = int.parse(hex.substring(11, 13), radix: 16);
        return '${(((256 * A) + B) / 4).round()}';
      }

      if (pid == '0142') {
        // Voltage
        if (hex.length < 13) return 'Invalid data format';
        int B = int.parse(hex.substring(11, 13), radix: 16);
        return '${((256 * A) + B) / 1000}';
      }

      // Single byte responses
      switch (pid) {
        case '0105': // Coolant Temperature
          return '${A - 40}';
        case '010d': // Speed
          return '$A';
        case '010f': // Intake Air Temperature
          return '${A - 40}';
        case '0111': // Throttle Position
          return '${((A * 100) / 255).round()}';
        case '012f': // Fuel Level
          return '${((A * 100) / 255).round()}';
        case '010a': // Fuel pressure
          return '${3 * A}';
        default:
          return response;
      }
    } catch (e) {
      return 'Error parsing data';
    }
  }

  String getOBDUnit(String pid) {
    switch (pid) {
      case '0105':
        return '°C';
      case '010c':
        return 'RPM';
      case '010d':
        return 'km/h';
      case '010f':
        return '°C';
      case '0111':
        return '%';
      case '012f':
        return '%';
      case '010a':
        return 'PSI';
      case '0142':
        return 'V';
      default:
        return '';
    }
  }

  String Dtctrans(String response) {
    if (response == 'N/A' ||
        response.contains('ERROR') ||
        response == 'Timeout') {
      return response;
    }

    try {
      String hex = response;
      String A = hex.substring(7, 8);
      String B = hex.substring(8, 11);

      switch (A) {
        case '0':
          return 'P0 ${B}';
        case '1':
          return 'P1 ${B}';
        case '2':
          return 'P2 ${B}';
        case '3':
          return 'P3 ${B}';
        case '4':
          return 'C0 ${B}';
        case '5':
          return 'C1 ${B}';
        case '6':
          return 'C2 ${B}';
        case '7':
          return 'C3 ${B}';
        case '8':
          return 'B0 ${B}';
        case '9':
          return 'B1 ${B}';
        case 'A':
          return 'B2 ${B}';
        case 'B':
          return 'B3 ${B}';
        case 'C':
          return 'U0 ${B}';
        case 'D':
          return 'U1 ${B}';

        case 'E':
          return 'U2 ${B}';

        case 'F':
          return 'U3 ${B}';

        default:
          return response;
      }
    } catch (e) {
      return 'Error: Invalid response format';
    }
  }

  Widget _buildStatusIndicator() {
    Color color = _isECUConnected ? Colors.green : Colors.red;
    IconData icon = _isECUConnected ? Icons.check_circle : Icons.error;
    String text = _isECUConnected ? "ECU Connected" : "ECU Not Connected";

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 8),
          Text(text,
              style: TextStyle(color: color, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }

  Widget _buildDataCard(String title, String pid) {
    String value = translateOBDResponse(pid, _commandResponses[pid] ?? 'N/A');
    String unit = getOBDUnit(pid);

    // Determine if it's a critical value to highlight
    bool isCritical = false;
    if (pid == '0105' && value != 'N/A' && value != 'Error parsing data') {
      // Engine temperature above 95°C
      try {
        double temp = double.parse(value);
        if (temp > 95) isCritical = true;
      } catch (_) {}
    }

    // Custom icons for each parameter
    IconData getIconForParameter() {
      switch (pid) {
        case '0105':
          return Icons.thermostat;
        case '010c':
          return Icons.speed;
        case '010d':
          return Icons.directions_car;
        case '010f':
          return Icons.air;
        case '0111':
          return Icons.sync_alt;
        case '012f':
          return Icons.local_gas_station;
        case '010a':
          return Icons.compress;
        case '0142':
          return Icons.battery_charging_full;
        default:
          return Icons.info_outline;
      }
    }

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCritical
            ? BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(getIconForParameter(), color: Colors.blue),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value == 'N/A' ? 'Not Available' : '$value $unit',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: isCritical ? Colors.red : Colors.black87,
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

  Future<void> _showDTCInfoDialog(BuildContext context, String dtc) async {
    if (dtc == 'N/A' || dtc == 'No DTCs found' || dtc.contains('Error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No DTC codes available to explain')),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
            SizedBox(width: 16),
            Text("Fetching DTC Info"),
          ],
        ),
        content: Text("Getting information about $dtc..."),
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
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text("DTC $dtc Information"),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(geminiResponse),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.close, color: Colors.red),
            label: Text("Close", style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> refreshDTCs() async {
    setState(() {
      _isRefreshingDTC = true;
    });

    try {
      // First send a mode 01 PID 01 command to "warm up" the connection
      await _sendCommandWithTimeout("0101");
      await Future.delayed(Duration(milliseconds: 300));

      // Clear previous DTC data
      _commandResponses.remove("03");

      // Send DTC request with retry logic
      bool success = false;
      for (int i = 0; i < 3; i++) {
        // Try up to 3 times
        success = await _sendCommandWithTimeout("03");
        if (success &&
            _commandResponses["03"] != null &&
            !_commandResponses["03"]!.contains("ERROR") &&
            !_commandResponses["03"]!.contains("?")) {
          break;
        }
        await Future.delayed(Duration(milliseconds: 500));
      }

      if (!success) {
        setState(() {
          errorMessage = 'Failed to retrieve DTCs. Try again.';
          hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error refreshing DTCs: $e';
        hasError = true;
      });
    } finally {
      setState(() {
        _isRefreshingDTC = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String dtcValue = Dtctrans(_commandResponses['03'] ?? 'N/A');
    bool hasDTCs = dtcValue != 'No DTCs found' &&
        dtcValue != 'N/A' &&
        !dtcValue.contains('Error');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF4993EE),
        elevation: 0,
        title: Text("Live Data - Engine Diagnostics",
            style: TextStyle(color: Colors.white)),
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
          _buildStatusIndicator(),
          SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Connecting to ECU...", style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : Column(
              children: [
                if (hasError)
                  Container(
                    color: Colors.red.shade100,
                    padding: EdgeInsets.all(12),
                    width: double.infinity,
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red),
                        SizedBox(width: 16),
                        Expanded(
                            child: Text(errorMessage,
                                style: TextStyle(color: Colors.red.shade800))),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red.shade800),
                          onPressed: () {
                            setState(() {
                              hasError = false;
                              errorMessage = '';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _isECUConnected
                      ? RefreshIndicator(
                          onRefresh: () async {
                            // Refresh all data
                            for (String pid in _livePIDs.keys) {
                              await _sendCommandWithTimeout(pid);
                              await Future.delayed(Duration(milliseconds: 200));
                            }
                            await _sendCommandWithTimeout("03"); // Refresh DTCs
                          },
                          child: SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // DTC Section
                                Card(
                                  elevation: 3,
                                  margin: EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: hasDTCs
                                        ? BorderSide(
                                            color: Colors.orange, width: 2)
                                        : BorderSide.none,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  hasDTCs
                                                      ? Icons.warning_amber
                                                      : Icons.check_circle,
                                                  color: hasDTCs
                                                      ? Colors.orange
                                                      : Colors.green,
                                                  size: 24,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  "Diagnostic Trouble Codes",
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.refresh,
                                                color: Colors.blue,
                                              ),
                                              onPressed: _isRefreshingDTC
                                                  ? null
                                                  : refreshDTCs,
                                              tooltip: "Refresh DTCs",
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        _isRefreshingDTC
                                            ? Center(
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 12),
                                                  child: Column(
                                                    children: [
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2),
                                                      SizedBox(height: 8),
                                                      Text("Retrieving DTCs...",
                                                          style: TextStyle(
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic))
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    dtcValue,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: hasDTCs
                                                          ? Colors
                                                              .orange.shade800
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                  if (hasDTCs)
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                          top: 8),
                                                      child:
                                                          OutlinedButton.icon(
                                                        icon: Icon(
                                                            Icons.info_outline,
                                                            size: 16),
                                                        label: Text(
                                                            "View Details"),
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              Colors.blue,
                                                          side: BorderSide(
                                                              color:
                                                                  Colors.blue),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                          ),
                                                        ),
                                                        onPressed: () =>
                                                            _showDTCInfoDialog(
                                                                context,
                                                                dtcValue),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Critical Parameters
                                Text(
                                  "Critical Parameters",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                SizedBox(height: 8),
                                _buildDataCard("Engine RPM", "010c"),
                                _buildDataCard("Vehicle Speed", "010d"),
                                _buildDataCard("Engine Temperature", "0105"),
                                _buildDataCard("Throttle Position", "0111"),

                                SizedBox(height: 16),

                                // Other Parameters
                                Text(
                                  "Other Parameters",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                SizedBox(height: 8),
                                _buildDataCard(
                                    "Intake Air Temperature", "010f"),
                                _buildDataCard("Fuel Level", "012f"),
                                _buildDataCard("Fuel Pressure", "010a"),
                                _buildDataCard("Battery Voltage", "0142"),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.car_repair,
                                  size: 80, color: Colors.grey),
                              SizedBox(height: 24),
                              Text(
                                "Not Connected to ECU",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Connect to access vehicle diagnostics",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: !_isECUConnected
                      ? ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4993EE),
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(Icons.link, color: Colors.white, size: 24),
                          label: Text(
                            "Connect to ECU",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isLoading ? null : connectToECU,
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 43, 139, 46),
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(Icons.check_circle,
                              color: Colors.white, size: 24),
                          label: Text(
                            "Back to Home",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/');
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
