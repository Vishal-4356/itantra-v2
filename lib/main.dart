import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'presentation/transceiver_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ITantraApp());
}

class ITantraApp extends StatelessWidget {
  const ITantraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iTantra Transceiver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6ECE3),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF5A3E36),
          secondary: Color(0xFF8C5E52),
          error: Color(0xFFC84B4B),
          surface: Color(0xFFF6ECE3),
        ),
        fontFamily: 'Roboto',
      ),
      home: const TransceiverScreen(),
    );
  }
}
