import 'dart:io';
import 'dart:async'; // Important for stream subscriptions
import 'package:flutter/material.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:workout/workout.dart';
import 'package:heart_rate_flutter/heart_rate_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart'; // <-- Importing sensors_plus package

/// The main entry point of the application.
/// It determines the platform and runs the appropriate app (iOS or others).
void main() {
  runApp(Platform.isIOS ? const MyIosApp() : const MyApp());
}

/// The main application widget for non-iOS platforms.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// The state class for [MyApp].
class _MyAppState extends State<MyApp> {
  final workout = Workout();
  final HeartRateFlutter _heartRateFlutterPlugin = HeartRateFlutter();

  /// Variable to display heart rate (from heart_rate_flutter plugin)
  var heartBeatValue = 0;

  // Configuration for the workout
  final exerciseType = ExerciseType.walking;
  final features = [
    WorkoutFeature.heartRate,
    WorkoutFeature.calories,
    WorkoutFeature.steps,
    WorkoutFeature.distance,
    WorkoutFeature.speed,
  ];
  final enableGps = true;

  // Variables to store workout data
  double heartRate = 0;
  double calories = 0;
  double steps = 0;
  double distance = 0;
  double speed = 0;
  bool started = false;

  // Variables to store sensor readings
  double accX = 0, accY = 0, accZ = 0;
  double gyrX = 0, gyrY = 0, gyrZ = 0;
  double magX = 0, magY = 0, magZ = 0;

