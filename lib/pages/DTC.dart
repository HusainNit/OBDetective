import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obdetective/pages/BluetoothHandler.dart';

class OBD2DTCReader extends ConsumerStatefulWidget {
  const OBD2DTCReader({super.key});

  @override
  ConsumerState<OBD2DTCReader> createState() => _OBD2DTCReaderState();
}

class _OBD2DTCReaderState extends ConsumerState<OBD2DTCReader> {
  BluetoothConnection get connection => ref.watch(bluetoothConnectionProvider)!;
  StreamSubscription? subscription;

  // Future<void> connectToDevice(BluetoothDevice device) async {
  //   try {
  //     connection = ref.read(bluetoothConnectionProvider);
  //     print('Connected to OBD2 device');
  //     _startListening();
  //   } catch (e) {
  //     onError('Failed to connect: $e');
  //   }
  // }

  void _startListening() {
    subscription = connection?.input?.listen(
      (data) {
        _processResponse(data);
      },
      onError: (error) {
        print('Error receiving data: $error');
      },
      onDone: () {
        print('Disconnected');
      },
    );
  }

  Future<void> requestDTCs() async {
    if (connection?.isConnected ?? false) {
      try {
        // Mode 03 command for requesting DTCs
        connection?.output.add(ascii.encode('03\r'));
        await connection?.output.allSent;
      } catch (e) {
        print('Failed to send command: $e');
      }
    } else {
      print('Not connected to device');
    }
  }

  void _processResponse(List<int> data) {
    if (data.isEmpty) return;

    String response = ascii.decode(data).trim();

    // Check if response is valid (starts with 43 which is response to mode 03)
    if (response.startsWith('43')) {
      // Process DTCs (each DTC is 2 bytes)
      for (int i = 2; i < response.length; i += 4) {
        if (i + 4 <= response.length) {
          String dtcHex = response.substring(i, i + 4);
          String dtc = _convertHexToDTC(dtcHex);
          //onDtcReceived(dtc);
        }
      }
    }
  }

  String _convertHexToDTC(String hex) {
    final Map<String, String> dtcFirstChar = {
      '0': 'P0',
      '1': 'P1',
      '2': 'P2',
      '3': 'P3',
      '4': 'C0',
      '5': 'C1',
      '6': 'C2',
      '7': 'C3',
      '8': 'B0',
      '9': 'B1',
      'A': 'B2',
      'B': 'B3',
      'C': 'U0',
      'D': 'U1',
      'E': 'U2',
      'F': 'U3'
    };

    String firstDigit = hex[0];
    String prefix = dtcFirstChar[firstDigit] ?? 'P0';
    String dtcNumber = hex.substring(1);

    return '$prefix$dtcNumber';
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
// }

// class OBD2DTCReader {
//   BluetoothConnection? connection;
//   StreamSubscription? subscription;
//   final void Function(String) onDtcReceived;
//   final void Function(String) onError;

//   OBD2DTCReader({required this.onDtcReceived, required this.onError});

//   Future<void> connectToDevice(BluetoothDevice device) async {
//     try {
//       connection = ref.read(bluetoothConnectionProvider);
//       print('Connected to OBD2 device');
//       _startListening();
//     } catch (e) {
//       onError('Failed to connect: $e');
//     }
//   }

//   void _startListening() {
//     subscription = connection?.input?.listen(
//       (data) {
//         _processResponse(data);
//       },
//       onError: (error) {
//         onError('Error receiving data: $error');
//       },
//       onDone: () {
//         print('Disconnected');
//       },
//     );
//   }

//   Future<void> requestDTCs() async {
//     if (connection?.isConnected ?? false) {
//       try {
//         // Mode 03 command for requesting DTCs
//         connection?.output.add(ascii.encode('03\r'));
//         await connection?.output.allSent;
//       } catch (e) {
//         onError('Failed to send command: $e');
//       }
//     } else {
//       onError('Not connected to device');
//     }
//   }

//   void _processResponse(List<int> data) {
//     if (data.isEmpty) return;

//     String response = ascii.decode(data).trim();

//     // Check if response is valid (starts with 43 which is response to mode 03)
//     if (response.startsWith('43')) {
//       // Process DTCs (each DTC is 2 bytes)
//       for (int i = 2; i < response.length; i += 4) {
//         if (i + 4 <= response.length) {
//           String dtcHex = response.substring(i, i + 4);
//           String dtc = _convertHexToDTC(dtcHex);
//           onDtcReceived(dtc);
//         }
//       }
//     }
//   }

//   String _convertHexToDTC(String hex) {
//     final Map<String, String> dtcFirstChar = {
//       '0': 'P0',
//       '1': 'P1',
//       '2': 'P2',
//       '3': 'P3',
//       '4': 'C0',
//       '5': 'C1',
//       '6': 'C2',
//       '7': 'C3',
//       '8': 'B0',
//       '9': 'B1',
//       'A': 'B2',
//       'B': 'B3',
//       'C': 'U0',
//       'D': 'U1',
//       'E': 'U2',
//       'F': 'U3'
//     };

//     String firstDigit = hex[0];
//     String prefix = dtcFirstChar[firstDigit] ?? 'P0';
//     String dtcNumber = hex.substring(1);

//     return '$prefix$dtcNumber';
//   }

//   // void dispose() {
//   //   subscription?.cancel();
//   //   connection?.dispose();
//   // }
}
