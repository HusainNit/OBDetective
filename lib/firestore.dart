import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreServices {
  // Collection references
  final CollectionReference users =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference cars =
      FirebaseFirestore.instance.collection('cars');

  // CREATE: add a new user based on type
  Future<DocumentReference> addUser(
      String name, String email, String password, String userType,
      {String? phone, Map<String, dynamic>? location, String? speciality}) {
    Map<String, dynamic> userData = {
      'name': name,
      'email': email,
      'password': password,
      'userType': userType,
      'createdAt': Timestamp.now(),
    };

    // Add additional fields based on user type
    if (userType == 'mechanical' || userType == 'tow') {
      userData['phone'] = phone;
    }

    if (userType == 'mechanical' && location != null && speciality != null) {
      userData['location'] = {
        'latitude': location['latitude'],
        'longitude': location['longitude'],
        'formatted': location['formatted']
      };

      userData['speciality'] = speciality;
    }

    if (userType == 'tow') {
      userData['isAvailable'] = true;
    }

    return users.add(userData);
  }

  // READ: authenticate user (without Firebase Auth)
  Future<Map<String, dynamic>?> authenticateUser(
      String email, String password) async {
    final QuerySnapshot snapshot =
        await users.where('email', isEqualTo: email).limit(1).get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final userDoc = snapshot.docs.first;
    final userData = userDoc.data() as Map<String, dynamic>;

    if (userData['password'] == password) {
      return {
        ...userData,
        'id': userDoc.id,
      };
    }

    return null;
  }

  // READ: get user data by ID
  Future<DocumentSnapshot> getUserById(String userId) {
    return users.doc(userId).get();
  }

  // READ: get all users of specific type
  Future<QuerySnapshot> getUsersByType(String userType) {
    return users.where('userType', isEqualTo: userType).get();
  }

  // UPDATE: update user profile
  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updatedData) {
    return users.doc(userId).update(updatedData);
  }

  // UPDATE: update password
  Future<void> updatePassword(String userId, String newPassword) {
    return users.doc(userId).update({
      'password': newPassword,
    });
  }

  // CREATE: add a new Car with user ID
  Future<DocumentReference> addCar(
      String userId, String make, String model, String year) {
    return cars.add({
      'userId': userId,
      'make': make,
      'model': model,
      'year': year,
      'createdAt': Timestamp.now(),
    });
  }

  // READ: get cars from database for a specific user
  Stream<QuerySnapshot> getUserCarsStream(String userId) {
    return cars.where('userId', isEqualTo: userId).snapshots();
  }

  // DELETE: delete car given a doc id
  Future<void> deleteCar(String carId) {
    return cars.doc(carId).delete();
  }

  // READ: get Tow trucks for a specific user
  Stream<QuerySnapshot> getAllTowTrucksStream() {
    return users
        .where('userType', isEqualTo: 'tow')
        .where('isAvailable', isEqualTo: true)
        .snapshots();
  }

  // UPDATE: update Tow truck availability
  Future<void> updateTowTruckAvailability(String userId, bool isAvailable) {
    return users.doc(userId).update({
      'isAvailable': isAvailable,
    });
  }

  // UPDATE: update mechanic timings availability
  Future<void> updateMechanicTiming(String userId, String start, String end) {
    return users.doc(userId).update({
      'start': start,
      'end': end,
    });
  }

  // UPDATE: update mechanic specialty
  Future<void> updateMechanicSpec(String userId, String speciality) {
    return users.doc(userId).update({
      'speciality': speciality,
    });
  }

  // READ: get all mechanics
  Stream<QuerySnapshot> getMechanicsStream() {
    return users.where('userType', isEqualTo: 'mechanical').snapshots();
  }
}
