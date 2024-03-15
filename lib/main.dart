import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'posts.dart';
import 'auth_screen.dart';
import 'user_provider.dart'; // Import your UserProvider
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "AIzaSyAVeabVGSO5Ru1u5MBccbZ03Onpul5_16Y",
        authDomain: "nexyket.firebaseapp.com",
        databaseURL: "https://nexyket-default-rtdb.firebaseio.com",
        projectId: "nexyket",
        storageBucket: "nexyket.appspot.com",
        messagingSenderId: "398223201089",
        appId: "1:398223201089:web:233e87df3e2755c80607c0",
        measurementId: "G-TE9RNY1NTL"
    ),
  );
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProvider(), // Use only UserProvider
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home:  WelcomeScreen(),
    );
  }
}
