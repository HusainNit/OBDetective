import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obdetective/pages/ECUconnection.dart';
import 'package:obdetective/pages/MainPage.dart';

// final bluetoothConnectionProvider = Provider<BluetoothConnection?>((ref) {
//   return BluetoothHandlerState().bluetoothConnection;
// });

final bluetoothConnectionProvider =
    StateProvider<BluetoothConnection?>((ref) => null);
final bluetoothStateProvider = StateProvider<bool>((ref) => false);

class BluetoothHandler extends ConsumerStatefulWidget {
  const BluetoothHandler({super.key});

  @override
  ConsumerState<BluetoothHandler> createState() => BluetoothHandlerState();
}

class BluetoothHandlerState extends ConsumerState<BluetoothHandler> {
  final _flutterBlueClassicPlugin = FlutterBlueClassic();

  void updatebluetoothState(bool connected) {
    ref.read(bluetoothStateProvider.notifier).state = connected;
  }

  List<BluetoothDevice> devices = [];
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  final Set<BluetoothDevice> _scanResults = {};
  bool _isScanning = false;
  int? _connectingToIndex;

  BluetoothConnection? _bluetoothConnection;

  // Subscriptions
  StreamSubscription? _adapterStateSubscription;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _scanningStateSubscription;

  BluetoothConnection? get bluetoothConnection => _bluetoothConnection;

  set bluetoothConnection(BluetoothConnection? connection) {
    _bluetoothConnection = connection;
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    try {
      final adapterState = await _flutterBlueClassicPlugin.adapterStateNow;

      _adapterStateSubscription = _flutterBlueClassicPlugin.adapterState.listen(
        (current) {
          if (mounted) setState(() => _adapterState = current);
        },
      );

      _scanSubscription = _flutterBlueClassicPlugin.scanResults.listen(
        (device) {
          if (mounted) setState(() => _scanResults.add(device));
        },
      );

      _scanningStateSubscription = _flutterBlueClassicPlugin.isScanning.listen(
        (isScanning) {
          if (mounted) setState(() => _isScanning = isScanning);
        },
      );

      if (mounted) setState(() => _adapterState = adapterState);
    } catch (e) {
      _showError('Failed to initialize Bluetooth: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device, int index) async {
    setState(() => _connectingToIndex = index);
    try {
      final connection =
          await _flutterBlueClassicPlugin.connect(device.address);

      if (!mounted) return;

      if (connection != null && connection.isConnected) {
        setState(() {
          _connectingToIndex = null;
          updatebluetoothState(true);
          _bluetoothConnection = connection;
          ref.read(bluetoothConnectionProvider.notifier).state = connection;
          ref.read(bluetoothStateProvider.notifier).state =
              connection?.isConnected ?? false;
        });

        _showECUDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connectingToIndex = null);
        _showError('Connection failed: ${e.toString()}');
      }
    }
  }

  void _showECUDialog() {
    final connection = ref.read(bluetoothConnectionProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('OBD-II ECU CONNECTION'),
        content: DatahandlerECU(),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    final scanResults = _scanResults.toList();

    if (scanResults.isEmpty) {
      return const Center(
        child: Text("No devices found yet", style: TextStyle(fontSize: 16)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: scanResults.length,
      itemBuilder: (context, index) {
        final device = scanResults[index];
        return ListTile(
          title: Text("${device.name ?? 'Unknown Device'} (${device.address})"),
          subtitle: Text(
            "Bond state: ${device.bondState.name}, Type: ${device.type.name}",
          ),
          trailing: index == _connectingToIndex
              ? const CircularProgressIndicator()
              : Text("${device.rssi} dBm"),
          onTap: () => _connectToDevice(device, index),
        );
      },
    );
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    // _scanSubscription?.cancel();
    _scanningStateSubscription?.cancel();
    //_bluetoothConnection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Device Scanner'),
        actions: [
          if (ref.read(bluetoothStateProvider))
            Icon(Icons.bluetooth_connected, color: Colors.green)
          else
            Icon(Icons.bluetooth_disabled, color: Colors.red),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            title: const Text("Bluetooth Adapter State"),
            subtitle: const Text("Tap to enable"),
            trailing: Text(_adapterState.name),
            leading: const Icon(Icons.settings_bluetooth),
            onTap: () => _flutterBlueClassicPlugin.turnOn(),
          ),
          const Divider(),
          Expanded(child: _buildDeviceList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            if (_isScanning) {
              _flutterBlueClassicPlugin.stopScan();
            } else {
              _scanResults.clear();
              _flutterBlueClassicPlugin.startScan();
            }
          });
        },
        label: Text(_isScanning ? "Scanning..." : "Start Scan"),
        icon: Icon(_isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
      ),
    );
  }
}
