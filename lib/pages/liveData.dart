import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obdetective/pages/BluetoothHandler.dart';
import 'package:obdetective/pages/ECUconnection.dart';
import 'package:obdetective/settings_manager.dart';

class Livedata extends ConsumerStatefulWidget {
  const Livedata({super.key});

  @override
  ConsumerState<Livedata> createState() => _LivedataState();
}

class _LivedataState extends ConsumerState<Livedata> {
  BluetoothConnection get connections =>
      ref.watch(bluetoothConnectionProvider)!;
  //BluetoothStreamSink get outputs => connections.output;
  StreamSubscription? _readSubscriptions;
  //final List<String> _receivedInput = [];
  final Map<String, String> _commandResponsesMode1 = {};

  String unexpectedErrorMessages = '';
  String selectedProtocol = SettingsManager.protocol;
  int selectedTimeout = 5000;
  bool hasErrors = false;
  bool _waitForResponse = false;
  final Completer _receivedSignal = Completer();
  final String _currentCommands = '';
  // String _errorECU = '';
  // static const int COMMAND_TIMEOUT = 5000; // 5 seconds timeout
  Timer? _timeoutTimer;
  Timer? _connectionMonitor;
  Timer? _refreshTimer;
  static const Map<String, String> OBD_SERVICES = {
    'Show Current Data': '01',
  };
  static const Map<String, String> MODE01_PIDS = {
    'Engine RPM': '0C',
    'Vehicle Speed': '0D',
    'Engine Coolant Temperature': '05',
    'Throttle Position': '11',
    'O2 Sensors': '13',
  };

