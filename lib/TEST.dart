import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers
final bluetoothProvider =
    StateNotifierProvider<BluetoothNotifier, BluetoothState>(
  (ref) => BluetoothNotifier(),
);

final liveDataProvider = StateProvider<String>((ref) => '');
final dtcCodesProvider = StateProvider<List<String>>((ref) => []);

class BluetoothState {
  final BluetoothAdapterState adapterState;
  final bool isScanning;
  final Set<BluetoothDevice> scanResults;
  final BluetoothConnection? connection;
  final bool isConnected;
  final int? connectingIndex;
  final List<String> receivedData;
  final Map<String, String> commandResponses;
  final String? errorMessage;

  BluetoothState({
    this.adapterState = BluetoothAdapterState.unknown,
    this.isScanning = false,
    this.scanResults = const {},
    this.connection,
    this.isConnected = false,
    this.connectingIndex,
    this.receivedData = const [],
    this.commandResponses = const {},
    this.errorMessage,
  });

  BluetoothState copyWith({
    BluetoothAdapterState? adapterState,
    bool? isScanning,
    Set<BluetoothDevice>? scanResults,
    BluetoothConnection? connection,
    bool? isConnected,
    int? connectingIndex,
    List<String>? receivedData,
    Map<String, String>? commandResponses,
    String? errorMessage,
  }) {
    return BluetoothState(
      adapterState: adapterState ?? this.adapterState,
      isScanning: isScanning ?? this.isScanning,
      scanResults: scanResults ?? this.scanResults,
      connection: connection ?? this.connection,
      isConnected: isConnected ?? this.isConnected,
      connectingIndex: connectingIndex ?? this.connectingIndex,
      receivedData: receivedData ?? this.receivedData,
      commandResponses: commandResponses ?? this.commandResponses,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class BluetoothNotifier extends StateNotifier<BluetoothState> {
  final FlutterBlueClassic _flutterBlue = FlutterBlueClassic();
  StreamSubscription? _adapterSub;
  StreamSubscription? _scanSub;
  StreamSubscription? _scanningSub;
  StreamSubscription? _connectionSub;
  final _commandCompleters = <String, Completer<String>>{};
  StreamSubscription<List<int>>? _dataSubscription;
  Timer? _timeoutTimer;
  String? _currentCommand;

  BluetoothNotifier() : super(BluetoothState()) {
    init();
  }

  Future<void> init() async {
    try {
      final adapterState = await _flutterBlue.adapterStateNow;
      _adapterSub = _flutterBlue.adapterState.listen(_updateAdapterState);
      _scanSub = _flutterBlue.scanResults.listen(_updateScanResults);
      _scanningSub = _flutterBlue.isScanning.listen(_updateScanningState);
      state = state.copyWith(adapterState: adapterState);
    } catch (e) {
      _handleError('Bluetooth initialization failed: $e');
    }
  }

  Future<void> _setupDataHandler(BluetoothConnection connection) async {
    _dataSubscription?.cancel();
    _dataSubscription = connection.input?.listen(
      _handleIncomingData,
      onError: _handleDataError,
      onDone: _handleDisconnection,
    );
  }

  void _handleIncomingData(List<int> data) {
    try {
      final response = ascii.decode(data).trim();
      final responses =
          response.split(RegExp(r'\r?\n>')); // Handle multi-line responses

      state = state.copyWith(
        receivedData: [...state.receivedData, ...responses],
      );

      for (final res in responses) {
        if (_currentCommand != null && res.isNotEmpty) {
          _completeCommand(res);
        }
      }
    } catch (e) {
      _handleError('Data decoding error: $e');
    }
  }

  void _completeCommand(String response) {
    final completer = _commandCompleters.remove(_currentCommand);
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
      state = state.copyWith(
        commandResponses: {
          ...state.commandResponses,
          _currentCommand!: response
        },
      );
    }
    _currentCommand = null;
    _timeoutTimer?.cancel();
  }

  void _handleDataError(Object error) {
    state = state.copyWith(errorMessage: 'Data stream error: $error');
    _cleanupConnection();
  }

  void _handleDisconnection() {
    state = state.copyWith(
      errorMessage: 'Device disconnected',
      isConnected: false,
      connection: null,
    );
    _cleanupConnection();
  }

  void _updateAdapterState(BluetoothAdapterState newState) {
    state = state.copyWith(adapterState: newState);
  }

  void _updateScanResults(BluetoothDevice device) {
    state = state.copyWith(scanResults: {...state.scanResults, device});
  }

  void _updateScanningState(bool isScanning) {
    state = state.copyWith(isScanning: isScanning);
  }

  Future<void> toggleScan() async {
    if (state.isScanning) {
      _flutterBlue.stopScan();
      state = state.copyWith(scanResults: {});
    } else {
      _flutterBlue.startScan();
    }
  }

  Future<void> connectToDevice(BluetoothDevice device, int index) async {
    state = state.copyWith(connectingIndex: index);
    try {
      final connection = await _flutterBlue.connect(device.address);
      if (connection == null) throw Exception('Connection failed');

      _connectionSub = connection.input?.listen((_) {
        state = BluetoothState(adapterState: state.adapterState);
      });

      state = state.copyWith(
        connection: connection,
        isConnected: true,
        connectingIndex: null,
      );
    } catch (e) {
      state = state.copyWith(connectingIndex: null);
      _handleError('Connection failed: $e');
    }
  }

  Future<void> disconnect() async {
    await state.connection?.close();
    state = state.copyWith(
      connection: null,
      isConnected: false,
    );
  }

  Future<String> sendObdCommand(String cmd) async {
    if (state.connection == null || !state.isConnected) {
      throw Exception('Not connected to any device');
    }

    _currentCommand = cmd;
    final completer = Completer<String>();
    _commandCompleters[cmd] = completer;

    try {
      state.connection!.output.add(ascii.encode('$cmd\r'));
    } catch (e) {
      _handleError('Error sending command: $e');
      _commandCompleters.remove(cmd);
      throw Exception('Failed to send command');
    }

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _commandCompleters.remove(cmd);
        throw TimeoutException('No response for command $cmd');
      },
    );
  }

