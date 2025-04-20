import 'dart:async';
import 'package:lads/model/node.dart';

class Orchestrator {
  static final Orchestrator _instance = Orchestrator._internal();

  factory Orchestrator() {
    return _instance;
  }
  Orchestrator._internal();

  List<Node> nodes = [];
  List<Task> tasksQueue = [];
  List<String> logs = [];

  void buildNode(String name, int cpuCores, {NodeClass nodeClass = NodeClass.generic}) {
    if (cpuCores <= 0) {
      _log('Error: CPU cores must be greater than 0 for node $name.');
      throw ArgumentError('CPU cores must be greater than 0');
    }
    if (findNodeByName(name) != null) {
        _log('Error: Node with name "$name" already exists.');
        throw ArgumentError('Node with name "$name" already exists.');
    }
    final newNode = Node(name, name, cpuCores, nodeClass: nodeClass);
    nodes.add(newNode);
    _log('Node ${newNode.name} built with ${newNode.cpuCores} cores and class ${newNode.nodeClass}. Initial state: ${newNode.nodeState}');
  }

  Node? findNodeByName(String name) {
    try {
      return nodes.firstWhere((node) => node.name == name);
    } catch (e) {
      return null;
    }
  }

  void removeNode(String nodeName, {bool forceRemove = false}) {
    Node? nodeToRemove = findNodeByName(nodeName);

    if (nodeToRemove == null) {
      _log('Error: Cannot remove node "$nodeName". Node not found.');
      return;
    }

    if (!forceRemove && nodeToRemove.nodeState != NodeState.decommissioned) {
       _log('Error: Cannot remove node "$nodeName". It must be in decommissioned state first (current state: ${nodeToRemove.nodeState}). Use forceRemove=true to override.');
       return;
    }

    nodes.remove(nodeToRemove);
    _log('Node "$nodeName" removed from orchestrator management.${forceRemove ? " (Forced)" : ""}');
  }

  Future<void> _setNodeState(String nodeName, NodeState targetState) async {
      Node? node = findNodeByName(nodeName);
      if (node == null) {
          _log('Error: Cannot change state for node "$nodeName". Node not found.');
          return;
      }
      try {
          _log('Attempting to set node "$nodeName" state to $targetState...');
          List<String> transitionLogs = await node.setState(targetState);
          logs.addAll(transitionLogs.map((l) => '[Node: ${node.name}] $l'));
          _log('State transition attempt for node "$nodeName" to $targetState finished.');
      } catch (e) {
          _log('Exception during state transition for node "$nodeName" to $targetState: $e');
      }
  }

  Future<void> setNodeStateActive(String nodeName) async {
      await _setNodeState(nodeName, NodeState.active);
  }

  Future<void> setNodeStateInactive(String nodeName) async {
      await _setNodeState(nodeName, NodeState.inactive);
  }

  Future<void> setNodeStateMaintenance(String nodeName) async {
      await _setNodeState(nodeName, NodeState.maintenance);
  }

  Future<void> setNodeStateDecommissioned(String nodeName) async {
      await _setNodeState(nodeName, NodeState.decommissioned);
  }

  void addTask(Task task) {
    if (task.cpuCores <= 0) {
      _log('Error adding task "${task.name}": CPU cores must be greater than 0.');
      throw ArgumentError('CPU cores must be greater than 0');
    }
    if (task.taskLength.isNegative) {
       _log('Error adding task "${task.name}": Task duration must be non-negative.');
      throw ArgumentError('Task duration must be non-negative');
    }
    tasksQueue.add(task);
    _log('Task "${task.name}" added to the queue.');
  }

  void processTasks() {
     if (tasksQueue.isEmpty) {
         return;
     }

    _log('Processing task queue (${tasksQueue.length} tasks)...');
    List<Task> processedTasks = [];

    for (var task in tasksQueue) {
      final node = _matchTaskToNode(task);
      if (node != null) {
        try {
            node.addTask(task);
             _log('Task "${task.name}" assigned to node "${node.name}".');
            processedTasks.add(task);
        } catch (e) {
             _log('Error assigning task "${task.name}" to node "${node.name}": $e');
        }
      } else {
         _log('No available or suitable node found for task "${task.name}". It remains in the queue.');
      }
    }

    tasksQueue.removeWhere((task) => processedTasks.contains(task));
     _log('Finished processing task queue. ${processedTasks.length} tasks assigned.');
  }

  Node? _matchTaskToNode(Task task) {
    for (var node in nodes) {
      if (node.canAcceptTask(task)) {
        return node;
      }
    }
    return null;
  }

  void repurposeNode(String nodeName, NodeClass newClass, {bool hierarchical = false}) {
     Node? node = findNodeByName(nodeName);
     if (node == null) {
         _log('Error: Cannot repurpose node "$nodeName". Node not found.');
         return;
     }
     try {
        node.repurpose(newClass, hierarchical);
        _log('Repurpose command sent to node "$nodeName" for class $newClass (hierarchical: $hierarchical).');
     } catch (e) {
         _log('Error sending repurpose command to node "$nodeName": $e');
     }
  }

  void _log(String message) {
    String timestamp = DateTime.now().toIso8601String();
    logs.add('[$timestamp] [Orchestrator] $message');
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
