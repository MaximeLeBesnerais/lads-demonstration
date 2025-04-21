import 'dart:io'; // Required for exit()
import 'dart:async';

// Adjust package name if different (e.g., package:lads/...)
import 'package:lads/model/orchestrator.dart';
import 'package:lads/services/ai.dart';
import 'package:lads/core/command_processor.dart';
import 'package:lads/services/cli_service.dart';
import 'package:lads/entry/repl.dart'; // Import the REPL runner function

// --- Instantiate Core Services ---
// These instances are specific to the CLI process
final orchestrator = Orchestrator();
final geminiService = GeminiService();
final commandProcessor = CommandProcessor(orchestrator, geminiService);
final cliService = CliService(commandProcessor);

// --- Main Entry Point for CLI ---
// This main function now directly starts the REPL after setup.
Future<void> main(List<String> arguments) async {
  // Arguments are currently ignored, but kept for potential future CLI options

  print('Initializing orchestrator backend for CLI...');
  try {
    // Perform setup using the service. Errors will be printed by the service/processor.
    // Using await here ensures setup completes before REPL starts.
    await cliService.processCommand('add_node WebServer-A 4 compute');
    await cliService.processCommand('add_node DBServer-A 8 database');
    await cliService.processCommand('add_node BackupSrv 2 backup');
    await cliService.processCommand('add_task "Sample Web Request" 15 1 compute');
    await cliService.processCommand('process');
    print('Initial setup complete.');
  } catch (e) {
    print('Critical error during initial setup: $e');
    exit(1); // Exit if setup fails
  }

  // --- Start the REPL ---
  // Pass the CliService instance to the REPL function and wait for it to complete.
  await runCliRepl(cliService);

  // Exit explicitly when the REPL loop finishes.
  exit(0);
}
