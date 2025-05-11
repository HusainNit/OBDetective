import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/bluetooth.dart';
import 'package:flutter_application_1/pages/cars.dart';
import 'package:flutter_application_1/pages/demo.dart';
import 'package:flutter_application_1/pages/garage.dart';

import 'package:flutter_application_1/pages/signin.dart';
import 'package:flutter_application_1/pages/help.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF4993EE),
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(
          "Main Menu",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
           icon: Icon(
                  Icons.keyboard_backspace_rounded, color: Colors.white,
                  size: 30,
               ), 
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: GridView.count(
          crossAxisCount: 2,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ]),
              width: MediaQuery.of(context).size.width * 0.4,
              height: MediaQuery.of(context).size.height * 0.25,
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(10),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Help(),
                    ),
                  );
                },
                child: Column(
                  children: [
                    Icon(
                    Icons.fire_truck_sharp,
                      color: Color(0xFF4993EE),
                      size: 80,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: Text("Available Tow Trucks",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ]),
              width: MediaQuery.of(context).size.width * 0.4,
              height: MediaQuery.of(context).size.height * 0.25,
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(10),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Demo(),
                    ),
                  );
                },
                child: Column(
                  children: [
                    Icon(
                      Icons.science,
                      color: Color(0xFF4993EE),
                      size: 80,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: Text("Demo Mode",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ]),
              width: MediaQuery.of(context).size.width * 0.4,
              height: MediaQuery.of(context).size.height * 0.25,
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(10),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MechanicsListPage(),
                    ),
                  );
                },
                child: Column(
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      color: Color(0xFF4993EE),
                      size: 80,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: Text("Available Mechanics",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ]),
              width: MediaQuery.of(context).size.width * 0.4,
              height: MediaQuery.of(context).size.height * 0.25,
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(10),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Bluetoothhandler(),
                    ),
                  );
                },
                child: Column(
                  children: [
                    Icon(
                      Icons.sync,
                      color: Color(0xFF4993EE),
                      size: 80,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: Text("Live Data",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
