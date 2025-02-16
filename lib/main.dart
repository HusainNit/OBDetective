import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obdetective/pages/BluetoothHandler.dart';
import 'package:obdetective/pages/ECUconnection.dart';
import 'package:obdetective/pages/MainPage.dart';
import 'package:obdetective/routs.dart';
import 'package:obdetective/settings_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsManager.init();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OBD Detective',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color.fromARGB(255, 64, 199, 209),
      ),
      initialRoute: '/',
      routes: routes,
    );
  }
}
