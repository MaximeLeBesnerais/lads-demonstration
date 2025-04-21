import 'dart:io';
import 'dart:async';
import 'package:lads/model/command_result.dart';
import 'package:lads/model/node.dart';
import 'package:lads/services/cli_service.dart';

// --- CLI REPL Entry Point ---
Future<void> runCliRepl(CliService cliService) async {
  print('\n--- Orchestrator CLI Mode ---');
  print('Type "help" for commands, "exit" to quit.');
  print('Use "set_api_key <your_key>" to set the AI API Key.');

  bool running = true;
  while (running) {
    await Future.delayed(Duration(milliseconds: 50)); // Prevent tight loop
    stdout.write('\n> ');
    String? input = stdin.readLineSync();

    if (input == null) {
      running = false; // EOF (Ctrl+D)
      print('\nExiting CLI mode.');
      continue;
    }

    String trimmedInput = input.trim();
    if (trimmedInput.isEmpty) continue;

    // Handle exit command directly in the loop
    if (trimmedInput.toLowerCase() == 'exit') {
      running = false;
      print('Exiting CLI mode.');
      continue;
    }

    // Process command via the service and print results using the CLI helper
    await _processCliResult(cliService, cliService.processCommand(trimmedInput));
  }
}

// --- CLI Specific Result Processing and Printing ---
// Takes CliService now to handle recursive calls for AI commands
Future<void> _processCliResult(CliService cliService, Future<CommandResult> futureResult) async {
  try {
    CommandResult result = await futureResult;

    switch (result.type) {
      case CommandResultType.nodeList:
        _printNodes(result.data as List<Node>);
        break;
      case CommandResultType.taskList:
        _printQueue(result.data as List<Task>);
        break;
      case CommandResultType.nodeStatus:
        final statusData = result.data as Map<String, dynamic>;
        _printNodeStatus(statusData['node'] as Node?, statusData['identifier'] as String);
        break;
      case CommandResultType.logList:
        _printLogs(result.data as List<String>);
        break;
      case CommandResultType.aiResponse:
        final aiResult = result.data as AiCommandResult;
        if (aiResult.message != null && aiResult.message!.isNotEmpty) {
          print('AI Message: ${aiResult.message}');
        }
        if (aiResult.answerType == 'instructions' &&
            aiResult.instructions != null &&
            aiResult.instructions!.isNotEmpty) {
          print('AI Suggested Commands:');
          for (var cmd in aiResult.instructions!) {
            print('  - $cmd');
          }
          stdout.write('Execute these commands? (yes/no): ');
          String? confirmation = stdin.readLineSync()?.toLowerCase();
          if (confirmation == 'yes' || confirmation == 'y') {
            print('Executing AI suggested commands...');
            for (String cmdToExecute in aiResult.instructions!) {
              print('\nExecuting: $cmdToExecute');
              // Process subsequent commands using the service via this helper
              await _processCliResult(cliService, cliService.processCommand(cmdToExecute));
              await Future.delayed(Duration(milliseconds: 200));
            }
            print('Finished executing AI suggested commands.');
          } else {
            print('Execution cancelled.');
          }
        } else if (aiResult.answerType == 'message') {
            // Message handled above or by processor
        } else {
             print(aiResult.message ?? 'AI returned an unknown response type without a message.');
        }
        break;
      case CommandResultType.simpleMessage:
        // Only print if data is not null or empty
        if (result.data != null && (result.data as String).isNotEmpty) {
             print(result.data as String);
        }
        break;
      case CommandResultType.error:
        print('Error: ${result.errorMessage}');
        break;
    }
  } catch (e, stacktrace) {
    print('An unexpected error occurred while processing the command result: $e');
    print('Stacktrace:\n$stacktrace');
  }
}


// --- CLI Specific Helper Functions for Printing ---
// (Identical to the ones previously in main.dart)

void _printNodes(List<Node> nodes) {
  print('\n--- Nodes (${nodes.length}) ---');
  if (nodes.isEmpty) { print('No nodes found.'); return; }
  print('ID   | Name           | State         | Class      | CPU Busy/Total | Tasks (# / Details)');
  print('-----|----------------|---------------|------------|----------------|-------------------');
  for (var node in nodes) {
    String id = node.id.padRight(4);
    String name = node.name.padRight(14).substring(0, 14);
    String state = node.nodeState.name.padRight(13);
    String nodeClass = node.nodeClass.name.padRight(10);
    String cpu = '${node.busyCores}/${node.cpuCores}'.padRight(14);
    String taskInfo = node.tasks.isEmpty ? '0' : '${node.tasks.length} [${node.tasks.map((t) => t.toString()).join(', ')}]';
    print('$id | $name | $state | $nodeClass | $cpu | $taskInfo');
  }
  print('-----|----------------|---------------|------------|----------------|-------------------');
}

void _printQueue(List<Task> queue) {
  print('\n--- Task Queue (${queue.length}) ---');
  if (queue.isEmpty) { print('Queue is empty.'); return; }
  print('Name                 | Initial Duration | Cores | Class');
  print('---------------------|------------------|-------|------------');
  for (var task in queue) {
    String name = task.name.padRight(20).substring(0, 20);
    String duration = '${task.initialTaskLength.inSeconds}s'.padRight(16);
    String cores = task.cpuCores.toString().padRight(5);
    String taskClass = task.taskClass.name;
    print('$name | $duration | $cores | $taskClass');
  }
  print('---------------------|------------------|-------|------------');
}

void _printNodeStatus(Node? node, String identifier) {
  if (node == null) { print('Node with ID or Name "$identifier" not found.'); return; }
  print('\n--- Status for Node ${node.name} (ID: ${node.id}) ---');
  print('  State: ${node.nodeState.name}');
  print('  Class: ${node.nodeClass.name}');
  print('  CPU Cores: ${node.cpuCores}');
  print('  Busy Cores: ${node.busyCores}');
  print('  Available Cores: ${node.availableCores}');
  print('  Tasks Running: ${node.tasks.length}');
  if (node.tasks.isNotEmpty) {
    print('  Tasks:');
    for (var task in node.tasks) {
      print('    - ${task.toString()} (Cores: ${task.cpuCores}, Class: ${task.taskClass.name})');
    }
  }
}

void _printLogs(List<String> logs) {
  print('\n--- Orchestrator Logs ---');
  if (logs.isEmpty) { print('No logs available.'); return; }
  logs.forEach(print);
  print('--- End of Logs ---');
}
