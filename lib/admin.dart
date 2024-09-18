import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AdminMapScreen extends StatefulWidget {
  @override
  _AdminMapScreenState createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserLocations();
  }

  // Fetch all user locations from Firestore
  Future<void> _fetchUserLocations() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore.collection('locations').get();

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;
          var latitude = data['latitude'];
          var longitude = data['longitude'];

          // Print latitude and longitude for debugging
          print('Lat: $latitude, Lng: $longitude');

          if (latitude != null && longitude != null) {
            setState(() {
              _markers.add(Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(latitude, longitude),
                infoWindow: InfoWindow(
                  title: 'User: ${doc.id}',
                  snippet: 'Lat: $latitude, Lng: $longitude',
                ),
              ));
            });
          }
        }

        // Move the camera to the first marker's position
        if (_markers.isNotEmpty) {
          _mapController
              ?.animateCamera(CameraUpdate.newLatLng(_markers.first.position));
        }
      }
    } catch (e) {
      print('Error fetching user locations: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin - User Locations'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                    27.67282385538321, 85.31359345049343), // Initial location
                zoom: 14,
              ),
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
    );
  }
}
