import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/screens/tour_list_screen.dart';
import 'database/database_helper.dart'; // Ensure this path is correct

void main() async {
  // Required for plugins like sqflite before runApp
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize database (optional here, can be lazy loaded)
  await DatabaseHelper.instance.database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Provider for simple state management / dependency injection
    return ChangeNotifierProvider(
      create: (context) => TourProvider(),
      child: MaterialApp(
        title: 'Tour Expense Tracker',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true, // Optional: Use Material 3 design
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 10.0,
            ),
          ),
          cardTheme: CardTheme(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        home: const TourListScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