  @override
  void initState() {
    super.initState();

    _refreshTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (connections.isConnected && !_waitForResponse) {
        // Request each PID
        _commandResponsesMode1[MODE01_PIDS['Engine RPM']!] =
            await requestLiveData(MODE01_PIDS['Engine RPM']!) ?? 'N/A';
        _commandResponsesMode1[MODE01_PIDS['Vehicle Speed']!] =
            await requestLiveData(MODE01_PIDS['Vehicle Speed']!) ?? 'N/A';
        _commandResponsesMode1[MODE01_PIDS['Engine Coolant Temperature']!] =
            await requestLiveData(MODE01_PIDS['Engine Coolant Temperature']!) ??
                'N/A';
        _commandResponsesMode1[MODE01_PIDS['Throttle Position']!] =
            await requestLiveData(MODE01_PIDS['Throttle Position']!) ?? 'N/A';

        setState(() {});
      }
    });
    if (connections != null) {
      receiveData();
      startConnectionMonitoring();
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _refreshTimer?.cancel();
    //_connectionMonitor?.cancel();
    _readSubscriptions?.cancel();
    super.dispose();
  }

  Future<void> receiveData() async {
    _readSubscriptions = connections.input?.listen(
      (event) {
        if (!mounted) return;

        try {
          //ref.read(readSubscriptionProvider.notifier).state = _readSubscription;
          final response = ascii.decode(event).trim();
          //setState(() => _receivedInput.add(response));

          if (_waitForResponse) {
            _commandResponsesMode1[_currentCommands] = response;
            _waitForResponse = false;
            _timeoutTimer?.cancel();
            if (!_receivedSignal.isCompleted) {
              _receivedSignal.complete();
            }
          }
        } catch (e) {
          setState(() {
            unexpectedErrorMessages = 'Decoding error: $e';
            hasErrors = true;
          });
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          unexpectedErrorMessages = 'Data stream error: $error';
          hasErrors = true;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          unexpectedErrorMessages = 'Data stream closed';
          hasErrors = true;
        });
      },
    );
  }

  Future<void> sendData(String text) async {
    try {
      if (connections.output == null) {
        throw Exception('Output stream not available');
      }
      connections.output.add(ascii.encode(text));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        unexpectedErrorMessages = 'Error sending data: $e';
        hasErrors = true;
      });
    }
  }

  Future<String?> requestLiveData(String pid) async {
    if (!connections.isConnected) return null;
    final mode = OBD_SERVICES['Show Current Data'] ?? '01';
    final command = '$mode$pid';
    _waitForResponse = true;

    try {
      await sendData('$command\r');

      _timeoutTimer = Timer(Duration(milliseconds: (selectedTimeout)), () {
        if (!_receivedSignal.isCompleted) {
          _receivedSignal.completeError('Timeout');
          _waitForResponse = false;
        }
      });

      await _receivedSignal.future;

      // Get the response and validate it
      final response = _commandResponsesMode1[command];
      if (response == null || !response.startsWith('41')) {
        throw Exception('Invalid response: $response');
      }

      return response;
    } catch (e) {
      setState(() {
        unexpectedErrorMessages = 'Error requesting live data: $e';
        hasErrors = true;
      });
      return null;
    } finally {
      _timeoutTimer?.cancel();
      _waitForResponse = false;
    }
  }

  void startConnectionMonitoring() {
    _connectionMonitor = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!connections.isConnected) {
        setState(() {
          unexpectedErrorMessages = 'Connection lost';
          hasErrors = true;
        });
        _connectionMonitor?.cancel();
        handleConnectionError();
      }
    });
  }

  void handleConnectionError() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Connection Error'),
          content: const Text('Lost connection to OBD device'),
          actions: [
            TextButton(
              child: const Text('Return'),
              onPressed: () {
                // _readSubscription?.cancel();
                // _refreshTimer?.cancel();
                // _connectionMonitor?.cancel();
                // _timeoutTimer?.cancel();
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Exit page
              },
            ),
          ],
        );
      },
    );
  }

  int hexToInt(String hex) => int.parse(hex, radix: 16);

  double calculateEngineRPM(String hexValue) {
    try {
      final A = hexToInt(hexValue.substring(0, 2));
      final B = hexToInt(hexValue.substring(2, 4));
      return ((256 * A) + B) / 4;
    } catch (e) {
      return 0.0; // or handle error appropriately
    }
  }

  int calculateSpeed(String hexValue) {
    return hexToInt(hexValue.substring(0, 2));
  }

  double calculateCoolantTemp(String hexValue) {
    return hexToInt(hexValue.substring(0, 2)) - 40;
  }

  double calculateThrottlePosition(String hexValue) {
    return hexToInt(hexValue.substring(0, 2)) * 100 / 255;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Data'),
        backgroundColor: Colors.blue.shade900,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _refreshTimer?.cancel();
            _connectionMonitor?.cancel();
            _timeoutTimer?.cancel();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade800,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (hasErrors)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unexpectedErrorMessages,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _buildDataCard(
                        'Engine RPM',
                        _commandResponsesMode1[MODE01_PIDS['Engine RPM']] ??
                            'N/A',
                        Icons.speed,
                      ),
                      _buildDataCard(
                        'Speed',
                        _commandResponsesMode1[MODE01_PIDS['Vehicle Speed']] ??
                            'N/A',
                        Icons.directions_car,
                      ),
                      _buildDataCard(
                        'Coolant Temp',
                        _commandResponsesMode1[
                                MODE01_PIDS['Engine Coolant Temperature']] ??
                            'N/A',
                        Icons.thermostat,
                      ),
                      _buildDataCard(
                        'Throttle',
                        _commandResponsesMode1[
                                MODE01_PIDS['Throttle Position']] ??
                            'N/A',
                        Icons.speed_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCard(String title, String value, IconData icon) {
    bool isValid = value != 'N/A' && !value.contains('Error');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 40,
            color: Colors.white,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          // Text(
          //   value,
          //   style: const TextStyle(
          //     color: Colors.white,
          //     fontSize: 24,
          //     fontWeight: FontWeight.bold,
          //   ),
          // ),
          Text(
            isValid ? value : 'Error',
            style: TextStyle(
              color: isValid ? Colors.white : Colors.red,
              // ... rest of style
            ),
          )
        ],
      ),
    );
  }
}
