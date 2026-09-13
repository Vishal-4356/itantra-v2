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
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0284C7),
          secondary: Color(0xFF059669),
          error: Color(0xFFDC2626),
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: const TransceiverScreen(),
    );
  }
}
