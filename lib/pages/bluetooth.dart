import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/livedata.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

class Bluetoothhandler extends StatefulWidget {
  const Bluetoothhandler({super.key});

  @override
  State<Bluetoothhandler> createState() => BluetoothhandlerState();
}

class BluetoothhandlerState extends State<Bluetoothhandler> {
  static final _flutterBlueClassicPlugin = FlutterBlueClassic();

  static bool isConnected = false;

  static List<BluetoothDevice> devices = [];

  static Future<void> loadDevices() async {
    final result = await _flutterBlueClassicPlugin.bondedDevices;
    devices = result!;
  }

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription? _adapterStateSubscription;

  final Set<BluetoothDevice> _scanResults = {};
  StreamSubscription? _scanSubscription;

  bool _isScanning = false;
  int? _connectingToIndex;
  StreamSubscription? _scanningStateSubscription;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    BluetoothAdapterState adapterState = _adapterState;

    try {
      adapterState = await _flutterBlueClassicPlugin.adapterStateNow;
      _adapterStateSubscription =
          _flutterBlueClassicPlugin.adapterState.listen((current) {
        if (mounted) setState(() => _adapterState = current);
      });
      _scanSubscription =
          _flutterBlueClassicPlugin.scanResults.listen((device) {
        if (mounted) setState(() => _scanResults.add(device));
      });
      _scanningStateSubscription =
          _flutterBlueClassicPlugin.isScanning.listen((isScanning) {
        if (mounted) setState(() => _isScanning = isScanning);
      });
    } catch (e) {
      if (kDebugMode) print(e);
    }

    if (!mounted) return;

    setState(() {
      _adapterState = adapterState;
    });
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _scanningStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<BluetoothDevice> scanResults = _scanResults.toList();

    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          // TRY THIS: Try changing the color here to a specific color (to
          // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
          // change color while the other colors stay the same.

          backgroundColor: Color(0xFF4993EE),
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text("Bluetooth", style: TextStyle(color: Colors.white)),

          actions: [
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.bluetooth,
                color: Colors.blueAccent,
                size: 30,
              ),
            ),
          ],

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
        ),
        body: ListView(
          children: [
            if (scanResults.isEmpty)
              const Center(child: Text(""))
            else
              for (var (index, result) in scanResults.indexed)
                ListTile(
                  title: Text("${result.name ?? "???"} (${result.address})"),
                  subtitle: Text(
                      "Bondstate: ${result.bondState.name}, Device type: ${result.type.name}"),
                  trailing: index == _connectingToIndex
                      ? const CircularProgressIndicator()
                      : Text("${result.rssi} dBm"),
                  onTap: () async {
                    BluetoothConnection? connection;
                    setState(() => _connectingToIndex = index);
                    try {
                      connection = await _flutterBlueClassicPlugin
                          .connect(result.address);
                      if (!this.context.mounted) return;
                      if (connection != null && connection.isConnected) {
                        if (mounted) setState(() => _connectingToIndex = null);
                        isConnected = true;
                        //Navigator.pop(context);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DatahandlerECU(connection: connection!),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) setState(() => _connectingToIndex = null);
                      if (kDebugMode) print(e);
                      connection?.dispose();
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          const SnackBar(
                              content: Text("Error connecting to device")));
                    }
                  },
                )
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Color(0xFF4993EE),
          onPressed: () {
            if (_isScanning) {
              _flutterBlueClassicPlugin.stopScan();
            } else {
              _scanResults.clear();
              _flutterBlueClassicPlugin.startScan();
            }
          },
          label: Text(
            _isScanning ? "Scanning..." : "Start device scan",
            style: TextStyle(color: Colors.white),
          ),
          icon: Icon(
            _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
            color: Colors.white,
          ),
        ));
  }
}
