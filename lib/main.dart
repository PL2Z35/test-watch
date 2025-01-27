import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:workout/workout.dart';

// 1. Import permission_handler
import 'package:permission_handler/permission_handler.dart';

void main() {
  // Check the platform: if it's iOS, run MyIosApp; otherwise, run MyApp.
  runApp(Platform.isIOS ? const MyIosApp() : const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final workout = Workout();

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

  _MyAppState() {
    // Listen to the workout stream to receive sensor updates
    workout.stream.listen((event) {
      debugPrint('${event.feature}: ${event.value} (${event.timestamp})');

      switch (event.feature) {
        case WorkoutFeature.unknown:
          return;
        case WorkoutFeature.heartRate:
          setState(() {
            heartRate = event.value;
          });
        case WorkoutFeature.calories:
          setState(() {
            calories = event.value;
          });
        case WorkoutFeature.steps:
          setState(() {
            steps = event.value;
          });
        case WorkoutFeature.distance:
          setState(() {
            distance = event.value;
          });
        case WorkoutFeature.speed:
          setState(() {
            speed = event.value;
          });
      }
    });
  }

  // 2. Define a method to request permissions
  Future<bool> _requestPermissions() async {
    // For body sensors (heart rate):
    if (await Permission.sensors.request().isDenied) {
      // If user denies, return false
      return false;
    }

    // For activity recognition (steps, etc.)
    if (await Permission.activityRecognition.request().isDenied) {
      return false;
    }

    // For GPS tracking (distance, speed), you need location:
    if (await Permission.locationWhenInUse.request().isDenied) {
      return false;
    }

    // If you need background location, uncomment this and ensure
    // you handle background location usage in your app.
//    if (await Permission.locationAlways.request().isDenied) {
//      return false;
//    }

    // If all requested permissions are granted, return true
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      // Use AmbientMode on Wear OS to keep the screen active in a low-power state
      home: AmbientMode(
        builder: (context, mode, child) => child!,
        child: Scaffold(
          body: Center(
            child: Column(
              children: [
                const Spacer(),
                Text('Heart rate: $heartRate'),
                Text('Calories: ${calories.toStringAsFixed(2)}'),
                Text('Steps: $steps'),
                Text('Distance: ${distance.toStringAsFixed(2)}'),
                Text('Speed: ${speed.toStringAsFixed(2)}'),
                const Spacer(),
                TextButton(
                  onPressed: toggleExerciseState,
                  child: Text(started ? 'Stop' : 'Start'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void toggleExerciseState() async {
    if (started) {
      // If workout is started, stop it
      await workout.stop();
      setState(() => started = false);
    } else {
      // If not started, first check permissions
      final granted = await _requestPermissions();
      if (!granted) {
        debugPrint('Permissions not granted. Cannot start workout.');
        return;
      }

      // Get the list of supported exercise types (not strictly necessary, but useful)
      final supportedExerciseTypes = await workout.getSupportedExerciseTypes();
      debugPrint('Supported exercise types: ${supportedExerciseTypes.length}');

      // Start workout with your chosen exercise type and features
      final result = await workout.start(
        exerciseType: exerciseType,
        features: features,
        enableGps: enableGps,
      );

      // If any requested features are unsupported, handle accordingly
      if (result.unsupportedFeatures.isNotEmpty) {
        debugPrint('Unsupported features: ${result.unsupportedFeatures}');
      } else {
        debugPrint('All requested features are supported');
      }

      setState(() => started = true);
    }
  }
}

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
              DropdownButton<ExerciseType>(
                value: exerciseType,
                onChanged: (value) => setState(() => exerciseType = value!),
                items: ExerciseType.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
              ),
              DropdownButton<WorkoutLocationType>(
                value: locationType,
                onChanged: (value) => setState(() => locationType = value!),
                items: WorkoutLocationType.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
              ),
              DropdownButton<WorkoutSwimmingLocationType>(
                value: swimmingLocationType,
                onChanged: (value) =>
                    setState(() => swimmingLocationType = value!),
                items: WorkoutSwimmingLocationType.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Lap length'),
                keyboardType: TextInputType.number,
                onChanged: (value) =>
                    setState(() => lapLength = double.parse(value)),
              ),
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

  void start() {
    workout.start(
      exerciseType: exerciseType,
      features: [],
      locationType: locationType,
      swimmingLocationType: swimmingLocationType,
      lapLength: lapLength,
    );
  }
}
