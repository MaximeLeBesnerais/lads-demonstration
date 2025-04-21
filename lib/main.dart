import 'package:flutter/material.dart';
import 'package:lads/ui/providers/orchestrator_provider.dart';
import 'package:lads/ui/screens/home_screen.dart';
import 'package:provider/provider.dart';

void main() {
  // No need to instantiate Orchestrator etc. here for the UI,
  // the provider will handle the singleton.

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap the entire app with ChangeNotifierProvider
    return ChangeNotifierProvider(
      create: (context) => OrchestratorProvider(),
      child: MaterialApp(
        title: 'Orchestrator HUD',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark, // Use a dark theme for HUD style
          ),
          useMaterial3: true,
          // Define a slightly more HUD-like font if desired
          // fontFamily: 'YourMonospaceFont', // e.g., Roboto Mono
        ),
        debugShowCheckedModeBanner: false, // Hide debug banner
        home: const HomeScreen(), // Start with the new HomeScreen
      ),
    );
  }
}

// Removed the old MyHomePage StatefulWidget as it's replaced by HomeScreen
