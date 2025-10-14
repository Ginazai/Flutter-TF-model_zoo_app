import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/connection_provider.dart';
import 'providers/collision_provider.dart';
import 'providers/ocr_provider.dart';
import 'providers/scene_provider.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // MultiProvider: registra todos los providers
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => CollisionProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => OCRProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => SceneDetectionProvider()..initialize()),
      ],
      child: MaterialApp(
        title: 'Asistente Visual',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: HomeScreen(),
      ),
    );
  }
}