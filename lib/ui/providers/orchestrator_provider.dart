import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lads/model/node.dart';
import 'package:lads/model/orchestrator.dart';
import 'package:lads/model/command_result.dart'; // Import CommandResult & AiCommandResult
import 'package:lads/core/command_processor.dart'; // Import CommandProcessor
import 'package:lads/services/ai.dart'; // Import GeminiService
// Consider using flutter_secure_storage for API key persistence

/// ChangeNotifier provider for the Orchestrator, AI, and Settings.
class OrchestratorProvider with ChangeNotifier {
  // Core Orchestrator
  final Orchestrator _orchestrator = Orchestrator();
  Timer? _refreshTimer; // For non-AI UI updates

  // AI & Settings Integration
  // Instantiate AI Service and Command Processor here
  final GeminiService _geminiService = GeminiService();
  late final CommandProcessor _commandProcessor;

  // API Key State
  String? _apiKey;
  bool _isApiKeyValid = false;

  // AI Interaction State
  AiCommandResult? _lastAiResult;
  bool _isAiProcessing = false; // True while talking to AI OR executing commands
  String? _aiError;
  List<String> _executedAiCommandsFeedback = [];
  bool _isAiConfirmationPending = false; // True when waiting for user accept/reject

  OrchestratorProvider() {
    // Initialize CommandProcessor with the orchestrator and AI service
    _commandProcessor = CommandProcessor(_orchestrator, _geminiService);

    // TODO: Load API key from secure storage on startup if implemented

    // Timer for general UI refresh (e.g., task progress)
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Avoid notifying if only AI state changed, as AI screen handles that explicitly
      if (hasListeners) {
         // Basic check to avoid unnecessary refreshes during AI ops
         if (!_isAiProcessing && !_isAiConfirmationPending) {
             notifyListeners();
         }
      }
    });
    // Don't notify initially, let widgets build first
  }

  // --- Getters ---
  List<Node> get nodes => _orchestrator.nodes;
  List<Task> get tasksQueue => _orchestrator.tasksQueue;
  List<String> get logs => _orchestrator.getAllLogs(); // Orchestrator logs

  // AI & Settings Getters
  String? get apiKey => _apiKey;
  bool get isApiKeySet => _isApiKeyValid;
  AiCommandResult? get lastAiResult => _lastAiResult;
  bool get isAiProcessing => _isAiProcessing; // Use this to disable input
  String? get aiError => _aiError;
  List<String> get executedAiCommandsFeedback => List.unmodifiable(_executedAiCommandsFeedback); // Return unmodifiable list
  bool get isAiConfirmationPending => _isAiConfirmationPending; // Use this to show confirm/reject


  // --- Methods ---

  // --- API Key Management ---
  Future<void> setApiKey(String key) async {
    _apiKey = key.trim(); // Trim whitespace
    if (_apiKey != null && _apiKey!.isNotEmpty) {
        try {
          // Set key in the service
          _geminiService.setApiKey(_apiKey!);
          _isApiKeyValid = true;
          _aiError = null; // Clear previous API key errors
          print("API Key set and validated in provider.");
          // TODO: Persist the key securely if implemented
        } catch (e) {
           // Catch potential errors during API key setting/validation if any
           print("Error setting API Key in service: $e");
           _isApiKeyValid = false;
           _aiError = "Failed to validate API Key: $e";
        }
    } else {
        _apiKey = null; // Ensure empty key is treated as null
        _isApiKeyValid = false;
        print("API Key cleared in provider.");
    }
    notifyListeners(); // Notify UI about API key status change
  }

  // --- AI Interaction ---
  Future<void> processAiCommand(String userInstruction) async {
    if (!_isApiKeyValid) {
      _aiError = 'API Key not set or invalid. Please set it first.';
      _lastAiResult = null;
      _isAiConfirmationPending = false;
      notifyListeners();
      return;
    }
    if (userInstruction.trim().isEmpty) {
       _aiError = 'Please enter an instruction for the AI.';
       notifyListeners();
       return;
    }

    _isAiProcessing = true; // Start processing
    _aiError = null;
    _lastAiResult = null;
    _executedAiCommandsFeedback.clear();
    _isAiConfirmationPending = false;
    notifyListeners(); // Update UI to show loading/disable input

    try {
      _lastAiResult = await _commandProcessor.processAiCommand(userInstruction.split(' '));
      // Check if confirmation is needed
      if (_lastAiResult?.answerType == 'instructions' &&
          _lastAiResult?.instructions != null &&
          _lastAiResult!.instructions!.isNotEmpty) {
         _isAiConfirmationPending = true;
         // Keep _isAiProcessing = true while confirmation is pending
      } else {
         _isAiProcessing = false; // No confirmation needed, processing done
      }
    } catch (e) {
      print("Error processing AI command in provider: $e");
      _aiError = 'Failed to process AI command: $e';
      _lastAiResult = null;
      _isAiProcessing = false; // Error occurred, stop processing
      _isAiConfirmationPending = false;
    } finally {
      notifyListeners(); // Update UI with result/error/confirmation state
    }
  }

  // --- Handle User Confirmation ---
  void rejectAiCommands() {
     if (!_isAiConfirmationPending) return; // Ignore if not pending

     _isAiConfirmationPending = false;
     _isAiProcessing = false; // Allow user input again
     final rejectedResult = _lastAiResult; // Keep result for logging if needed
     _lastAiResult = null; // Clear the suggestion visually
     _executedAiCommandsFeedback.clear();
     _executedAiCommandsFeedback.add("AI suggestions rejected by user.");
     print("User rejected AI commands: ${rejectedResult?.instructions}");
     notifyListeners();
  }

  Future<void> acceptAndExecuteAiCommands() async {
     if (!_isAiConfirmationPending || _lastAiResult?.instructions == null) {
        return; // Should not happen
     }

     final commandsToExecute = List<String>.from(_lastAiResult!.instructions!);
     final acceptedResult = _lastAiResult; // Keep for logging

     _isAiConfirmationPending = false; // Confirmation handled
     _isAiProcessing = true; // Keep processing flag true during execution
     _lastAiResult = null; // Clear the suggestion visually
     _executedAiCommandsFeedback.clear();
     _executedAiCommandsFeedback.add("Executing accepted AI suggestions...");
     print("User accepted AI commands: ${acceptedResult?.instructions}");
     notifyListeners(); // Show "Executing..." message

     await _executeAiSuggestedCommandsInternal(commandsToExecute); // Call the execution logic
  }


  // --- Execute AI Suggested Commands (Internal logic) ---
  Future<void> _executeAiSuggestedCommandsInternal(List<String> commands) async {
     // Note: _isAiProcessing should already be true here
     for (String commandLine in commands) {
        String feedback = '> $commandLine\n';
        try {
            List<String> parts = commandLine.trim().split(' ');
            if (parts.isEmpty || parts[0].isEmpty) {
               feedback += 'Error: Empty command received.';
               _executedAiCommandsFeedback.add(feedback);
               continue;
            }
            String command = parts[0].toLowerCase();
            List<String> args = parts.length > 1 ? parts.sublist(1) : [];

            // Use CommandProcessor methods directly
            switch (command) {
               case 'add_node': feedback += _commandProcessor.addNode(args); break;
               case 'add_task': feedback += _commandProcessor.addTask(args); break;
               case 'list': case 'ls': _commandProcessor.listNodes(); feedback += 'Executed: list nodes (UI will refresh)'; break;
               case 'queue': _commandProcessor.listQueue(); feedback += 'Executed: list queue (UI will refresh)'; break;
               case 'process': feedback += _commandProcessor.processTasks(); break;
               case 'status':
                  if (args.isEmpty) { feedback += 'Error: Usage: status <node_id_or_name>'; break; }
                  Node? node = _commandProcessor.getNodeStatus(args[0]);
                  if (node != null) { feedback += 'Status for ${node.name} (${node.id}): ${node.nodeState.name}, CPU ${node.busyCores}/${node.cpuCores}, Class ${node.nodeClass.name}'; }
                  else { feedback += 'Error: Node "${args[0]}" not found.'; }
                  break;
               case 'active': case 'inactive': case 'maintain': case 'decom': feedback += await _commandProcessor.setNodeState(command, args); break;
               case 'remove': feedback += await _commandProcessor.removeNode(args); break;
               case 'repurpose': feedback += _commandProcessor.repurposeNode(args); break;
               case 'logs': _commandProcessor.getLogs(); feedback += 'Executed: show logs (UI will refresh)'; break;
               case 'clearlogs': feedback += _commandProcessor.clearLogs(); break;
               default: feedback += 'Error: Unknown or unsupported command "$command" from AI.';
            }
        } catch (e) {
           feedback += 'Error executing command: $e';
           print("Error executing AI suggested command '$commandLine': $e");
        }
        _executedAiCommandsFeedback.add(feedback); // Add feedback for this command
        notifyListeners(); // Update UI incrementally
        await Future.delayed(const Duration(milliseconds: 150)); // Small delay
     }

     _isAiProcessing = false; // Finished execution
     notifyListeners(); // Update UI to re-enable input etc.
  }


  // --- Existing Orchestrator Methods (Unchanged from previous version) ---
  void addNode(String name, int cpuCores, NodeClass nodeClass) { try { _orchestrator.buildNode(name, cpuCores, nodeClass: nodeClass); notifyListeners(); } catch (e) { print("Error adding node in provider: $e"); rethrow; } }
  void addTask(String name, int durationSeconds, int cpuCores, NodeClass taskClass) { try { _orchestrator.addTask(Task(name, Duration(seconds: durationSeconds), cpuCores, taskClass: taskClass)); notifyListeners(); } catch (e) { print("Error adding task in provider: $e"); rethrow; } }
  void processTasks() { _orchestrator.processTasks(); notifyListeners(); }
  Future<void> setNodeState(String nodeId, NodeState newState) async { Node? node = _orchestrator.findNodeById(nodeId); if (node != null) { await _orchestrator.setNodeState(nodeId, newState); notifyListeners(); } else { print("Error setting node state: Node $nodeId not found."); } }
  Future<void> removeNode(String nodeId, {bool force = false}) async { await _orchestrator.removeNode(nodeId, forceRemove: force); notifyListeners(); }
  void repurposeNode(String nodeId, NodeClass newClass) { Node? node = _orchestrator.findNodeById(nodeId); if (node != null) { _orchestrator.repurposeNode(nodeId, newClass); notifyListeners(); } else { print("Error repurposing node: Node $nodeId not found."); } }
  void clearLogs() { _orchestrator.clearLogs(); notifyListeners(); }

  // --- Cleanup ---
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
