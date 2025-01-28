import 'dart:io';
import 'dart:async'; // Importante para las suscripciones de los Streams
import 'package:flutter/material.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:workout/workout.dart';
import 'package:heart_rate_flutter/heart_rate_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart'; // <-- Import de sensors_plus

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

  /// Variable que se mostrará en pantalla para la frecuencia cardíaca (plugin heart_rate_flutter)
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

  // Variables para almacenar la lectura de los sensores
  double accX = 0, accY = 0, accZ = 0;
  double gyrX = 0, gyrY = 0, gyrZ = 0;
  double magX = 0, magY = 0, magZ = 0;

  // Suscripciones a los streams
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

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

    /// Suscribirnos a los sensores (con manejo de excepciones)
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
      debugPrint('Error suscribiendo al acelerómetro: $e');
    }

    try {
      _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
        setState(() {
          gyrX = event.x;
          gyrY = event.y;
          gyrZ = event.z;
        });
      });
    } catch (e) {
      debugPrint('Error suscribiendo al giroscopio: $e');
    }

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
      debugPrint('Error suscribiendo al magnetómetro: $e');
    }
  }

  @override
  void dispose() {
    // Cancelamos las suscripciones para evitar fugas de memoria
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
                  // Frecuencia cardíaca desde heart_rate_flutter
                  Text('Heart rate value (plugin): $heartBeatValue'),
                  // Frecuencia cardíaca desde Workout
                  Text('Heart rate (Workout API): $heartRate'),
                  Text('Calories: ${calories.toStringAsFixed(2)}'),
                  Text('Steps: $steps'),
                  Text('Distance: ${distance.toStringAsFixed(2)}'),
                  Text('Speed: ${speed.toStringAsFixed(2)}'),
                  const Divider(),
                  // Lectura de Acelerómetro
                  Text('Acelerómetro:'),
                  Text('   X: ${accX.toStringAsFixed(2)}'),
                  Text('   Y: ${accY.toStringAsFixed(2)}'),
                  Text('   Z: ${accZ.toStringAsFixed(2)}'),
                  const Divider(),
                  // Lectura de Giroscopio
                  Text('Giroscopio:'),
                  Text('   X: ${gyrX.toStringAsFixed(2)}'),
                  Text('   Y: ${gyrY.toStringAsFixed(2)}'),
                  Text('   Z: ${gyrZ.toStringAsFixed(2)}'),
                  const Divider(),
                  // Lectura de Magnetómetro
                  Text('Magnetómetro:'),
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

  void toggleExerciseState() async {
    if (started) {
      await workout.stop();
    } else {
      try {
        final supportedExerciseTypes = await workout.getSupportedExerciseTypes();
        debugPrint('Supported exercise types: ${supportedExerciseTypes.length}');

        final result = await workout.start(
          exerciseType: exerciseType,
          features: features,
          enableGps: enableGps,
        );

        if (result.unsupportedFeatures.isNotEmpty) {
          debugPrint('Unsupported features: ${result.unsupportedFeatures}');
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
