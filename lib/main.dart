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
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // MaterialApp with Material 3 enabled for updated design components.
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true, // Enable Material 3
        scaffoldBackgroundColor: Colors.black,
        textTheme: Typography.whiteMountainView, // Updated text theme
      ),
      home: const HomePage(), // Set HomePage as the home widget.
    );
  }
}

/// HomePage widget that handles the core functionality.
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Heart rate plugin instance.
  final HeartRateFlutter _heartRateFlutterPlugin = HeartRateFlutter();

  // Battery plugin instance.
  final Battery _battery = Battery();

  // Vital signs
  int heartRate = 0;

  // Fall detection
  bool hasFallen = false;
  bool fallDetectionEnabled = true;

  // Danger status indicator
  bool isInDanger = false;

  // Sensor readings
  double accX = 0, accY = 0, accZ = 0;
  double gyrX = 0, gyrY = 0, gyrZ = 0;
  double magX = 0, magY = 0, magZ = 0;

  // Battery level and activity
  int batteryLevel = 0;
  String activityType = 'Unknown';

  // Stream subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  // To prevent multiple alerts
  bool _isHeartRateAlertShown = false;
  bool _isFallAlertShown = false; // New flag for fall alerts

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
            heartRate = (event ?? 0).toInt();
          });

          // Check if heart rate is zero
          if (heartRate == 0 && !_isHeartRateAlertShown) {
            _isHeartRateAlertShown = true;
            _showHeartRateAlert();
          }
        }
      },
      onError: (error) {
        debugPrint('Error in heartBeatStream: $error');
        if (mounted) {
          setState(() {
            heartRate = 0;
          });

          if (!_isHeartRateAlertShown) {
            _isHeartRateAlertShown = true;
            _showHeartRateAlert();
          }
        }
      },
    );
  }

  /// Initializes battery monitoring and listens to state changes.
  Future<void> _initializeBattery() async {
    try {
      // Get initial battery level.
      batteryLevel = await _battery.batteryLevel;
      setState(() {});
    } catch (e) {
      debugPrint('Error fetching battery level: $e');
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

  /// Simple fall detection based on acceleration magnitude.
  void _detectFall(AccelerometerEvent event) {
    final double magnitude =
    sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    const double fallThreshold = 30.0;

    if (magnitude > fallThreshold && !hasFallen) {
      debugPrint('Possible fall detected. Magnitude: $magnitude');
      setState(() {
        hasFallen = true;
      });
      _triggerFallAlert(); // Trigger the fall alert
    }
  }

  /// Triggers the fall alert dialog with a 15-second countdown.
  void _triggerFallAlert() {
    if (!_isFallAlertShown) {
      _isFallAlertShown = true;
      // Ensure dialog is shown after the current frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showFallAlert();
        }
      });
    }
  }

  /// Displays an alert dialog with a timer when a fall is detected.
  void _showFallAlert() {
    const int countdownSeconds = 15;
    int remainingSeconds = countdownSeconds;
    Timer? countdownTimer;

    // Start the countdown timer
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        remainingSeconds--;
      });

      if (remainingSeconds <= 0) {
        timer.cancel();
        Navigator.of(context).pop(); // Close the dialog
        setState(() {
          isInDanger = true;
          hasFallen = false; // Reset fall detection
          _isFallAlertShown = false;
        });
        debugPrint('No response to fall alert. User marked as in danger.');
      }
    });

    // Show the dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismiss by tapping outside
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: AlertDialog(
            title: const Text(
              'Fall Detected',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 120, // Adjust as needed for small screens
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Are you okay?',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Time remaining: $remainingSeconds seconds',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              ElevatedButton(
                onPressed: () {
                  countdownTimer?.cancel();
                  Navigator.of(context).pop();
                  setState(() {
                    hasFallen = false; // Reset fall detection
                    _isFallAlertShown = false;
                  });
                  debugPrint('User responded they are okay.');
                },
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Yes'),
              ),
              ElevatedButton(
                onPressed: () {
                  countdownTimer?.cancel();
                  Navigator.of(context).pop();
                  setState(() {
                    isInDanger = true;
                    hasFallen = false; // Reset fall detection
                    _isFallAlertShown = false;
                  });
                  debugPrint('User responded they are not okay.');
                },
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor: Colors.redAccent,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('No'),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
      _isFallAlertShown = false;
    });
  }

  /// Basic activity detection based on acceleration magnitude.
  void _detectActivity(AccelerometerEvent event) {
    final double magnitude =
    sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    String newActivity;
    if (magnitude < 11) {
      newActivity = 'Inactive';
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

  /// Checks vital signs and updates danger status.
  void _checkDangerStatus() {
    bool danger = false;

    // Example thresholds (non-clinical).
    if (heartRate < 40 || heartRate > 150) {
      danger = true;
      debugPrint('Abnormal heart rate: $heartRate bpm');
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

  /// Displays an alert dialog with a timer when heart rate is zero.
  void _showHeartRateAlert() {
    const int countdownSeconds = 10;
    int remainingSeconds = countdownSeconds;
    Timer? countdownTimer;

    // Start the countdown timer
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        remainingSeconds--;
      });

      if (remainingSeconds <= 0) {
        timer.cancel();
        Navigator.of(context).pop(); // Close the dialog
        setState(() {
          isInDanger = true;
          _isHeartRateAlertShown = false;
        });
        debugPrint(
            'No response to heart rate alert. User marked as in danger.');
      }
    });

    // Show the dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismiss by tapping outside
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: AlertDialog(
            title: const Text(
              'Heart Rate Alert',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 120, // Adjust as needed for small screens
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Your heart rate is zero. Are you okay?',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Time remaining: $remainingSeconds seconds',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              ElevatedButton(
                onPressed: () {
                  countdownTimer?.cancel();
                  Navigator.of(context).pop();
                  setState(() {
                    _isHeartRateAlertShown = false;
                  });
                  debugPrint('User responded they are okay.');
                },
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Yes'),
              ),
              ElevatedButton(
                onPressed: () {
                  countdownTimer?.cancel();
                  Navigator.of(context).pop();
                  setState(() {
                    isInDanger = true;
                    _isHeartRateAlertShown = false;
                  });
                  debugPrint('User responded they are not okay.');
                },
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor: Colors.redAccent,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('No'),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
      _isHeartRateAlertShown = false;
    });
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions to avoid memory leaks.
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _batteryStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check danger status on each build.
    _checkDangerStatus();

    return AmbientMode(
      builder: (context, mode, child) => child!,
      child: Scaffold(
        body: Stack(
          children: [
            // Central Circular Design
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 280, // Reduced size for better fit on small screens
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                  isInDanger ? Colors.redAccent : Colors.blueGrey[900],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0), // Reduced padding
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Danger Status
                      _buildStatusIcon(
                        icon: isInDanger
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_rounded,
                        color: isInDanger ? Colors.red : Colors.green,
                        label: isInDanger ? 'Danger' : 'Safe',
                      ),
                      const SizedBox(height: 16),
                      // Heart Rate
                      _buildIconValueRow(
                        icon: Icons.favorite,
                        value: '$heartRate bpm',
                        label: 'Heart Rate',
                      ),
                      const SizedBox(height: 8),
                      // Fall Detection
                      _buildIconValueRow(
                        icon: hasFallen
                            ? Icons.person_remove
                            : Icons.person_add,
                        value: hasFallen ? 'Yes' : 'No',
                        label: 'Fall Detected',
                        iconColor: hasFallen ? Colors.red : Colors.green,
                      ),
                      const SizedBox(height: 8),
                      // Battery Level and Activity
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                        children: [
                          // Battery
                          _buildIconValueColumn(
                            icon: Icons.battery_std,
                            value: '$batteryLevel%',
                            label: 'Battery',
                          ),
                          // Activity
                          _buildIconValueColumn(
                            icon: _getActivityIcon(),
                            value: activityType,
                            label: 'Activity',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the appropriate activity icon based on the current activity.
  IconData _getActivityIcon() {
    switch (activityType) {
      case 'Inactive':
        return Icons.hourglass_empty;
      case 'Walking':
        return Icons.directions_walk;
      case 'Running':
        return Icons.directions_run;
      default:
        return Icons.help_outline;
    }
  }

  /// Builds a row with an icon and its corresponding value.
  Widget _buildIconValueRow({
    required IconData icon,
    required String value,
    required String label,
    Color iconColor = Colors.white,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
        const SizedBox(width: 8),
        Flexible( // Ensures text wraps if necessary
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis, // Prevents overflow
          ),
        ),
      ],
    );
  }

  /// Builds a column with an icon and its corresponding value.
  Widget _buildIconValueColumn({
    required IconData icon,
    required String value,
    required String label,
    Color iconColor = Colors.white,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  /// Builds a status icon with a label.
  Widget _buildStatusIcon({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 28,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// (Optional) Builds an overlay to display detailed sensor data.
  Widget _buildSensorDataOverlay() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.black54,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Accelerometer
          _buildSensorIconValue(
            icon: Icons.arrow_upward,
            label: 'Accel',
            value:
            'X:${accX.toStringAsFixed(1)} Y:${accY.toStringAsFixed(1)} Z:${accZ.toStringAsFixed(1)}',
          ),
          // Gyroscope
          _buildSensorIconValue(
            icon: Icons.g_mobiledata,
            label: 'Gyro',
            value:
            'X:${gyrX.toStringAsFixed(1)} Y:${gyrY.toStringAsFixed(1)} Z:${gyrZ.toStringAsFixed(1)}',
          ),
          // Magnetometer
          _buildSensorIconValue(
            icon: Icons.filter_hdr,
            label: 'Mag',
            value:
            'X:${magX.toStringAsFixed(1)} Y:${magY.toStringAsFixed(1)} Z:${magZ.toStringAsFixed(1)}',
          ),
        ],
      ),
    );
  }

  /// Builds a sensor icon with its corresponding value.
  Widget _buildSensorIconValue({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.blueAccent,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $value',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

/// Main application widget for iOS platforms without exercise functionality.
class MyIosApp extends StatelessWidget {
  const MyIosApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // UI specific to iOS without exercise functionality.
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('iOS App')),
        body: const SafeArea(
          child: Center(
            child: Text(
              'iOS app version without exercise functionality.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}
