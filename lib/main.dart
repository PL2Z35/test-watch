import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:workout/workout.dart';
import 'package:heart_rate_flutter/heart_rate_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Fictional Plugin: SpO2 and ECG (already included in your example).
class OxygenEcgPlugin {
  /// Simulates a stream of SpO2 values (95%-100%).
  Stream<double> get spO2Stream => Stream.periodic(
    const Duration(seconds: 5),
        (count) => 95 + Random().nextDouble() * 5,
  );

  /// Simulates a stream of ECG values.
  Stream<double> get ecgStream => Stream.periodic(
    const Duration(milliseconds: 500),
        (count) => Random().nextDouble() * 1.0, // Generic value
  );
}

/// Additional Fictional Plugin for Vital Signs (respiration rate, blood pressure, temperature).
/// Normally, this data would come from an external device or native API.
class VitalSignsPlugin {
  /// Respiration rate in breaths per minute (rpm).
  /// Normal values ~ 12-20 rpm.
  Stream<double> get respirationRateStream => Stream.periodic(
    const Duration(seconds: 5),
        (count) => 12 + Random().nextInt(9).toDouble(), // Between 12 and 20
  );

  /// Systolic blood pressure (high value, mmHg). Normal value ~ 90-120 mmHg.
  Stream<double> get systolicBloodPressureStream => Stream.periodic(
    const Duration(seconds: 10),
        (count) => 100 + Random().nextInt(30).toDouble(), // 100 - 130
  );

  /// Diastolic blood pressure (low value, mmHg). Normal value ~ 60-80 mmHg.
  Stream<double> get diastolicBloodPressureStream => Stream.periodic(
    const Duration(seconds: 10),
        (count) => 60 + Random().nextInt(20).toDouble(), // 60 - 80
  );

  /// Body temperature (°C). Normal value ~ 36.0 - 37.5 °C.
  Stream<double> get bodyTemperatureStream => Stream.periodic(
    const Duration(seconds: 7),
        (count) => 36 + Random().nextDouble() * 2, // ~36-38
  );
}

/// Entry point of the app.
void main() {
  runApp(Platform.isIOS ? const MyIosApp() : const MyApp());
}

