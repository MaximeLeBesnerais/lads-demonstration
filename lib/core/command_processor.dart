import 'dart:async';
import 'package:lads/model/node.dart';
import 'package:lads/model/orchestrator.dart';
import 'package:lads/services/ai.dart';

// Result class for AI commands to carry structured data
class AiCommandResult {
  final String? message;
  final List<String>? instructions;
  final String answerType; // 'message' or 'instructions'

  AiCommandResult({
    required this.answerType,
    this.message,
    this.instructions,
  });
}


class CommandProcessor {
  final Orchestrator orchestrator;
  final GeminiService geminiService;
  // Define the System Prompt here as it's core to the AI interaction logic
  static const String systemPrompt = """
You are an assistant for a command-line orchestrator tool. You assist transforming natural language demands into custom machine specific commands.
Here are the available commands you can use:
--- AVAILABLE COMMANDS ---
help                     - Show this help message
set_api_key <key>        - Set the Gemini API Key for the current session
ai <instruction>         - Ask the AI to perform tasks (e.g., ai create a db server)
list / ls                - List all nodes and their status
queue                    - List tasks waiting in the queue
add_node <name> <cores> [class] - Add a new node (e.g., add_node MyNode 8 compute) // available classes: compute, database, backup, storage, network, generic
add_task <name> <secs> <cores> [class] - Add a task (e.g., add_task WebReq 5 1 compute) // available classes: compute, database, backup, storage, network, generic
process                  - Attempt to assign tasks from the queue to nodes
status <node_id_or_name> - Show detailed status of a specific node
active <node_id>         - Set node state to active
inactive <node_id>       - Set node state to inactive (waits for tasks)
maintain <node_id>       - Set node state to maintenance (waits for tasks)
decom <node_id>          - Set node state to decommissioned (waits for tasks)
remove <node_id> [force] - Remove a decommissioned node (or attempt decom first)
repurpose <node_id> <class> - Change class (e.g., repurpose XF34 database)
logs                     - Show all orchestrator logs
clearlogs                - Clear all orchestrator logs
exit                     - Exit the shell
--- END AVAILABLE COMMANDS ---
Node Classes: backup, compute, storage, network, database, generic

Based on the user's request and the available commands, generate a sequence of commands to achieve the goal.
Follow the response schema precisely.
Example response for "add a compute node named web1 with 4 cores":
{ "answer_type": "instructions", "instructions": ["add_node web1 4 compute"], "message": "Okay, adding compute node web1." }
Example response for "add a db node db1 with 8 cores then list nodes":
{ "answer_type": "instructions", "instructions": ["add_node db1 8 database", "list"], "message": null }
Example response for "what is a node?":
{ "answer_type": "message", "instructions": null, "message": "A node represents a virtual machine in the simulated environment that can run tasks." }


- Return *only* a valid JSON object matching the schema.
- Never return an empty instructions array if answer_type is "instructions". If no commands are applicable, use answer_type "message".
- You should always try to fulfill the request using the available commands, even if it requires multiple steps.
- Always be brief in your message answers.
- You can send messages to the user to: advise, inform about limitations, clarify conflicts, or ask direct questions.
- When user prepends their request with "f:", YOU MUST PROVIDE INSTRUCTIONS WITH NO MESSAGE (set message to null or omit it if possible within schema constraints).
- Otherwise, you can include a brief message.
- Your JSON response must be exactly as specified, with NO EMBEDDING SYMBOLS OR MARKDOWN.
""";


  CommandProcessor(this.orchestrator, this.geminiService);

  // --- Methods corresponding to CLI commands ---

