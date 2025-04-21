import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lads/model/node.dart';
import 'package:lads/model/orchestrator.dart';
// Assuming your CommandProcessor is needed for AI or complex actions
// import 'package:lads/core/command_processor.dart';
// import 'package:lads/services/ai.dart';

/// ChangeNotifier provider for the Orchestrator.
/// Wraps the Orchestrator singleton and notifies listeners when changes occur.
class OrchestratorProvider with ChangeNotifier {
  final Orchestrator _orchestrator = Orchestrator();
  // Optional: If you need CommandProcessor for UI actions (like AI)
  // final CommandProcessor _commandProcessor;
  Timer? _refreshTimer;

  OrchestratorProvider() {
    // Optional: Initialize CommandProcessor if needed
    // final geminiService = GeminiService(); // Consider how API key is managed in UI
    // _commandProcessor = CommandProcessor(_orchestrator, geminiService);

    // Start a timer to periodically notify listeners.
    // This is a simple way to refresh the UI, especially for things like
    // task durations or node state changes initiated internally.
    // A more sophisticated approach might involve listening to streams
    // directly from the Orchestrator or Nodes if they provided them.
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Only notify if there are active listeners to avoid unnecessary work
      if (hasListeners) {
        notifyListeners();
      }
    });
    // Initial notification
    notifyListeners();
  }

  // --- Getters to expose Orchestrator data ---

  List<Node> get nodes => _orchestrator.nodes;
  List<Task> get tasksQueue => _orchestrator.tasksQueue;
  List<String> get logs => _orchestrator.getAllLogs(); // Use the getter

  // --- Methods to interact with Orchestrator ---
  // Wrap orchestrator methods and call notifyListeners() after modifications.

  void addNode(String name, int cpuCores, NodeClass nodeClass) {
    try {
      _orchestrator.buildNode(name, cpuCores, nodeClass: nodeClass);
      notifyListeners(); // Notify UI about the change
    } catch (e) {
      // Handle or rethrow the error for the UI
      print("Error adding node in provider: $e");
      rethrow;
    }
  }

  void addTask(String name, int durationSeconds, int cpuCores, NodeClass taskClass) {
     try {
       _orchestrator.addTask(Task(
         name,
         Duration(seconds: durationSeconds),
         cpuCores,
         taskClass: taskClass,
       ));
       notifyListeners();
     } catch (e) {
       print("Error adding task in provider: $e");
       rethrow;
     }
   }

  void processTasks() {
    _orchestrator.processTasks();
    // Processing might take time and change state later,
    // the timer will eventually pick up the changes.
    // Or, Orchestrator could expose a Future/Stream for completion.
    notifyListeners(); // Notify immediately that processing was triggered
  }

  Future<void> setNodeState(String nodeId, NodeState newState) async {
    Node? node = _orchestrator.findNodeById(nodeId);
    if (node != null) {
      // The orchestrator method is async and handles logging
      await _orchestrator.setNodeState(nodeId, newState);
      // State change might take time, timer will update UI,
      // but notify now to potentially show an intermediate state (e.g., 'pending')
      notifyListeners();
    } else {
       print("Error setting node state: Node $nodeId not found.");
       // Consider throwing an error or returning a status to the UI
    }
  }

   Future<void> removeNode(String nodeId, {bool force = false}) async {
     // Orchestrator handles logging and finding the node
     await _orchestrator.removeNode(nodeId, forceRemove: force);
     notifyListeners(); // Notify UI that node list changed
   }

   void repurposeNode(String nodeId, NodeClass newClass) {
     Node? node = _orchestrator.findNodeById(nodeId);
     if (node != null) {
       _orchestrator.repurposeNode(nodeId, newClass);
       notifyListeners(); // Node class changed
     } else {
        print("Error repurposing node: Node $nodeId not found.");
        // Consider throwing an error
     }
   }

   void clearLogs() {
     _orchestrator.clearLogs();
     notifyListeners(); // Log list changed
   }

  // --- Cleanup ---
  @override
  void dispose() {
    _refreshTimer?.cancel(); // Cancel the timer when the provider is disposed
    super.dispose();
  }
}
