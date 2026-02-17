import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'signup_page.dart'; // This imports your signup file

void main() async {
  // This line fixes the 'WidgetsFlutterBinding' error
  WidgetsFlutterBinding.ensureInitialized();
  
  // This line fixes the 'Firebase' error
  await Firebase.initializeApp();
  
  // This line fixes the 'runApp' error
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crop Advisory System',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      // This tells the app to start on the Signup Page
      home: SignupPage(), 
    );
  }
}