  String getHelpText() {
    // This could potentially load from a config file in the future
    StringBuffer helpBuffer = StringBuffer();
    helpBuffer.writeln('\nAvailable Commands:');
    helpBuffer.writeln('  help                     - Show this help message');
    helpBuffer.writeln('  set_api_key <key>        - Set the Gemini API Key for the current session');
    helpBuffer.writeln('  ai <instruction>         - Ask the AI to perform tasks (e.g., ai create a db server)');
    helpBuffer.writeln('  list / ls                - List all nodes and their status');
    helpBuffer.writeln('  queue                    - List tasks waiting in the queue');
    helpBuffer.writeln('  add_node <name> <cores> [class] - Add a new node (e.g., add_node MyNode 8 compute)');
    helpBuffer.writeln('  add_task <name> <secs> <cores> [class] - Add a task (e.g., add_task WebReq 5 1 compute)');
    helpBuffer.writeln('  process                  - Attempt to assign tasks from the queue to nodes');
    helpBuffer.writeln('  status <node_id_or_name> - Show detailed status of a specific node');
    helpBuffer.writeln('  active <node_id>         - Set node state to active');
    helpBuffer.writeln('  inactive <node_id>       - Set node state to inactive (waits for tasks)');
    helpBuffer.writeln('  maintain <node_id>       - Set node state to maintenance (waits for tasks)');
    helpBuffer.writeln('  decom <node_id>          - Set node state to decommissioned (waits for tasks)');
    helpBuffer.writeln('  remove <node_id> [force] - Remove a decommissioned node (or attempt decom first)');
    helpBuffer.writeln('  repurpose <node_id> <class> - Change class (e.g., repurpose XF34 database)');
    helpBuffer.writeln('  logs                     - Show all orchestrator logs');
    helpBuffer.writeln('  clearlogs                - Clear all orchestrator logs');
    helpBuffer.writeln('  exit                     - Exit the shell');
    helpBuffer.writeln('\nNode Classes: ${NodeClass.values.map((e) => e.name).join(', ')}');
    return helpBuffer.toString();
  }

  String setApiKey(List<String> args) {
     if (args.isEmpty) {
       return 'Usage: set_api_key <your_gemini_api_key>';
     } else {
       geminiService.setApiKey(args[0]);
       return 'Gemini API Key has been set for this session.';
     }
  }

  List<Node> listNodes() {
    return orchestrator.nodes;
  }

  List<Task> listQueue() {
    return orchestrator.tasksQueue;
  }

  String addNode(List<String> args) {
    if (args.length < 2) {
      return 'Usage: add_node <name> <cpu_cores> [class]';
    }
    String name = args[0];
    int? cores = int.tryParse(args[1]);
    NodeClass nodeClass = NodeClass.generic; // Default
    String? warning;
    if (args.length > 2) {
      try {
        nodeClass = NodeClass.values.firstWhere(
            (e) => e.name == args[2].toLowerCase(),
            orElse: () => NodeClass.generic);
        if (nodeClass == NodeClass.generic && args[2].toLowerCase() != 'generic') {
          warning = 'Warning: Invalid node class "${args[2]}". Using generic.';
        }
      } catch (_) {
        warning = 'Error parsing node class: ${args[2]}. Using generic.';
        nodeClass = NodeClass.generic;
      }
    }
    if (cores == null || cores <= 0) {
      return 'Invalid CPU cores value.';
    }
    try {
        orchestrator.buildNode(name, cores, nodeClass: nodeClass);
        String result = 'Node "$name" ($nodeClass) added.';
        if (warning != null) {
            result += '\n$warning';
        }
        return result;
    } catch (e) {
        // Catch potential duplicate name error from orchestrator
        return 'Error adding node: $e';
    }
  }

   String addTask(List<String> args) {
     if (args.length < 3) {
       return 'Usage: add_task <name> <duration_seconds> <cpu_cores> [class]';
     }
     String taskName = args[0];
     int? duration = int.tryParse(args[1]);
     int? taskCores = int.tryParse(args[2]);
     NodeClass taskClass = NodeClass.generic; // Default
     String? warning;
     if (args.length > 3) {
       try {
         taskClass = NodeClass.values.firstWhere(
             (e) => e.name == args[3].toLowerCase(),
             orElse: () => NodeClass.generic);
         if (taskClass == NodeClass.generic && args[3].toLowerCase() != 'generic') {
           warning = 'Warning: Invalid task class "${args[3]}". Using generic.';
         }
       } catch (_) {
         warning = 'Error parsing task class: ${args[3]}. Using generic.';
         taskClass = NodeClass.generic;
       }
     }
     if (duration == null || duration < 0 || taskCores == null || taskCores <= 0) {
       return 'Invalid duration or CPU cores value.';
     }
     try {
        orchestrator.addTask(Task(taskName, Duration(seconds: duration), taskCores, taskClass: taskClass));
        String result = 'Task "$taskName" added to queue.';
         if (warning != null) {
            result += '\n$warning';
        }
        return result;
     } catch (e) {
         return 'Error adding task: $e';
     }
   }

   String processTasks() {
       orchestrator.processTasks();
       // Could return more detailed status from orchestrator logs if needed
       return 'Processing task queue requested.';
   }

   Node? getNodeStatus(String nodeIdOrName) {
       Node? node = orchestrator.findNodeById(nodeIdOrName.toUpperCase());
       node ??= orchestrator.findNodeByName(nodeIdOrName);
       return node; // Return the node object or null
   }

