import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camerawesome/models/orientations.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock/wakelock.dart';
import 'package:camerawesome/camerawesome_plugin.dart';

Future<void> main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Wakelock.enable();
    return const MaterialApp(
      home: MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  initState() {
    checkGps();
    _startTimer();
  }

  //Counting pictures
  int picNumber = 0;
  List<File> capturedImages = [];

  //Initialise the counter variables
  int _counter = 1;
  late Timer _timer;

  //GPS variables
  bool serviceStatus = false;
  bool haspermission = false;
  late LocationPermission permission;
  late Position position;
  String long = "", lat = "";
  late StreamSubscription<Position> positionStream;
  late String timestamp;

  //Camerawesome integration variables
  // Notifiers
  final ValueNotifier<CameraFlashes> _switchFlash =
      ValueNotifier(CameraFlashes.NONE);
  final ValueNotifier<Sensors> _sensor = ValueNotifier(Sensors.BACK);
  final ValueNotifier<CaptureModes> _captureMode =
      ValueNotifier(CaptureModes.PHOTO);
  final ValueNotifier<double> _zoomNotifier = ValueNotifier(0);
  final ValueNotifier<Size> _photoSize = ValueNotifier(const Size(1920, 1080));

  // Camera Controllers
  final PictureController _pictureController = PictureController();
  // list of available sizes

  // Method with a little timer
  void _startTimer() {
    _counter = 1;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_counter > 0) {
          _counter--;
        } else if (_counter == 0) {
          // Take picture and restart counter
          _counter = 1;
          picNumber++;
          //takeApic();
        }
      });
    });
  }

  // Method to initialise the GPS signal when permission is granted, calling getLocation
  checkGps() async {
    serviceStatus = await Geolocator.isLocationServiceEnabled();
    if (serviceStatus) {
      permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
        } else if (permission == LocationPermission.deniedForever) {
          print('Location permissions are permanently denied');
        } else {
          haspermission = true;
        }
      } else {
        haspermission = true;
      }
      if (haspermission) {
        setState(() {
          // refresh the UI
        });
        getLocation();
      }
    } else {
      print("GPS Service is not enabled, turn on GPS location");
    }
    setState(() {});
  }

  //Method to retrieve the current GPS Location
  getLocation() async {
    position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best);
    print("Lon: " + position.longitude.toString());
    print("Lat: " + position.latitude.toString());

    setState(() {});
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter:
          1, //minimum distance in meters for a device must move to update event is generated
    );
    StreamSubscription<Position> positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      print(position.longitude);
      print(position.latitude);

      long = position.longitude.toString();
      lat = position.latitude.toString();
      timestamp = getTimestamp();
      print(timestamp);
      setState(() {});
    });
  }

  takeApic() async {
    final Directory extDir = await getTemporaryDirectory();
    final testDir =
        await Directory('${extDir.path}/pictures').create(recursive: true);
    final String filePath = '${testDir.path}/$picNumber-$lat:$long.jpg';
    await _pictureController.takePicture(filePath);
  }

  @override
  void dispose() {
    _photoSize.dispose();
    _captureMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Amphora Camerawesome"),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(child: buildSizedScreenCamera()),
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Column(
                    children: <Widget>[
                      (_counter > 0)
                          ? Text(
                              "$_counter",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 48,
                              ),
                            )
                          : const Text(
                              "Taking Pic!",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 48,
                              ),
                            ),
                      Text("Longitude: $long",
                          style: const TextStyle(fontSize: 20)),
                      Text(
                        "Latitude: $lat",
                        style: const TextStyle(fontSize: 20),
                      )
                    ],
                  ),
                  //Text(timestamp, style: TextStyle(fontSize: 20),),
                  Text(
                    'Total pics: $picNumber',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            )
          ],
        ));
  }

  String getTimestamp() {
    int timestamp = DateTime.now().microsecondsSinceEpoch;
    DateTime tsdate = DateTime.fromMicrosecondsSinceEpoch(timestamp);
    String date = tsdate.year.toString() +
        "/" +
        tsdate.month.toString() +
        "/" +
        tsdate.day.toString() +
        " " +
        tsdate.hour.toString() +
        ":" +
        tsdate.minute.toString() +
        ":" +
        tsdate.second.toString();
    return date;
  }

  void Function(bool?)? _onPermissionsResult(bool granted) {
    if (!granted) {
      AlertDialog alert = AlertDialog(
        title: const Text('Error'),
        content: const Text(
            'It seems you didn\'t authorized some permissions. Please check on your settings and try again.'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );

      // show the dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return alert;
        },
      );
    } else {
      setState(() {});
      print("granted");
    }
  }

  Widget buildSizedScreenCamera() {
    return Positioned(
      top: 0,
      left: 0,
      bottom: 0,
      right: 0,
      child: Container(
        color: Colors.black,
        child: Center(
          child: Container(
            height: 300,
            width: MediaQuery.of(context).size.width,
            child: CameraAwesome(
              //onPermissionsResult: _onPermissionsResult,
              captureMode: _captureMode,
              photoSize: _photoSize,
              sensor: _sensor,
              fitted: true,
              switchFlashMode: _switchFlash,
              zoom: _zoomNotifier,
            ),
          ),
        ),
      ),
    );
  }
}
