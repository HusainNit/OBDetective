import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:obdetective/pages/BluetoothHandler.dart';
import 'package:obdetective/settings_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ecuStateProvider = StateProvider<bool>((ref) => false);

class DatahandlerECU extends ConsumerStatefulWidget {
  DatahandlerECU({super.key});

  @override
  ConsumerState<DatahandlerECU> createState() => DatahandlerECUState();
}

class DatahandlerECUState extends ConsumerState<DatahandlerECU> {
  BluetoothConnection get connection => ref.watch(bluetoothConnectionProvider)!;
  BluetoothStreamSink get output => connection.output;
  void updateECUState(bool connected) {
    ref.read(ecuStateProvider.notifier).state = connected;
  }

  //Stream<Uint8List>? get input => widget.classicConnection.input;
  StreamSubscription? _readSubscription;
  final List<String> _receivedInput = [];
  Map<String, String> _commandResponses = {};
  String unexpectedErrorMessage = '';
  String selectedProtocol = SettingsManager.protocol;
  bool hasError = false;
  bool _waitForResponse = false;
  Completer _receivedSignal = Completer();
  String _currentCommand = '';
  String _errorECU = '';
  List<String> ECUcommands = [
    "ATZ", // Reset all
    "ATE0", // Echo off
    "ATH1", // Headers on
    "ATSP0", // Auto protocol (will be replaced with user selection)
    "ATAT1", // Adaptive timing on
  ];
  static const int COMMAND_TIMEOUT = 5000; // 5 seconds timeout
  Timer? _timeoutTimer;
  Timer? _connectionMonitor;

  @override
  void initState() {
    super.initState();
    ECUcommands[3] =
        "ATSP${SettingsManager.protocol}"; // Ensure protocol is correct too

    startConnectionMonitoring();
    if (connection != null) {
      receiveData();
      connectToECU();
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _commandResponses.clear();
    _receivedInput.clear();
    // _connectionMonitor?.cancel();
    _readSubscription?.cancel();
    _receivedSignal.complete();
    unexpectedErrorMessage = '';
    hasError = false;
    _waitForResponse = false;
    _currentCommand = '';
    super.dispose();
  }

  Future<void> receiveData() async {
    _readSubscription = connection.input?.listen(
      (event) {
        if (!mounted) return;

        try {
          final response = ascii.decode(event).trim();
          setState(() => _receivedInput.add(response));

          if (_waitForResponse) {
            _commandResponses[_currentCommand] = response;
            _waitForResponse = false;
            _timeoutTimer?.cancel();
            if (!_receivedSignal.isCompleted) {
              _receivedSignal.complete();
            }
          }
        } catch (e) {
          setState(() {
            unexpectedErrorMessage = 'Decoding error: $e';
            hasError = true;
          });
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          unexpectedErrorMessage = 'Data stream error: $error';
          hasError = true;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          unexpectedErrorMessage = 'Data stream closed';
          hasError = true;
        });
      },
    );
  }

  Future<void> sendData(String text) async {
    try {
      if (connection.output == null) {
        throw Exception('Output stream not available');
      }
      connection.output.add(ascii.encode(text));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        unexpectedErrorMessage = 'Error sending data: $e';
        hasError = true;
      });
    }
  }

  Future<void> connectToECU() async {
    bool allSuccess = true;
    if (!connection.isConnected) {
      ref.read(ecuStateProvider.notifier).state = false;
      return;
    }
    _waitForResponse = false;

    for (String command in ECUcommands) {
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

        sendData("$command\r");
        await _receivedSignal.future;
      } catch (e) {
        setState(() {
          unexpectedErrorMessage = 'Timeout or error on command: $command';
          hasError = true;
        });
        print('Command failed: $command - Error: $e');
      } finally {
        _timeoutTimer?.cancel();
        _waitForResponse = false;
      }

      await Future.delayed(Duration(seconds: 1));

      if (_commandResponses[command]?.toLowerCase().trim() == "timeout" ||
              _commandResponses[command] == null ||
              _commandResponses[command] == "" ||
              _commandResponses[command]?.toLowerCase().trim() ==
                  "error" /*||
          _commandResponses[command]?.trim() == "?" ||
          _commandResponses[command]?.trim() == ">"*/
          ) {
        _errorECU = _commandResponses[command]!;
        allSuccess = false;
      }
    }

    ref.read(ecuStateProvider.notifier).state = allSuccess;
  }

  Future<void> ECuconnectionstatus() async {
    if (connection.isConnected) {
      setState(() {
        updateECUState(true);
      });
    } else {
      setState(() {
        updateECUState(true);
      });
    }
  }

  void startConnectionMonitoring() {
    _connectionMonitor = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!connection.isConnected) {
        setState(() {
          updateECUState(false);
          unexpectedErrorMessage = 'Connection lost';
          hasError = true;
        });
        _connectionMonitor?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (connection == null || !connection.isConnected) {
      return const SizedBox.shrink(); // Or connection error message
    }
    return AlertDialog(
      title: const Text('Connection Status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bluetooth Status
          ListTile(
            leading: Icon(
              connection.isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: connection.isConnected ? Colors.green : Colors.red,
            ),
            title: Text(
              connection.isConnected
                  ? 'Bluetooth Connected'
                  : 'Bluetooth Disconnected',
            ),
          ),
          // ECU Status with Loading
          ListTile(
            leading: _waitForResponse
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    ref.watch(ecuStateProvider)
                        ? Icons.check_circle
                        : Icons.error,
                    color:
                        ref.watch(ecuStateProvider) ? Colors.green : Colors.red,
                  ),
            title: Text(
              _waitForResponse
                  ? 'Connecting to ECU... ${_currentCommand}'
                  : (ref.watch(ecuStateProvider)
                      ? 'ECU Connected ${_errorECU}'
                      : 'ECU Connection Failed ${_errorECU}'),
            ),
          ),
          if (hasError)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              child: Text(unexpectedErrorMessage),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