   Future<String> setNodeState(String command, List<String> args) async {
        if (args.isEmpty) { return 'Usage: $command <node_id>'; }

        NodeState targetState;
        switch (command) {
          case 'active': targetState = NodeState.active; break;
          case 'inactive': targetState = NodeState.inactive; break;
          case 'maintain': targetState = NodeState.maintenance; break;
          case 'decom': targetState = NodeState.decommissioned; break;
          default: return 'Internal error: Invalid state command';
        }

        String nodeId = args[0].toUpperCase();
        Node? node = orchestrator.findNodeById(nodeId);
        if (node == null) {
          return 'Node with ID "$nodeId" not found.';
        }

        // Orchestrator's setNodeState handles the async logic and logging
        await orchestrator.setNodeState(node.id, targetState);
        // We might want more detailed feedback, maybe from orchestrator logs
        return 'State change to ${targetState.name} requested for node ${node.name} ($nodeId). Check logs for details.';
   }

    Future<String> removeNode(List<String> args) async {
        if (args.isEmpty) { return 'Usage: remove <node_id> [force]'; }
        String nodeToRemoveId = args[0].toUpperCase();
        bool force = args.length > 1 && args[1].toLowerCase() == 'force';

        // Orchestrator's removeNode handles the logic and logging
        await orchestrator.removeNode(nodeToRemoveId, forceRemove: force);
        // Could check orchestrator logs for confirmation or errors
        return 'Removal requested for node $nodeToRemoveId. Check logs for details.';
    }

    String repurposeNode(List<String> args) {
        if (args.length < 2) { return 'Usage: repurpose <node_id> <new_class>'; }
        String repurposeNodeId = args[0].toUpperCase();
        NodeClass newClass;
        try {
            newClass = NodeClass.values.firstWhere(
                (e) => e.name == args[1].toLowerCase(),
                 orElse: () => throw FormatException("Invalid class name")
            );
        } catch (_) {
            return 'Invalid node class specified: ${args[1]}\nAvailable classes: ${NodeClass.values.map((e) => e.name).join(', ')}';
        }

        Node? node = orchestrator.findNodeById(repurposeNodeId);
         if (node == null) {
           return 'Node with ID "$repurposeNodeId" not found.';
         }

        orchestrator.repurposeNode(repurposeNodeId, newClass);
        return 'Repurpose request sent for node ${node.name} ($repurposeNodeId) to ${newClass.name}.';
    }

    List<String> getLogs() {
        return orchestrator.getAllLogs();
    }

    String clearLogs() {
        orchestrator.clearLogs();
        return 'Logs cleared.';
    }

   // --- AI Command Processing ---
   Future<AiCommandResult> processAiCommand(List<String> args) async {
        if (!geminiService.isApiKeySet()) {
          // Instead of throwing, return a specific result for the UI layer
           return AiCommandResult(answerType: 'message', message: 'AI API Key not set. Please use: set_api_key <your_key>');
        }
        if (args.isEmpty) {
          return AiCommandResult(answerType: 'message', message: 'Usage: ai <your instruction for the ai>');
        }

        String userInstruction = args.join(' ');

        try {
          Map<String, dynamic> aiResponse = await geminiService
              .generateStructuredContent(userInstruction, systemPrompt);

          String? answerType = aiResponse['answer_type'] as String?;
          List<dynamic>? instructionsDynamic = aiResponse['instructions'] as List<dynamic>?;
          String? message = aiResponse['message'] as String?;

          if (answerType == 'instructions') {
             List<String> suggestedCommands = instructionsDynamic
                    ?.map((item) => item.toString())
                    .where((item) => item.isNotEmpty) // Filter out empty strings
                    .toList() ?? [];
              if (suggestedCommands.isEmpty) {
                  return AiCommandResult(answerType: 'message', message: 'AI indicated instructions but provided none.');
              }
              return AiCommandResult(
                  answerType: 'instructions',
                  instructions: suggestedCommands,
                  message: message);
          } else if (answerType == 'message') {
              return AiCommandResult(
                  answerType: 'message',
                  message: message ?? "AI returned a message response with no content."); // Provide default if message is null
          } else {
              return AiCommandResult(answerType: 'message', message: 'Error: Unknown or missing answer_type from AI response.');
          }

        } catch (e) {
           // Return error as a message
           return AiCommandResult(answerType: 'message', message: 'Error interacting with AI service: $e');
        }
   }

}
