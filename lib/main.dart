import 'package:flutter/material.dart';
import 'package:location_track/admin.dart';
import 'package:location_track/firebase_options.dart';
import 'package:location_track/mapPage.dart';
import 'package:location_track/sqflite.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:permission_handler/permission_handler.dart' as permission;
import 'package:location/location.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final service = FlutterBackgroundService();

Future<void> requestPermissions() async {
  final status = await permission.Permission.notification.request();
  if (!status.isGranted) {
    print('Notification permission not granted');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await requestPermissions();
  await initializeService();

  // Call this function to upload the data to Firestore
  await uploadDataToFirestore();
  runApp(const MyApp());
}

Future<void> initializeService() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'MY FOREGROUND SERVICE',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('ic_bg_service_small'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'AWESOME SERVICE',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [
        AndroidForegroundType.location,
      ],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  print('FLUTTER BACKGROUND SERVICE: Ios Background Fetch');
  return true;
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
      print("App is running in foreground ");
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
      print("App is running in background ");
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    Location location = Location();
    LocationData locationData = await location.getLocation();
    await saveLocation(locationData.latitude, locationData.longitude);
    await uploadDataToFirestore();
    print(
        'Location saved: ${locationData.latitude}, ${locationData.longitude}');

    print('FLUTTER BACKGROUND SERVICE: upperwala ${DateTime.now()}');

    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        flutterLocalNotificationsPlugin.show(
          888,
          'COOL SERVICE',
          'Awesome ${DateTime.now()}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );

        service.setForegroundNotificationInfo(
          title: "Service being logged",
          content: "Updated at ${DateTime.now()}",
        );
      }
    }

    print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
      },
    );
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Location location = Location();
  bool _serviceEnabled = false;
  PermissionStatus? _permissionGranted;

  @override
  void initState() {
    super.initState();
    _checkLocationPermissions();
  }

  Future<void> _checkLocationPermissions() async {
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    } else if (_permissionGranted == PermissionStatus.deniedForever) {
      _showPermissionDialog();
      return;
    }

    if (_permissionGranted == PermissionStatus.granted) {
      print('Location Access Granted!');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Important!'),
        content: const Text(
            'You have denied permission for location, please enable it via Settings > Apps > app_name > permissions'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            child: const Text('Open Settings'),
            onPressed: () {
              permission.openAppSettings();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'LocationTrack',
        theme: ThemeData().copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        builder: (_, child) => _Unfocus(child: child!),
        home: AdminMapScreen());
  }
}

class _Unfocus extends StatelessWidget {
  const _Unfocus({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus,
      child: child,
    );
  }
}

class LocationScreen extends StatefulWidget {
  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  List<Map<String, dynamic>> _data = [];

  Future<void> _fetchData() async {
    final dbHelper = DatabaseHelper.instance;
    final data = await dbHelper.queryAllRows(); // Fetch all rows
    setState(() {
      _data = data;
    });
  }

  Future<void> clearDatabase() async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.clearAllTables();
    print("The location data of User are $_data");
  }

  getdata() {
    print(_data);
  }

  Location location = Location();
  late bool _serviceEnabled;
  late PermissionStatus _permissionGranted;
  late LocationData _locationData;
  String locationString = "Fetching location...";

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    // Check if location service is enabled
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        setState(() {
          locationString = "Location service disabled.";
        });
        return;
      }
    }

    // Request location permission
    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        setState(() {
          locationString = "Location permission denied.";
        });
        return;
      }
    }

//  Location location = Location();
    Timer.periodic(const Duration(minutes: 30), (timer) async {
      LocationData locationData = await location.getLocation();
      await saveLocation(locationData.latitude, locationData.longitude);
      print(
          'Location saved: ${locationData.latitude}, ${locationData.longitude}');

      print('FLUTTER BACKGROUND SERVICE lowerwala: ${DateTime.now()}');
    });

    // Get the current location
    _locationData = await location.getLocation();
    setState(() {
      locationString =
          "Latitude: ${_locationData.latitude}, Longitude: ${_locationData.longitude}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('User Location'),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                MaterialButton(
                  onPressed: () {
                    _fetchData();
                    print(_data);
                  },
                  child: Text("Get User Location"),
                  color: Colors.blue,
                ),
                MaterialButton(
                  onPressed: () {
                    clearDatabase();
                  },
                  child: Text("Clear Database"),
                  color: Colors.blue,
                ),
                MaterialButton(
                  onPressed: () {
                    getdata();
                  },
                  child: Text("data"),
                  color: Colors.blue,
                ),
                Text("the location of user is $_data"),
                Text(locationString)
              ],
            ),
          ),
        ));
  }
}
