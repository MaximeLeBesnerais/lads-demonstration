import '../core/command_processor.dart';

enum CommandResultType {
  nodeList,
  taskList,
  nodeStatus,
  logList,
  aiResponse, // Contains AiCommandResult
  simpleMessage,
  error
}

class CommandResult {
  final CommandResultType type;
  final dynamic data; // Can be List<Node>, List<Task>, Node?, List<String>, AiCommandResult, String
  final String? errorMessage; // Used when type is error

  CommandResult({required this.type, this.data, this.errorMessage});

  // Factory constructor for convenience
  factory CommandResult.success(CommandResultType type, dynamic data) {
    return CommandResult(type: type, data: data);
  }

  factory CommandResult.message(String message) {
    return CommandResult(type: CommandResultType.simpleMessage, data: message);
  }

   factory CommandResult.ai(AiCommandResult aiData) {
     return CommandResult(type: CommandResultType.aiResponse, data: aiData);
   }

  factory CommandResult.error(String message) {
    return CommandResult(type: CommandResultType.error, errorMessage: message);
  }
}