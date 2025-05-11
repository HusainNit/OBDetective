import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/firestore.dart';
import 'package:flutter_application_1/pages/home.dart';

import 'package:flutter_application_1/pages/signin.dart';

import 'dart:async';

String make1 = '';
String model1 = '';
String year1 = '';

final FirestoreServices firestoreServices = FirestoreServices();

final Map<String, List<String>> carMakesWithModels = {
  'Toyota': [
    'Camry',
    'Corolla',
    'RAV4',
    'Highlander',
    'Tacoma',
    'Tundra',
    'Prius',
    'Sienna',
    '4Runner',
    'Land Cruiser'
  ],
  'Honda': [
    'Civic',
    'Accord',
    'CR-V',
    'Pilot',
    'Odyssey',
    'HR-V',
    'Ridgeline',
    'Fit',
    'Insight',
    'Passport'
  ],
  'Ford': [
    'F-150',
    'Mustang',
    'Explorer',
    'Escape',
    'Edge',
    'Bronco',
    'Ranger',
    'Expedition',
    'Maverick',
    'Mach-E'
  ],
  'Chevrolet': [
    'Silverado',
    'Equinox',
    'Tahoe',
    'Suburban',
    'Traverse',
    'Malibu',
    'Camaro',
    'Corvette',
    'Blazer',
    'Colorado'
  ],
  'BMW': [
    '3 Series',
    '5 Series',
    '7 Series',
    'X1',
    'X3',
    'X5',
    'X7',
    'i4',
    'iX',
    'M3'
  ],
  'Mercedes-Benz': [
    'C-Class',
    'E-Class',
    'S-Class',
    'GLA',
    'GLC',
    'GLE',
    'GLS',
    'A-Class',
    'CLA',
    'EQS'
  ],
  'Audi': ['A4', 'A6', 'A8', 'Q3', 'Q5', 'Q7', 'e-tron', 'TT', 'R8', 'S4'],
  'Volkswagen': [
    'Golf',
    'Jetta',
    'Passat',
    'Tiguan',
    'Atlas',
    'ID.4',
    'Taos',
    'Arteon',
    'GTI',
    'Atlas Cross Sport'
  ],
  'Hyundai': [
    'Elantra',
    'Sonata',
    'Tucson',
    'Santa Fe',
    'Palisade',
    'Kona',
    'Ioniq',
    'Venue',
    'Accent',
    'Nexo'
  ],
  'Kia': [
    'Sorento',
    'Sportage',
    'Telluride',
    'Forte',
    'Soul',
    'K5',
    'Carnival',
    'Niro',
    'Seltos',
    'EV6'
  ],
  'Mazda': [
    'CX-5',
    'CX-9',
    'CX-30',
    'Mazda3',
    'Mazda6',
    'MX-5 Miata',
    'CX-50',
    'CX-90',
    'MX-30',
    'CX-3'
  ],
  'Subaru': [
    'Outback',
    'Forester',
    'Crosstrek',
    'Impreza',
    'Legacy',
    'Ascent',
    'WRX',
    'BRZ',
    'Solterra',
    'Baja'
  ],
  'Nissan': [
    'Altima',
    'Rogue',
    'Sentra',
    'Pathfinder',
    'Murano',
    'Frontier',
    'Titan',
    'Armada',
    'Kicks',
    'Ariya'
  ],
  'Tesla': [
    'Model 3',
    'Model Y',
    'Model S',
    'Model X',
    'Cybertruck',
    'Roadster',
    'Semi',
    'Model 2',
    'Optimus',
    'Powerwall'
  ],
  'Volvo': [
    'XC90',
    'XC60',
    'XC40',
    'S60',
    'S90',
    'V60',
    'V90',
    'C40 Recharge',
    'EX30',
    'EX90'
  ]
};

final List<String> carYears = [
  '2025',
  '2024',
  '2023',
  '2022',
  '2021',
  '2020',
  '2019',
  '2018',
  '2017',
  '2016',
  '2015',
  '2014',
  '2013',
  '2012',
  '2010',
  '2009',
  '2008',
  '2007',
  '2006',
  '2005',
];