/// Main application for platforms other than iOS.
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final workout = Workout();
  final HeartRateFlutter _heartRateFlutterPlugin = HeartRateFlutter();

  // Fictional Plugins
  final OxygenEcgPlugin _oxygenEcgPlugin = OxygenEcgPlugin();
  final VitalSignsPlugin _vitalSignsPlugin = VitalSignsPlugin();

  // Heart rate value (from heart_rate_flutter plugin)
  var heartBeatValue = 0;

  // SpO2 and ECG variables
  double spO2Value = 0.0;
  double ecgValue = 0.0;

  // Additional vital signs variables
  double respirationRateValue = 0.0;
  double systolicValue = 0.0;
  double diastolicValue = 0.0;
  double temperatureValue = 0.0;

  // Fall detection
  bool hasFallen = false;
  bool fallDetectionEnabled = true;

  // Danger status
  bool isInDanger = false;

  // Workout Variables
  final exerciseType = ExerciseType.walking;
  final features = [
    WorkoutFeature.heartRate,
    WorkoutFeature.calories,
    WorkoutFeature.steps,
    WorkoutFeature.distance,
    WorkoutFeature.speed,
  ];
  final enableGps = true;

  double heartRate = 0;
  double calories = 0;
  double steps = 0;
  double distance = 0;
  double speed = 0;
  bool started = false;

  // Sensor Variables
  double accX = 0, accY = 0, accZ = 0;
  double gyrX = 0, gyrY = 0, gyrZ = 0;
  double magX = 0, magY = 0, magZ = 0;

  // Subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<double>? _spO2Subscription;
  StreamSubscription<double>? _ecgSubscription;

  // New subscriptions for additional vital signs
  StreamSubscription<double>? _respirationSubscription;
  StreamSubscription<double>? _systolicSubscription;
  StreamSubscription<double>? _diastolicSubscription;
  StreamSubscription<double>? _temperatureSubscription;

  _MyAppState() {
    // Workout Listener
    workout.stream.listen(
          (event) {
        try {
          debugPrint('${event.feature}: ${event.value} (${event.timestamp})');
          switch (event.feature) {
            case WorkoutFeature.unknown:
            // No action
              break;
            case WorkoutFeature.heartRate:
              setState(() {
                heartRate = event.value ?? 0;
              });
              break;
            case WorkoutFeature.calories:
              setState(() {
                calories = event.value ?? 0;
              });
              break;
            case WorkoutFeature.steps:
              setState(() {
                steps = event.value ?? 0;
              });
              break;
            case WorkoutFeature.distance:
              setState(() {
                distance = event.value ?? 0;
              });
              break;
            case WorkoutFeature.speed:
              setState(() {
                speed = event.value ?? 0;
              });
              break;
          }
        } catch (e) {
          debugPrint('Error in workout stream: $e');
          setState(() {
            heartRate = 0;
            calories = 0;
            steps = 0;
            distance = 0;
            speed = 0;
          });
        }
      },
      onError: (error) {
        debugPrint('Error in workout.stream.listen: $error');
        setState(() {
          heartRate = 0;
          calories = 0;
          steps = 0;
          distance = 0;
          speed = 0;
        });
      },
    );
  }

  @override
  void initState() {
    super.initState();

    // Initialize heart rate plugin
    _heartRateFlutterPlugin.init();

    // Subscribe to heartBeatStream
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

    // Subscribe to SpO2 and ECG (fictional)
    try {
      _spO2Subscription = _oxygenEcgPlugin.spO2Stream.listen((value) {
        setState(() {
          spO2Value = value;
        });
      });
    } catch (e) {
      debugPrint('Error subscribing to SpO2: $e');
    }

    try {
      _ecgSubscription = _oxygenEcgPlugin.ecgStream.listen((value) {
        setState(() {
          ecgValue = value;
        });
      });
    } catch (e) {
      debugPrint('Error subscribing to ECG: $e');
    }

    // Subscribe to base sensors (accelerometer, gyroscope, magnetometer)
    try {
      _accelerometerSubscription = accelerometerEvents.listen((event) {
        setState(() {
          accX = event.x;
          accY = event.y;
          accZ = event.z;
        });
        if (fallDetectionEnabled) {
          detectFall(event);
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to accelerometer: $e');
    }

    try {
      _gyroscopeSubscription = gyroscopeEvents.listen((event) {
        setState(() {
          gyrX = event.x;
          gyrY = event.y;
          gyrZ = event.z;
        });
      });
    } catch (e) {
      debugPrint('Error subscribing to gyroscope: $e');
    }

    try {
      _magnetometerSubscription = magnetometerEvents.listen((event) {
        setState(() {
          magX = event.x;
          magY = event.y;
          magZ = event.z;
        });
      });
    } catch (e) {
      debugPrint('Error subscribing to magnetometer: $e');
    }

    // ================================
    // Subscribe to additional vital signs
    // ================================
    try {
      _respirationSubscription =
          _vitalSignsPlugin.respirationRateStream.listen((value) {
            setState(() {
              respirationRateValue = value;
            });
          });
    } catch (e) {
      debugPrint('Error in respiration rate: $e');
    }

    try {
      _systolicSubscription =
          _vitalSignsPlugin.systolicBloodPressureStream.listen((value) {
            setState(() {
              systolicValue = value;
            });
          });
    } catch (e) {
      debugPrint('Error in systolic blood pressure: $e');
    }

    try {
      _diastolicSubscription =
          _vitalSignsPlugin.diastolicBloodPressureStream.listen((value) {
            setState(() {
              diastolicValue = value;
            });
          });
    } catch (e) {
      debugPrint('Error in diastolic blood pressure: $e');
    }

    try {
      _temperatureSubscription =
          _vitalSignsPlugin.bodyTemperatureStream.listen((value) {
            setState(() {
              temperatureValue = value;
            });
          });
    } catch (e) {
      debugPrint('Error in body temperature: $e');
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _spO2Subscription?.cancel();
    _ecgSubscription?.cancel();
    _respirationSubscription?.cancel();
    _systolicSubscription?.cancel();
    _diastolicSubscription?.cancel();
    _temperatureSubscription?.cancel();
    super.dispose();
  }

  /// Simple fall detection: calculates the magnitude of acceleration and compares it against a threshold.
  void detectFall(AccelerometerEvent event) {
    final double magnitude =
    sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    const double fallThreshold = 25.0;

    if (magnitude > fallThreshold) {
      debugPrint('Possible fall detected. Magnitude: $magnitude');
      setState(() {
        hasFallen = true;
      });
    }
  }

  /// Checks vital signs and danger status.
  /// You can add more advanced or complex logic here.
  void checkDangerStatus() {
    bool danger = false;

    // Example of very simple thresholds (not clinical).
    // Adjust these values to reality or the regulations you consider.
    if (heartBeatValue < 40 || heartBeatValue > 150) {
      danger = true;
      debugPrint('Abnormal heart rate: $heartBeatValue');
    }
    if (spO2Value < 90) {
      danger = true;
      debugPrint('Low SpO2 level: $spO2Value');
    }
    // ECG: here only a fictitious number is shown; in practice, ECG wave analysis is required.
    // if (ecgValue ...)

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
      // If a fall is detected, we can include it as a danger factor.
      danger = true;
      debugPrint('The person has fallen.');
    }

    setState(() {
      isInDanger = danger;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Invoke checkDangerStatus periodically or each time build() is called.
    // You could also use a periodic Timer or do it in onData of each stream.
    checkDangerStatus();

    return MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: AmbientMode(
        builder: (context, mode, child) => child!,
        child: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Danger Status?: $isInDanger',
                    style: TextStyle(
                      color: isInDanger ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Heart rate
                  Text(
                      'Heart Rate (heart_rate_flutter plugin): $heartBeatValue'),
                  // Heart rate (Workout API)
                  Text('Heart Rate (Workout API): $heartRate'),
                  Text('Calories: ${calories.toStringAsFixed(2)}'),
                  Text('Steps: $steps'),
                  Text('Distance: ${distance.toStringAsFixed(2)}'),
                  Text('Speed: ${speed.toStringAsFixed(2)}'),

                  const Divider(),
                  // SpO2 and ECG
                  Text(
                      'Blood Oxygen (SpO₂): ${spO2Value.toStringAsFixed(1)} %'),
                  Text('ECG (simulated value): ${ecgValue.toStringAsFixed(3)}'),

                  const Divider(),
                  // Additional Vital Signs
                  Text(
                      'Respiration Rate: ${respirationRateValue.toStringAsFixed(0)} rpm'),
                  Text(
                      'Blood Pressure: ${systolicValue.toStringAsFixed(0)}/${diastolicValue.toStringAsFixed(0)} mmHg'),
                  Text(
                      'Body Temperature: ${temperatureValue.toStringAsFixed(1)} °C'),

                  const Divider(),
                  // Fall Detection
                  Text('Fall Detected?: $hasFallen'),

                  const Divider(),
                  // Accelerometer
                  Text('Accelerometer (m/s²):'),
                  Text('   X: ${accX.toStringAsFixed(2)}'),
                  Text('   Y: ${accY.toStringAsFixed(2)}'),
                  Text('   Z: ${accZ.toStringAsFixed(2)}'),

                  const Divider(),
                  // Gyroscope
                  Text('Gyroscope (rad/s):'),
                  Text('   X: ${gyrX.toStringAsFixed(2)}'),
                  Text('   Y: ${gyrY.toStringAsFixed(2)}'),
                  Text('   Z: ${gyrZ.toStringAsFixed(2)}'),

                  const Divider(),
                  // Magnetometer
                  Text('Magnetometer (µT):'),
                  Text('   X: ${magX.toStringAsFixed(2)}'),
                  Text('   Y: ${magY.toStringAsFixed(2)}'),
                  Text('   Z: ${magZ.toStringAsFixed(2)}'),

                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: toggleExerciseState,
                    child: Text(started ? 'Stop' : 'Start'),
                  ),

                  // Button to reset fall detection
                  TextButton(
                    onPressed: () {
                      setState(() {
                        hasFallen = false;
                      });
                    },
                    child: const Text('Reset Fall Detection'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Starts or stops the exercise (Workout).
  void toggleExerciseState() async {
    if (started) {
      await workout.stop();
    } else {
      try {
        final supportedExerciseTypes =
        await workout.getSupportedExerciseTypes();
        debugPrint('Supported exercise types: ${supportedExerciseTypes.length}');

        final result = await workout.start(
          exerciseType: exerciseType,
          features: features,
          enableGps: enableGps,
        );

        if (result.unsupportedFeatures.isNotEmpty) {
          debugPrint('Unsupported features: ${result.unsupportedFeatures}');
        } else {
          debugPrint('All requested features are supported');
        }
      } catch (e) {
        debugPrint('Error starting Workout: $e');
        setState(() {
          heartRate = 0;
          calories = 0;
          steps = 0;
          distance = 0;
          speed = 0;
          started = false;
        });
        return;
      }
    }
    setState(() => started = !started);
  }
}

/// Main App for iOS (maintains your previous logic).
class MyIosApp extends StatefulWidget {
  const MyIosApp({super.key});

  @override
  State<StatefulWidget> createState() => _MyIosAppState();
}

class _MyIosAppState extends State<MyIosApp> {
  final workout = Workout();
  var exerciseType = ExerciseType.workout;
  var locationType = WorkoutLocationType.indoor;
  var swimmingLocationType = WorkoutSwimmingLocationType.pool;
  var lapLength = 25.0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Exercise type dropdown
              DropdownButton<ExerciseType>(
                value: exerciseType,
                onChanged: (value) => setState(() => exerciseType = value!),
                items: ExerciseType.values
                    .map((e) =>
                    DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
              ),
              // Location type dropdown
              DropdownButton<WorkoutLocationType>(
                value: locationType,
                onChanged: (value) => setState(() => locationType = value!),
                items: WorkoutLocationType.values
                    .map((e) => DropdownMenuItem(
                    value: e, child: Text(e.name)))
                    .toList(),
              ),
              // Swimming location type dropdown (pool or open water)
              DropdownButton<WorkoutSwimmingLocationType>(
                value: swimmingLocationType,
                onChanged: (value) =>
                    setState(() => swimmingLocationType = value!),
                items: WorkoutSwimmingLocationType.values
                    .map((e) => DropdownMenuItem(
                    value: e, child: Text(e.name)))
                    .toList(),
              ),
              // Pool length field
              TextField(
                decoration:
                const InputDecoration(labelText: 'Pool Length (meters)'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  try {
                    setState(() => lapLength = double.parse(value));
                  } catch (e) {
                    debugPrint('Error parsing lapLength: $e');
                    setState(() => lapLength = 25.0);
                  }
                },
              ),
              ElevatedButton(
                onPressed: start,
                child: const Text('Start App on Apple Watch'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Starts the Workout on iOS.
  void start() {
    try {
      workout.start(
        exerciseType: exerciseType,
        features: [],
        locationType: locationType,
        swimmingLocationType: swimmingLocationType,
        lapLength: lapLength,
      );
    } catch (e) {
      debugPrint('Error starting Workout on iOS: $e');
    }
  }
}
