import 'package:flutter/material.dart';
import 'package:obdetective/TEST.dart';
import 'package:obdetective/pages/DTC.dart';
import 'package:obdetective/pages/MainPage.dart';
import 'package:obdetective/pages/BluetoothHandler.dart';
import 'package:obdetective/pages/ECUconnection.dart';
import 'package:obdetective/pages/MapHelp.dart';
import 'package:obdetective/pages/liveData.dart';

final Map<String, WidgetBuilder> routes = {
  '/': (context) => const MainPage(),
  '/bluetooth': (context) => const BluetoothHandler(),
  '/ecu': (context) => DatahandlerECU(),
  '/livedata': (context) => const Livedata(),
  '/test': (context) => const BluetoothHandlers(),
  '/map': (context) => MapScreen(),
  //'/dtc': (context) =>  OBD2DTCReader(),
};
