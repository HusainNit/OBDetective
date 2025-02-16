import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obdetective/pages/BluetoothHandler.dart';
import 'package:obdetective/pages/ECUconnection.dart';
import 'package:obdetective/settings_manager.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  // bool get isConnected => BluetoothHandlerState().isConnected;
  // bool get isECUConnected => DatahandlerECUState.isECUConnected;
  Timer? _refreshTimer;

  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _showConnectionSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Connection Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Protocol'),
                value: '0',
                items: const [
                  DropdownMenuItem(value: '0', child: Text('Auto')),
                  DropdownMenuItem(value: '1', child: Text('SAE J1850 PWM')),
                  DropdownMenuItem(value: '2', child: Text('SAE J1850 VPW')),
                  DropdownMenuItem(value: '3', child: Text('ISO 9141-2')),
                  DropdownMenuItem(value: '4', child: Text('ISO 14230-4 KWP')),
                  DropdownMenuItem(
                      value: '5', child: Text('ISO 14230-4 KWP Fast')),
                  DropdownMenuItem(value: '6', child: Text('ISO 15765-4 CAN')),
                  DropdownMenuItem(
                      value: '7', child: Text('ISO 15765-4 CAN 29/500')),
                  DropdownMenuItem(
                      value: '8', child: Text('ISO 15765-4 CAN 11/250')),
                  DropdownMenuItem(
                      value: '9', child: Text('ISO 15765-4 CAN 29/250')),
                  DropdownMenuItem(value: '10', child: Text('SAE J1939 CAN')),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    SettingsManager.protocol = value;
                    setState(() {});
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget build(BuildContext context) {
    final isConnected = ref.watch(bluetoothStateProvider);
    final isECUConnected = ref.watch(ecuStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'OBDetective',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(179, 148, 26, 219),
      ),
      body: Column(
        children: [
          // Top Connection Button and settings
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isECUConnected && isConnected
                          ? const Color.fromARGB(200, 76, 175, 79)
                          : const Color.fromARGB(181, 238, 0, 0),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/bluetooth');
                    },
                    child: Text(
                      isECUConnected && isConnected
                          ? 'Connected'
                          : 'Connect to OBD',
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: _showConnectionSettings,
                    tooltip: 'Connection Settings',
                  ),
                ),
              ],
            ),
          ),

          // Grid of Task Boxes
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildTaskBox(
                  title: 'Read DTCs',
                  icon: Icons.error_outline,
                  onTap: () => {/* Navigate to DTC Reader */},
                  isEnabled: isECUConnected && isConnected,
                ),
                _buildTaskBox(
                  title: 'Live Data',
                  icon: Icons.show_chart,
                  onTap: () => {Navigator.pushNamed(context, '/livedata')},
                  isEnabled: isECUConnected && isConnected,
                ),
                _buildTaskBox(
                  title: 'Sensors',
                  icon: Icons.sensors,
                  onTap: () => {/* Navigate to Sensors */},
                  isEnabled: isECUConnected && isConnected,
                ),
                _buildTaskBox(
                  title: 'Terminal',
                  icon: Icons.terminal,
                  onTap: () => {/* Navigate to Terminal */},
                  isEnabled: isECUConnected && isConnected,
                ),
                _buildTaskBox(
                  title: 'extra Details',
                  icon: Icons.auto_stories,
                  onTap: () => {/* Navigate to Settings */},
                  isEnabled: isECUConnected && isConnected,
                ),
                _buildTaskBox(
                  title: 'All cars',
                  icon: Icons.car_rental,
                  onTap: () => {/* Navigate to Settings */},
                  isEnabled: true,
                ),
                _buildTaskBox(
                  title: 'Car Help',
                  icon: Icons.help_center,
                  onTap: () => {Navigator.pushNamed(context, '/map')},
                  isEnabled: true,
                ),
                _buildTaskBox(
                  title: 'Database',
                  icon: Icons.save,
                  onTap: () => {/* Navigate to Settings */},
                  isEnabled: true,
                ),
                _buildTaskBox(
                  title: 'Settings',
                  icon: Icons.settings,
                  onTap: () => {/* Navigate to Settings */},
                  isEnabled: true,
                ),
                _buildTaskBox(
                  title: 'test',
                  icon: Icons.text_snippet,
                  onTap: () => {Navigator.pushNamed(context, '/test')},
                  isEnabled: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskBox({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool isEnabled,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey[300],
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: isEnabled
                  ? const Color.fromARGB(179, 148, 26, 219)
                  : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isEnabled ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
