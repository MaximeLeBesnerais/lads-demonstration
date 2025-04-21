import 'dart:async';
import 'dart:math';

import 'package:lads/model/node.dart';
// Ensure this path correctly points to your updated node.dart file

class Orchestrator {
  static final Orchestrator _instance = Orchestrator._internal();

  factory Orchestrator() {
    return _instance;
  }
  Orchestrator._internal();

  List<Node> nodes = [];
  List<Task> tasksQueue = [];
  // Consider replacing List<String> with your custom Log class instance
  List<String> logs = [];
  final Random _random = Random();

  String _generateUniqueNodeId() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String id;
    bool isUnique = false;

    do {
      id = String.fromCharCodes(
        Iterable.generate(
          4,
          (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
        ),
      );
      isUnique = nodes.every((node) => node.id != id);
    } while (!isUnique);

    return id;
  }

  void buildNode(
    String name,
    int cpuCores, {
    NodeClass nodeClass = NodeClass.generic,
  }) {
    if (cpuCores <= 0) {
      _log('Error: CPU cores must be greater than 0 for node $name.');
      throw ArgumentError('CPU cores must be greater than 0');
    }
    if (findNodeByName(name) != null) {
      _log('Error: Node with name "$name" already exists.');
      throw ArgumentError('Node with name "$name" already exists.');
    }

    String nodeId = _generateUniqueNodeId();

    final newNode = Node(
      name,
      nodeId,
      cpuCores,
      nodeClass: nodeClass,
    );
    nodes.add(newNode);
    _log(
      'Node ${newNode.name} (ID: ${newNode.id}) built with ${newNode.cpuCores} cores and class ${newNode.nodeClass.name}. Initial state: ${newNode.nodeState.name}',
    );
  }

  Node? findNodeByName(String name) {
    try {
      return nodes.firstWhere(
        (node) => node.name == name,
      );
    } catch (e) {
      // firstWhere throws StateError if no element is found without orElse
      return null;
    }
  }

  Node? findNodeById(String id) {
    Node? node;
    try {
      node = nodes.firstWhere(
        (node) => node.id == id,
      );
    } catch (e) {
      node = null;
    }
    if (node == null) {
      try {
        node = nodes.firstWhere(
          (node) => node.name == id,
        );
      } catch (e) {
        node = null;
      }
    }
    if (node == null) {
      _log('Error: Node with ID "$id" not found.');
    }
    return node;
  }

  Future<void> removeNode(String nodeId, {bool forceRemove = false}) async {
    Node? nodeToRemove = findNodeById(nodeId);

    if (nodeToRemove == null) {
      _log('Error: Cannot remove node with ID "$nodeId". Node not found.');
      return;
    }

    if (!forceRemove) {
        if (nodeToRemove.nodeState != NodeState.decommissioned) {
             _log('Error: Node ${nodeToRemove.name} (ID: $nodeId) must be decommissioned first. Attempting decommissioning...');
             await setNodeStateDecommissioned(nodeId);
             // Re-check state after attempting decommission
             nodeToRemove = findNodeById(nodeId); // Re-fetch in case it was somehow removed
             if (nodeToRemove == null || nodeToRemove.nodeState != NodeState.decommissioned) {
                 _log('Error: Failed to decommission node $nodeId. Cannot remove.');
                 return;
             }
             _log('Node ${nodeToRemove.name} (ID: $nodeId) successfully decommissioned.');
        }
         // If already decommissioned or successfully decommissioned above
        nodes.remove(nodeToRemove);
        _log('Node ${nodeToRemove.name} (ID: $nodeId) removed from orchestrator management.');

    } else { // Force remove
        _log('Forcing removal of node ${nodeToRemove.name} (ID: $nodeId)...');
        // Forcefully dispose tasks that might still be tracked by the node
        for (var task in List<Task>.from(nodeToRemove.tasks)) {
             nodeToRemove.removeTaskInternal(task.id, triggeredByDecommission: true);
        }
        nodeToRemove.tasks.clear();
        nodeToRemove.taskCompletionFutures.clear(); // Use internal access for force removal if needed, or add public method to Node
        nodes.remove(nodeToRemove);
        _log('Node ${nodeToRemove.name} (ID: $nodeId) forcefully removed.');
    }
  }


  /// Internal helper, unchanged but relies on updated Node.setState
  Future<void> setNodeState(String nodeId, NodeState targetState) async {
    Node? node = findNodeById(nodeId);
    if (node == null) {
      _log(
        'Error: Cannot change state for node with ID "$nodeId". Node not found.',
      );
      return;
    }
    try {
      _log(
        'Attempting to set node ${node.name} (ID: $nodeId) state to ${targetState.name}...',
      );
      // Node.setState now handles waiting based on task futures from task.start()
      List<String> transitionLogs = await node.setState(targetState);
      // Add logs from the node to the orchestrator logs (or your custom log handler)
      logs.addAll(
        transitionLogs.map((l) => '[Node: ${node.name} ID: ${node.id}] $l'),
      );
      _log(
        'State transition attempt for node ${node.name} (ID: $nodeId) to ${targetState.name} finished.',
      );
    } catch (e) {
      _log(
        'Exception during state transition for node ${node.name} (ID: $nodeId) to ${targetState.name}: $e',
      );
    }
  }

