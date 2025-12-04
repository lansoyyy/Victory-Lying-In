import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/auth/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: "AIzaSyAHLEmv94h9MqjUEpjL7ik0L_CrWPjCJIs",
          authDomain: "maternity-clinic.firebaseapp.com",
          projectId: "maternity-clinic",
          storageBucket: "maternity-clinic.firebasestorage.app",
          messagingSenderId: "412859194071",
          appId: "1:412859194071:web:fd17423ba677c322f42e92"));

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Victory Lying In - Maternity Clinic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE91E8C)),
        useMaterial3: true,
        fontFamily: 'Regular',
      ),
      home: const HomeScreen(),
    );
  }
}
