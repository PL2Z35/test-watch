import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:workout/workout.dart';
import 'package:heart_rate_flutter/heart_rate_flutter.dart';

void main() {
  runApp(Platform.isIOS ? const MyIosApp() : const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final workout = Workout();
  final HeartRateFlutter _heartRateFlutterPlugin = HeartRateFlutter();

  /// Variable que se mostrará en pantalla para la frecuencia cardíaca
  var heartBeatValue = 0;
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
    /// Escuchamos el stream principal de `workout` con manejo de error
    workout.stream.listen(
          (event) {
        try {
          debugPrint('${event.feature}: ${event.value} (${event.timestamp})');
          switch (event.feature) {
            case WorkoutFeature.unknown:
            // No hacemos nada especial
              break;
            case WorkoutFeature.heartRate:
              setState(() {
                // Si event.value fuera nulo, usamos 0 por defecto
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
          // Ante cualquier excepción, ponemos valores en cero
          debugPrint('Error en el stream de workout: $e');
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
        debugPrint('Error en stream.listen: $error');
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

    /// Inicializa el plugin para la lectura de ritmo cardíaco
    _heartRateFlutterPlugin.init();

    /// Suscripción al stream de lectura de ritmo cardíaco con manejo de error
    _heartRateFlutterPlugin.heartBeatStream.listen(
          (double? event) {
        if (mounted) {
          setState(() {
            /// Convertimos el valor double a int y si es nulo usamos 0
            heartBeatValue = (event ?? 0).toInt();
          });
        }
      },
      onError: (error) {
        debugPrint('Error en heartBeatStream: $error');
        if (mounted) {
          setState(() {
            heartBeatValue = 0;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: AmbientMode(
        builder: (context, mode, child) => child!,
        child: Scaffold(
          body: Center(
            child: Column(
              children: [
                const Spacer(),
                /// Aquí se refleja el valor de `heartBeatValue` proveniente del plugin
                Text('Heart rate value: $heartBeatValue'),
                Text('Heart rate (Workout API): $heartRate'),
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
      await workout.stop();
    } else {
      try {
        final supportedExerciseTypes = await workout.getSupportedExerciseTypes();
        debugPrint('Supported exercise types: ${supportedExerciseTypes.length}');

        final result = await workout.start(
          // En una app real, revisa primero los tipos de ejercicio compatibles
          exerciseType: exerciseType,
          features: features,
          enableGps: enableGps,
        );

        if (result.unsupportedFeatures.isNotEmpty) {
          debugPrint('Unsupported features: ${result.unsupportedFeatures}');
          // Maneja en la UI si lo deseas
        } else {
          debugPrint('All requested features supported');
        }
      } catch (e) {
        debugPrint('Error al iniciar el workout: $e');
        // Ponemos valores por defecto en caso de error
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
                onChanged: (value) {
                  try {
                    setState(() => lapLength = double.parse(value));
                  } catch (e) {
                    // Si ocurre algún error, dejamos lapLength en 25.0 por defecto
                    debugPrint('Error parseando lapLength: $e');
                    setState(() => lapLength = 25.0);
                  }
                },
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
    try {
      workout.start(
        exerciseType: exerciseType,
        features: [],
        locationType: locationType,
        swimmingLocationType: swimmingLocationType,
        lapLength: lapLength,
      );
    } catch (e) {
      debugPrint('Error al iniciar el workout en iOS: $e');
      // Manejar en UI o restablecer estado si fuera necesario
    }
  }
}