  // Public state change methods remain the same interface
  Future<void> setNodeStateActive(String nodeId) async {
    await setNodeState(nodeId, NodeState.active);
  }

  Future<void> setNodeStateInactive(String nodeId) async {
    await setNodeState(nodeId, NodeState.inactive);
  }

  Future<void> setNodeStateMaintenance(String nodeId) async {
    await setNodeState(nodeId, NodeState.maintenance);
  }

  Future<void> setNodeStateDecommissioned(String nodeId) async {
    await setNodeState(nodeId, NodeState.decommissioned);
  }

  /// Adds task to the queue. Node.addTask handles the new start logic.
  void addTask(Task task) {
    // Validation remains the same
    if (task.cpuCores <= 0) {
      _log('Error adding task "${task.name}": CPU cores must be greater than 0.');
      throw ArgumentError('CPU cores must be greater than 0');
    }
    // Access initialTaskLength now
    if (task.initialTaskLength.isNegative) {
      _log('Error adding task "${task.name}": Task duration must be non-negative.');
      throw ArgumentError('Task duration must be non-negative');
    }
    tasksQueue.add(task);
    _log('Task "${task.name}" added to the queue.');
  }

  /// Processes queue. Node.addTask now handles starting the task timer.
  void processTasks() {
    if (tasksQueue.isEmpty) {
      return; // No tasks to process
    }

    _log('Processing task queue (${tasksQueue.length} tasks)...');
    List<Task> processedTasks = [];
    // Iterate over a copy in case of modification during iteration (less likely now)
    List<Task> queueCopy = List.from(tasksQueue);

    for (var task in queueCopy) {
      final node = _matchTaskToNode(task);
      if (node != null) {
        try {
          // Node.addTask now internally calls task.start()
          node.addTask(task);
          // Orchestrator log confirms assignment, node logs confirm execution start
          _log(
            'Task "${task.name}" assigned to node ${node.name} (ID: ${node.id}).',
          );
          processedTasks.add(task);
        } catch (e) {
          // Catch errors from node.addTask (e.g., node became inactive, start failed)
          _log(
            'Error assigning/starting task "${task.name}" on node ${node.name} (ID: ${node.id}): $e',
          );
          // Optionally, decide whether to keep the task in the queue or discard it
        }
      } else {
        // Log remains the same
        _log(
          'No available or suitable node found for task "${task.name}". It remains in the queue.',
        );
      }
    }

    // Remove processed tasks from the main queue
    tasksQueue.removeWhere((task) => processedTasks.contains(task));
    if (processedTasks.isNotEmpty) {
      _log(
        'Finished processing task queue. ${processedTasks.length} tasks assigned/started.',
      );
    } else if (queueCopy.isNotEmpty) {
      _log(
        'Finished processing task queue. No tasks could be assigned in this cycle.',
      );
    }
  }

  /// Matching logic remains the same, relies on Node.canAcceptTask
  Node? _matchTaskToNode(Task task) {
    for (var node in nodes) {
      if (node.canAcceptTask(task)) {
        return node;
      }
    }
    return null;
  }

  /// Repurpose logic remains the same, relies on Node.repurpose
  void repurposeNode(
    String nodeId,
    NodeClass newClass, {
    bool hierarchical = false,
  }) {
    Node? node = findNodeById(nodeId);
    if (node == null) {
      _log('Error: Cannot repurpose node with ID "$nodeId". Node not found.');
      return;
    }
    try {
      node.repurpose(newClass, hierarchical);
      _log(
        'Repurpose command sent to node ${node.name} (ID: $nodeId) for class ${newClass.name} (hierarchical: $hierarchical).',
      );
    } catch (e) {
      _log(
        'Error sending repurpose command to node ${node.name} (ID: $nodeId): $e',
      );
    }
  }

  // --- Logging ---
  // Replace with calls to your custom Log class if implemented
  void _log(String message) {
    String timestamp = DateTime.now().toIso8601String();
    logs.add('[$timestamp] [Orchestrator] $message');
    // Optional: print('[$timestamp] [Orchestrator] $message');
  }

  String? lastLog() {
    if (logs.isEmpty) {
      return null;
    }
    return logs.last;
  }

  List<String> getAllLogs() {
    return List.unmodifiable(logs);
  }

  void clearLogs() {
    logs.clear();
    _log('Logs cleared.');
  }
}