  void _handleError(String message) {
    // Add error handling logic (e.g., show snackbar)
    debugPrint(message);
  }

  void _cleanupConnection() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _timeoutTimer?.cancel();
    _commandCompleters.clear();
    _currentCommand = null;
  }

  @override
  void dispose() {
    _cleanupConnection();
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _scanningSub?.cancel();
    _connectionSub?.cancel();
    state.connection?.close();
    super.dispose();
  }
}

class BluetoothHandlers extends ConsumerWidget {
  const BluetoothHandlers({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bluetoothProvider);
    final notifier = ref.read(bluetoothProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OBD-II Scanner'),
        actions: [
          IconButton(
            icon: state.isConnected
                ? const Icon(Icons.bluetooth_connected, color: Colors.green)
                : const Icon(Icons.bluetooth_disabled, color: Colors.red),
            onPressed: () {
              if (state.isConnected) notifier.disconnect();
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildAdapterStateTile(state, notifier),
          const Divider(),
          Expanded(child: _buildDeviceList(state, notifier)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(state.isScanning ? Icons.stop : Icons.search),
        label: Text(state.isScanning ? 'Stop Scan' : 'Start Scan'),
        onPressed: () => notifier.toggleScan(),
      ),
    );
  }

  Widget _buildAdapterStateTile(
      BluetoothState state, BluetoothNotifier notifier) {
    return ListTile(
      leading: const Icon(Icons.bluetooth),
      title: const Text('Bluetooth Adapter'),
      subtitle: Text(state.adapterState.name),
      trailing: state.adapterState == BluetoothAdapterState.off
          ? IconButton(
              icon: const Icon(Icons.power_settings_new),
              onPressed: () => notifier._flutterBlue.turnOn(),
            )
          : null,
    );
  }

  Widget _buildDeviceList(BluetoothState state, BluetoothNotifier notifier) {
    if (state.scanResults.isEmpty) {
      return const Center(child: Text('No devices found'));
    }

    return ListView.builder(
      itemCount: state.scanResults.length,
      itemBuilder: (context, index) {
        final device = state.scanResults.elementAt(index);
        return ListTile(
          title: Text(device.name ?? 'Unknown Device'),
          subtitle: Text(device.address),
          trailing: _buildConnectionState(device, state, index),
          onTap: () => notifier.connectToDevice(device, index),
        );
      },
    );
  }

  Widget _buildConnectionState(
      BluetoothDevice device, BluetoothState state, int index) {
    if (state.connectingIndex == index) {
      return const CircularProgressIndicator();
    }
    if (state.connection?.address == device.address) {
      return const Icon(Icons.bluetooth_connected, color: Colors.green);
    }
    return const Icon(Icons.bluetooth, color: Colors.grey);
  }
}

class ObdDataHandler extends ConsumerWidget {
  const ObdDataHandler({super.key});

  ProviderListenable? get navigatorKeyProvider => null;

  _hexToBytes(String hex) {
    hex = hex.replaceAll(' ', '');
    return List.generate(hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
  }

  _parseDtcPair(int firstByte, int secondByte) {
    final char = ['P', 'C', 'B', 'U'][(firstByte >> 6) & 0x03];
    final first = (firstByte >> 4) & 0x03;
    final second = firstByte & 0x0F;
    final third = (secondByte >> 4) & 0x0F;
    final fourth = secondByte & 0x0F;
    return '$char$first$second$third$fourth';
  }

  _parseCoolantTemp(String response) {
    final bytes = _hexToBytes(response);
    return bytes.isNotEmpty ? bytes[0].toString() : 'N/A';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bluetooth = ref.watch(bluetoothProvider);
    final liveData = ref.watch(liveDataProvider);
    final dtcCodes = ref.watch(dtcCodesProvider);

    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _fetchLiveData(ref),
          child: const Text('Refresh Live Data'),
        ),
        ElevatedButton(
          onPressed: () => _fetchDtcCodes(ref),
          child: const Text('Refresh DTC Codes'),
        ),
        const SizedBox(height: 20),
        Text('Live Data:\n$liveData'),
        const SizedBox(height: 20),
        Text('DTC Codes: ${dtcCodes.join(', ')}'),
      ],
    );
  }

  Future<void> _fetchLiveData(WidgetRef ref) async {
    final notifier = ref.read(bluetoothProvider.notifier);
    try {
      final rpm = await notifier.sendObdCommand('010C');
      final speed = await notifier.sendObdCommand('010D');
      final temp = await notifier.sendObdCommand('0105');

      ref.read(liveDataProvider.notifier).state = '''
        RPM: ${_parseRpm(rpm)}
        Speed: ${_parseSpeed(speed)} km/h
        Temp: ${_parseCoolantTemp(temp)} °C
      ''';
    } catch (e) {
      _showError(ref, 'Failed to get live data: $e');
    }
  }

  Future<void> _fetchDtcCodes(WidgetRef ref) async {
    final notifier = ref.read(bluetoothProvider.notifier);
    try {
      final response = await notifier.sendObdCommand('03');
      ref.read(dtcCodesProvider.notifier).state = _parseDtcResponse(response);
    } catch (e) {
      _showError(ref, 'Failed to get DTCs: $e');
    }
  }

  String _parseRpm(String response) {
    final bytes = _hexToBytes(response);
    return bytes.length >= 2
        ? ((bytes[0] * 256 + bytes[1]) ~/ 4).toString()
        : 'N/A';
  }

  String _parseSpeed(String response) {
    final bytes = _hexToBytes(response);
    return bytes.isNotEmpty ? bytes[0].toString() : 'N/A';
  }

  List<String> _parseDtcResponse(String response) {
    final bytes = _hexToBytes(response);
    return List.generate(bytes.length ~/ 2,
        (i) => _parseDtcPair(bytes[i * 2], bytes[i * 2 + 1]));
  }

  // Add remaining parsing functions from previous implementation
  // ...

  void _showError(WidgetRef ref, String message) {
    final context = ref.read(navigatorKeyProvider!).currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}
