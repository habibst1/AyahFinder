import 'package:flutter/material.dart';
import 'screens/audio_recorder_screen.dart';

void main() {
  runApp(MaterialApp(
    home: AudioRecorderScreen(),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.teal,
      fontFamily: 'Tajawal',
      textTheme: TextTheme(
        titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(fontSize: 16.0),
      ),
    ),
  ));
}