  // Subscriptions to sensor streams
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  /// Constructor for [_MyAppState].
  /// Sets up the workout stream listener with error handling.
  _MyAppState() {
    /// Listen to the main workout stream with error handling
    workout.stream.listen(
          (event) {
        try {
          debugPrint('${event.feature}: ${event.value} (${event.timestamp})');
          switch (event.feature) {
            case WorkoutFeature.unknown:
            // Do nothing special for unknown features
              break;
            case WorkoutFeature.heartRate:
              setState(() {
                // If event.value is null, use 0 as default
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
          // On any exception, reset values to zero
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
        debugPrint('Error in stream.listen: $error');
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

    /// Initialize the heart rate plugin
    _heartRateFlutterPlugin.init();

    /// Subscribe to the heart rate stream with error handling
    _heartRateFlutterPlugin.heartBeatStream.listen(
          (double? event) {
        if (mounted) {
          setState(() {
            /// Convert the double value to int, default to 0 if null
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

    /// Subscribe to the accelerometer sensor with exception handling
    try {
      _accelerometerSubscription =
          accelerometerEvents.listen((AccelerometerEvent event) {
            setState(() {
              accX = event.x;
              accY = event.y;
              accZ = event.z;
            });
          });
    } catch (e) {
      debugPrint('Error subscribing to accelerometer: $e');
    }

    /// Subscribe to the gyroscope sensor with exception handling
    try {
      _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
        setState(() {
          gyrX = event.x;
          gyrY = event.y;
          gyrZ = event.z;
        });
      });
    } catch (e) {
      debugPrint('Error subscribing to gyroscope: $e');
    }

    /// Subscribe to the magnetometer sensor with exception handling
    try {
      _magnetometerSubscription =
          magnetometerEvents.listen((MagnetometerEvent event) {
            setState(() {
              magX = event.x;
              magY = event.y;
              magZ = event.z;
            });
          });
    } catch (e) {
      debugPrint('Error subscribing to magnetometer: $e');
    }
  }

  @override
  void dispose() {
    // Cancel subscriptions to prevent memory leaks
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  // Heart rate from heart_rate_flutter plugin
                  Text('Heart rate value (plugin): $heartBeatValue'),
                  // Heart rate from Workout API
                  Text('Heart rate (Workout API): $heartRate'),
                  Text('Calories: ${calories.toStringAsFixed(2)}'),
                  Text('Steps: $steps'),
                  Text('Distance: ${distance.toStringAsFixed(2)}'),
                  Text('Speed: ${speed.toStringAsFixed(2)}'),
                  const Divider(),
                  // Accelerometer readings
                  Text('Accelerometer:'),
                  Text('   X: ${accX.toStringAsFixed(2)}'),
                  Text('   Y: ${accY.toStringAsFixed(2)}'),
                  Text('   Z: ${accZ.toStringAsFixed(2)}'),
                  const Divider(),
                  // Gyroscope readings
                  Text('Gyroscope:'),
                  Text('   X: ${gyrX.toStringAsFixed(2)}'),
                  Text('   Y: ${gyrY.toStringAsFixed(2)}'),
                  Text('   Z: ${gyrZ.toStringAsFixed(2)}'),
                  const Divider(),
                  // Magnetometer readings
                  Text('Magnetometer:'),
                  Text('   X: ${magX.toStringAsFixed(2)}'),
                  Text('   Y: ${magY.toStringAsFixed(2)}'),
                  Text('   Z: ${magZ.toStringAsFixed(2)}'),
                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: toggleExerciseState,
                    child: Text(started ? 'Stop' : 'Start'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Toggles the exercise state between started and stopped.
  /// Starts or stops the workout accordingly.
  void toggleExerciseState() async {
    if (started) {
      // If workout is started, stop it
      await workout.stop();
    } else {
      // If workout is not started, attempt to start it
      try {
        // Retrieve supported exercise types
        final supportedExerciseTypes = await workout.getSupportedExerciseTypes();
        debugPrint('Supported exercise types: ${supportedExerciseTypes.length}');

        // Start the workout with specified configuration
        final result = await workout.start(
          exerciseType: exerciseType,
          features: features,
          enableGps: enableGps,
        );

        // Check for unsupported features
        if (result.unsupportedFeatures.isNotEmpty) {
          debugPrint('Unsupported features: ${result.unsupportedFeatures}');
        } else {
          debugPrint('All requested features supported');
        }
      } catch (e) {
        debugPrint('Error starting workout: $e');
        // Reset values in case of error
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

    // Toggle the started state
    setState(() => started = !started);
  }
}

/// The main application widget for iOS platforms.
class MyIosApp extends StatefulWidget {
  const MyIosApp({super.key});

  @override
  State<StatefulWidget> createState() => _MyIosAppState();
}

/// The state class for [MyIosApp].
class _MyIosAppState extends State<MyIosApp> {
  final workout = Workout();

  // Configuration variables for the workout
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
              // Dropdown to select exercise type
              DropdownButton<ExerciseType>(
                value: exerciseType,
                onChanged: (value) => setState(() => exerciseType = value!),
                items: ExerciseType.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
              ),
              // Dropdown to select workout location type
              DropdownButton<WorkoutLocationType>(
                value: locationType,
                onChanged: (value) => setState(() => locationType = value!),
                items: WorkoutLocationType.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
              ),
              // Dropdown to select swimming location type
              DropdownButton<WorkoutSwimmingLocationType>(
                value: swimmingLocationType,
                onChanged: (value) =>
                    setState(() => swimmingLocationType = value!),
                items: WorkoutSwimmingLocationType.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
              ),
              // TextField to input lap length
              TextField(
                decoration: const InputDecoration(labelText: 'Lap length'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  try {
                    setState(() => lapLength = double.parse(value));
                  } catch (e) {
                    // If parsing fails, default to 25.0
                    debugPrint('Error parsing lapLength: $e');
                    setState(() => lapLength = 25.0);
                  }
                },
              ),
              // Button to start the Apple Watch app
              ElevatedButton(
                onPressed: start,
                child: const Text('Start Apple Watch app'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Starts the workout with the selected configuration.
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
      debugPrint('Error starting workout on iOS: $e');
      // Handle the error in UI or reset state if necessary
    }
  }
}
