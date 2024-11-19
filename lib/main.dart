import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:open_file/open_file.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GPSLogger(),
    );
  }
}

class GPSLogger extends StatefulWidget {
  @override
  _GPSLoggerState createState() => _GPSLoggerState();
}

class _GPSLoggerState extends State<GPSLogger> {
  Timer? _timer;
  List<List<dynamic>> _gpsData = [["Marca de tiempo", "Latitud", "Longitud"]];
  String? _filePath;

  // Variables para mostrar coordenadas en pantalla
  String _latitude = "Cargando...";
  String _longitude = "Cargando...";

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPermission = await Geolocator.checkPermission();
    if (hasPermission == LocationPermission.denied ||
        hasPermission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
    _startLogging();
  }

  void _startLogging() async {
    _filePath = await _initCsvFile();
    _timer = Timer.periodic(Duration(seconds: 5), (_) async {
      final position = await _getCurrentLocation();
      if (position != null) {
        final timestamp = DateTime.now().toIso8601String();
        setState(() {
          _gpsData.add([timestamp, position.latitude, position.longitude]);
          _latitude = position.latitude.toString();
          _longitude = position.longitude.toString();
        });
        _writeToCsv(timestamp, position.latitude, position.longitude);
      }
    });
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print("Error al obtener la ubicación: $e");
      return null;
    }
  }

  Future<String> _initCsvFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/gps_log.csv';
    final file = File(filePath);
    if (!await file.exists()) {
      await file.writeAsString(const ListToCsvConverter().convert(_gpsData));
    }
    return filePath;
  }

  void _writeToCsv(String timestamp, double latitude, double longitude) async {
    if (_filePath == null) return;
    final file = File(_filePath!);
    final csvLine = ListToCsvConverter().convert([
      [timestamp, latitude, longitude]
    ]);
    await file.writeAsString('$csvLine\n', mode: FileMode.append);
  }

  void _openCsvFile() {
    if (_filePath != null) {
      OpenFile.open(_filePath!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La ruta del archivo CSV no está disponible')),
      );
    }
  }

  Future<void> _deleteAndResetCsvFile() async {
    if (_filePath != null) {
      final file = File(_filePath!);
      if (await file.exists()) {
        await file.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archivo CSV eliminado exitosamente')),
        );
      }
      // Regenerate a new CSV file
      setState(() {
        _gpsData = [["Marca de tiempo", "Latitud", "Longitud"]]; // Reset data
      });
      _filePath = await _initCsvFile();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo CSV recreado con éxito')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se encontró ningún archivo CSV para eliminar')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Registrador GPS"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Registrador GPS",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              "Ubicación actual:",
              style: TextStyle(fontSize: 18),
            ),
            Text(
              "Latitud: $_latitude",
              style: TextStyle(fontSize: 16),
            ),
            Text(
              "Longitud: $_longitude",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_filePath != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Archivo guardado en $_filePath')),
                  );
                }
              },
              child: Text("Mostrar ruta del archivo"),
            ),
            ElevatedButton(
              onPressed: _openCsvFile,
              child: Text("Abrir archivo CSV"),
            ),
            ElevatedButton(
              onPressed: _deleteAndResetCsvFile,
              child: Text("Eliminar y restablecer CSV"),
            ),
          ],
        ),
      ),
    );
  }
}
