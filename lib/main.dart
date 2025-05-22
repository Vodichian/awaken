import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart';
import 'models/computer.dart';
import 'screens/computer_list_screen.dart';
import 'package:wakeup/hive/hive_registrar.g.dart';
import 'package:logger/logger.dart';

var logger = Logger(printer: PrettyPrinter());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Set the initial window size and position (optional)
    setWindowFrame(
      const Rect.fromLTWH(100, 100, 800, 600),
    ); // x, y, width, height

    setWindowMinSize(const Size(400, 300));
    setWindowMaxSize(const Size(1200, 900));
  }
  await Hive.initFlutter();

  Hive.registerAdapters();

  final computerBox = await Hive.openBox<Computer>('computerBox');
  final settingsBox = await Hive.openBox('settingsBox');

  runApp(
    MultiProvider( // Use MultiProvider
      providers: [
        Provider<Box<Computer>>.value( // Provide the computerBox
          value: computerBox,
        ),
        Provider<Box<dynamic>>.value( // Provide the settingsBox
          value: settingsBox,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Awaken',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ComputerListScreen(), // Set your computer list screen as
      // home
    );
  }
}