void main() {
  runApp(const Car(
    userId: '',
  ));
}

class Car extends StatelessWidget {
  final String userId;

  const Car({super.key, required this.userId});

  // This widget is the root of the application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OBDetective Cars',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Color(0xFF4993EE),
          title: Text("My Cars",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold)),
          actions: <Widget>[
            IconButton(
              icon: Icon(
                Icons.logout,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Signin(),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                  stream: firestoreServices.getUserCarsStream(userId),
                  builder: (context, snapshot) {
                    //if we have data, get all the docs
                    if (snapshot.hasData) {
                      List carList = snapshot.data!.docs;

                      // display as a list
                      return ListView.builder(
                          itemCount: carList.length,
                          itemBuilder: (context, index) {
                            // get each individual doc
                            DocumentSnapshot document = carList[index];

                            //get email of each doc
                            Map<String, dynamic> data =
                                document.data() as Map<String, dynamic>;
                            String make = data['make'];
                            String model = data['model'];
                            String year = data['year'];

                            // display as a list tile
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: EdgeInsets.all(8),
                              color: Colors.grey[200],
                              shadowColor: Colors.black,
                              child: ListTile(
                                title: Text("$make $model",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    )),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "$year",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline,
                                            color: Colors.grey, size: 15),
                                        SizedBox(width: 4),
                                        Text(
                                          "hold to delete",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.black,
                                  size: 30,
                                  semanticLabel: 'Next',
                                ),
                                leading: Icon(
                                  Icons.directions_car_outlined,
                                  color: Colors.black,
                                  size: 30,
                                ),
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => Home()));
                                },
                                onLongPress: () {
                                  showDialog<String>(
                                    barrierColor: Colors.black54,
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        backgroundColor: Colors.white,
                                        title: Text('Delete Car'),
                                        content: Text(
                                            'Are you sure you want to delete this car?'),
                                        actions: <Widget>[
                                          TextButton(
                                            child: Text('Cancel',
                                                style: TextStyle(
                                                    color: Colors.black)),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          TextButton(
                                            child: Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                            onPressed: () {
                                              firestoreServices
                                                  .deleteCar(document.id);
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            );
                          });
                    }

                    // if there are no results
                    else {
                      return Center(
                          child: const Text(
                        "No Data",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ));
                    }
                  }),
            ),
          ],
        ),
        floatingActionButton: IconButton(
          style: ButtonStyle(
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                    color: Color(0xFF4993EE),
                    width: 2,
                    style: BorderStyle.solid),
              ),
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AddCar(
                        uid: userId,
                      )),
            );
          },
          icon: Icon(
            Icons.add,
            size: 30,
            color: Color(0xFF4993EE),
          ),
          tooltip: "Add New Car",
        ),
      ),
    );
  }
}

class AddCar extends StatelessWidget {
  String uid;
  AddCar({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text("Add Car"),
        leading: Icon(
          Icons.directions_car_outlined,
        ),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
               icon: Icon(
                  Icons.keyboard_backspace_rounded, color: Colors.white,
                  size: 30,
               ), )
        ],
      ),
      body: ListView.builder(
        itemCount: carMakesWithModels.length,
        itemBuilder: (context, index) {
          String make = carMakesWithModels.keys.elementAt(index);
          List<String> models = carMakesWithModels[make]!;

          return ExpansionTile(
            title: Text(make),
            children: models
                .map((model) => ListTile(
                    contentPadding: EdgeInsets.only(left: 32.0),
                    title: Text(model),
                    onTap: () {
                      make1 = make;
                      model1 = model;
                      // Handle model selection
                      showDialog<String>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Select Year'),
                            backgroundColor: Colors.white,
                            content: Container(
                              width: double.maxFinite,
                              height: 300,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: carYears.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    title: Text(carYears[index]),
                                    onTap: () {
                                      year1 = carYears[index];
                                    },
                                  );
                                },
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: Text('Add'),
                                onPressed: () {
                                  firestoreServices.addCar(
                                      uid, make1, model1, year1);
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    }))
                .toList(),
          );
        },
      ),
    );
  }
}
