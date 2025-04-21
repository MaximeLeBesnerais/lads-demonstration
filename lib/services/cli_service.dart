import 'dart:async';
import 'package:lads/model/command_result.dart';
import '../core/command_processor.dart';
import '../model/node.dart';

class CliService {
  final CommandProcessor commandProcessor;

  CliService(this.commandProcessor);

  /// Processes a raw command line string and returns a structured result.
  /// This method encapsulates the command dispatch logic.
  Future<CommandResult> processCommand(String commandLine) async {
    List<String> parts = commandLine.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) {
      return CommandResult.error("Empty command received.");
    }
    String command = parts[0].toLowerCase();
    List<String> args = parts.length > 1 ? parts.sublist(1) : [];

    try {
      switch (command) {
        case 'help':
          return CommandResult.message(commandProcessor.getHelpText());

        case 'set_api_key':
          return CommandResult.message(commandProcessor.setApiKey(args));

        case 'ai':
          // The processor now returns AiCommandResult directly
          AiCommandResult aiResult = await commandProcessor.processAiCommand(args);
          // Wrap it in the generic CommandResult for the UI/CLI layer
          return CommandResult.ai(aiResult);

        case 'list':
        case 'ls':
          final nodes = commandProcessor.listNodes();
          return CommandResult.success(CommandResultType.nodeList, nodes);

        case 'queue':
          final tasks = commandProcessor.listQueue();
          return CommandResult.success(CommandResultType.taskList, tasks);

        case 'add_node':
          final message = commandProcessor.addNode(args);
          // Check if the message indicates an error (simple check for now)
          if (message.toLowerCase().startsWith('error') || message.toLowerCase().startsWith('invalid')) {
               return CommandResult.error(message);
          }
          return CommandResult.message(message);

        case 'add_task':
           final message = commandProcessor.addTask(args);
           if (message.toLowerCase().startsWith('error') || message.toLowerCase().startsWith('invalid')) {
               return CommandResult.error(message);
           }
           return CommandResult.message(message);

        case 'process':
          return CommandResult.message(commandProcessor.processTasks());

        case 'status':
          if (args.isEmpty) {
            return CommandResult.error('Usage: status <node_id_or_name>');
          }
          Node? node = commandProcessor.getNodeStatus(args[0]);
          // Return node data or null if not found (let UI handle null display)
          return CommandResult.success(CommandResultType.nodeStatus, {'node': node, 'identifier': args[0]});


        case 'active':
        case 'inactive':
        case 'maintain':
        case 'decom':
          final message = await commandProcessor.setNodeState(command, args);
           if (message.toLowerCase().contains('not found')) {
               return CommandResult.error(message);
           }
          return CommandResult.message(message);

        case 'remove':
           final message = await commandProcessor.removeNode(args);
            if (message.toLowerCase().contains('not found')) { // Basic error check
               return CommandResult.error(message);
           }
           return CommandResult.message(message);

        case 'repurpose':
           final message = commandProcessor.repurposeNode(args);
            if (message.toLowerCase().startsWith('invalid') || message.toLowerCase().contains('not found')) {
               return CommandResult.error(message);
           }
           return CommandResult.message(message);

        case 'logs':
          final logs = commandProcessor.getLogs();
          return CommandResult.success(CommandResultType.logList, logs);

        case 'clearlogs':
          return CommandResult.message(commandProcessor.clearLogs());

        case 'exit':
             // This command is usually handled by the shell loop itself,
             // but we can return a specific type if needed.
             // Returning an error might be misleading. Let's return a message.
             return CommandResult.message("Exit command recognized.");


        default:
          return CommandResult.error('Unknown command: "$command". Type "help" for options.');
      }
    } catch (e, stacktrace) {
      // Catch unexpected errors during command processing
      print('Internal error processing command "$commandLine": $e');
      print('Stacktrace:\n$stacktrace');
      return CommandResult.error('An internal error occurred: $e');
    }
  }
}
