import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:heart_rate_flutter/heart_rate_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:battery_plus/battery_plus.dart';

/// Entry point of the application.
void main() {
  runApp(Platform.isIOS ? const MyIosApp() : const MyApp());
}

/// Main application widget for non-iOS platforms.
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Heart rate plugin instance.
  final HeartRateFlutter _heartRateFlutterPlugin = HeartRateFlutter();

  // Battery plugin instance.
  final Battery _battery = Battery();

  // Vital signs
  int heartBeatValue = 0;
  double spO2Value = 0.0;
  double ecgValue = 0.0;
  double respirationRateValue = 0.0;
  double systolicValue = 0.0;
  double diastolicValue = 0.0;
  double temperatureValue = 0.0;

  // Fall detection
  bool hasFallen = false;
  bool fallDetectionEnabled = true;

  // Danger status flag
  bool isInDanger = false;

  // Sensor readings
  double accX = 0, accY = 0, accZ = 0;
  double gyrX = 0, gyrY = 0, gyrZ = 0;
  double magX = 0, magY = 0, magZ = 0;

  // Battery and activity status
  int batteryLevel = 0;
  String activityType = 'Unknown';

  // Stream subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<double>? _spO2Subscription;
  StreamSubscription<double>? _ecgSubscription;
  StreamSubscription<double>? _respirationSubscription;
  StreamSubscription<double>? _systolicSubscription;
  StreamSubscription<double>? _diastolicSubscription;
  StreamSubscription<double>? _temperatureSubscription;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeHeartRate();
    _initializeBattery();
    _initializeSensors();
  }

  /// Initializes the heart rate plugin and listens to its stream.
  void _initializeHeartRate() {
    _heartRateFlutterPlugin.init();

    _heartRateFlutterPlugin.heartBeatStream.listen(
          (double? event) {
        if (mounted) {
          setState(() {
            heartBeatValue = (event ?? 0).toInt();
          });
        }
      },
      onError: (error) {
        debugPrint('Error in heartBeatStream: $error');
        if (mounted) {
          setState(() {
            heartBeatValue = 0;
          });
        }
      },
    );
  }

  /// Initializes battery monitoring and listens to battery state changes.
  Future<void> _initializeBattery() async {
    try {
      // Get the initial battery level.
      batteryLevel = await _battery.batteryLevel;
      setState(() {});
    } catch (e) {
      debugPrint('Error obtaining battery level: $e');
    }

    // Listen to battery state changes (charging, discharging, etc.).
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen(
          (BatteryState state) async {
        try {
          final level = await _battery.batteryLevel;
          if (mounted) {
            setState(() {
              batteryLevel = level;
            });
          }
        } catch (e) {
          debugPrint('Error updating battery level: $e');
        }
      },
    );
  }

  /// Initializes sensor streams and sets up listeners for each sensor.
  void _initializeSensors() {
    // Accelerometer
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      setState(() {
        accX = event.x;
        accY = event.y;
        accZ = event.z;
      });
      _handleAccelerometer(event);
    });

    // Gyroscope
    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      setState(() {
        gyrX = event.x;
        gyrY = event.y;
        gyrZ = event.z;
      });
    });

    // Magnetometer
    _magnetometerSubscription = magnetometerEvents.listen((event) {
      setState(() {
        magX = event.x;
        magY = event.y;
        magZ = event.z;
      });
    });

    // Additional sensor streams can be initialized here if needed.
  }

  /// Handles accelerometer events for fall detection and activity monitoring.
  void _handleAccelerometer(AccelerometerEvent event) {
    if (fallDetectionEnabled) {
      _detectFall(event);
      _detectActivity(event);
    }
  }

  /// Simple fall detection based on the magnitude of acceleration.
  void _detectFall(AccelerometerEvent event) {
    final double magnitude =
    sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    const double fallThreshold = 25.0;

    if (magnitude > fallThreshold && !hasFallen) {
      debugPrint('Possible fall detected. Magnitude: $magnitude');
      setState(() {
        hasFallen = true;
      });
    }
  }

  /// Basic activity detection based on the magnitude of acceleration.
  void _detectActivity(AccelerometerEvent event) {
    final double magnitude =
    sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    String newActivity;
    if (magnitude < 11) {
      newActivity = 'Idle';
    } else if (magnitude < 18) {
      newActivity = 'Walking';
    } else {
      newActivity = 'Running';
    }

    if (activityType != newActivity) {
      setState(() {
        activityType = newActivity;
      });
    }
  }

  /// Checks vital signs and updates the danger status.
  void _checkDangerStatus() {
    bool danger = false;

    // Example thresholds (non-clinical).
    if (heartBeatValue < 40 || heartBeatValue > 150) {
      danger = true;
      debugPrint('Abnormal heart rate: $heartBeatValue bpm');
    }
    if (spO2Value < 90) {
      danger = true;
      debugPrint('Low SpO2: $spO2Value%');
    }
    if (respirationRateValue < 8 || respirationRateValue > 30) {
      danger = true;
      debugPrint('Abnormal respiration rate: $respirationRateValue');
    }
    if (systolicValue > 180 || diastolicValue > 120) {
      danger = true;
      debugPrint(
          'Dangerous hypertension: ${systolicValue.toStringAsFixed(0)}/${diastolicValue.toStringAsFixed(0)} mmHg');
    }
    if (temperatureValue > 39 || temperatureValue < 35) {
      danger = true;
      debugPrint(
          'Abnormal temperature: ${temperatureValue.toStringAsFixed(1)} °C');
    }
    if (hasFallen) {
      danger = true;
      debugPrint('User has fallen.');
    }

    if (isInDanger != danger) {
      setState(() {
        isInDanger = danger;
      });
    }
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks.
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _spO2Subscription?.cancel();
    _ecgSubscription?.cancel();
    _respirationSubscription?.cancel();
    _systolicSubscription?.cancel();
    _diastolicSubscription?.cancel();
    _temperatureSubscription?.cancel();
    _batteryStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check danger status during each build.
    _checkDangerStatus();

    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: AmbientMode(
        builder: (context, mode, child) => child!,
        child: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildDangerStatus(),
                  const SizedBox(height: 20),
                  _buildVitalSigns(),
                  const Divider(),
                  _buildFallDetection(),
                  const Divider(),
                  _buildAccelerometerData(),
                  const Divider(),
                  _buildGyroscopeData(),
                  const Divider(),
                  _buildMagnetometerData(),
                  const Divider(),
                  _buildBatteryAndActivity(),
                  const SizedBox(height: 40),
                  _buildResetButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the danger status display widget.
  Widget _buildDangerStatus() {
    return Text(
      'Danger Status: ${isInDanger ? "Yes" : "No"}',
      style: TextStyle(
        color: isInDanger ? Colors.red : Colors.green,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  /// Builds the vital signs display widget.
  Widget _buildVitalSigns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Heart Rate: $heartBeatValue bpm',
          style: const TextStyle(fontSize: 16),
        ),
        // Additional vital signs can be displayed here.
      ],
    );
  }

  /// Builds the fall detection display widget.
  Widget _buildFallDetection() {
    return Text(
      'Fall Detected: ${hasFallen ? "Yes" : "No"}',
      style: const TextStyle(fontSize: 16),
    );
  }

  /// Builds the accelerometer data display widget.
  Widget _buildAccelerometerData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accelerometer (m/s²):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text('   X: ${accX.toStringAsFixed(2)}'),
        Text('   Y: ${accY.toStringAsFixed(2)}'),
        Text('   Z: ${accZ.toStringAsFixed(2)}'),
      ],
    );
  }

  /// Builds the gyroscope data display widget.
  Widget _buildGyroscopeData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gyroscope (rad/s):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text('   X: ${gyrX.toStringAsFixed(2)}'),
        Text('   Y: ${gyrY.toStringAsFixed(2)}'),
        Text('   Z: ${gyrZ.toStringAsFixed(2)}'),
      ],
    );
  }

  /// Builds the magnetometer data display widget.
  Widget _buildMagnetometerData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Magnetometer (µT):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text('   X: ${magX.toStringAsFixed(2)}'),
        Text('   Y: ${magY.toStringAsFixed(2)}'),
        Text('   Z: ${magZ.toStringAsFixed(2)}'),
      ],
    );
  }

  /// Builds the battery level and activity type display widget.
  Widget _buildBatteryAndActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Battery Level: $batteryLevel%'),
        Text('Activity: $activityType'),
      ],
    );
  }

  /// Builds the reset button for fall detection.
  Widget _buildResetButton() {
    return TextButton(
      onPressed: () {
        setState(() {
          hasFallen = false;
        });
      },
      child: const Text('Reset Fall Detection'),
    );
  }
}

/// Main application widget for iOS platforms without workout functionality.
class MyIosApp extends StatelessWidget {
  const MyIosApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // iOS-specific UI without workout functionality.
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('iOS App')),
        body: const SafeArea(
          child: Center(
            child: Text(
              'iOS version of the app without workout functionality.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}
