class AiCommandResult {
  final String? message;
  final List<String>? instructions;
  final String answerType;

  AiCommandResult({
    required this.answerType,
    this.message,
    this.instructions,
  });
}

enum CommandResultType {
  nodeList,
  taskList,
  nodeStatus,
  logList,
  aiResponse,
  simpleMessage,
  error
}

class CommandResult {
  final CommandResultType type;
  final dynamic data;
  final String? errorMessage;

  CommandResult({required this.type, this.data, this.errorMessage});

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
