import 'dart:async';
import 'dart:math';
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
      'Node ${newNode.name} (ID: ${newNode.id}) built with ${newNode.cpuCores} cores and class ${newNode.nodeClass}. Initial state: ${newNode.nodeState}',
    );
  }

  Node? findNodeByName(String name) {
    try {
      return nodes.firstWhere(
        (node) => node.name == name,
        orElse: () => throw StateError("Not found"),
      );
    } catch (e) {
      return null;
    }
  }

  Node? findNodeById(String id) {
    try {
      return nodes.firstWhere(
        (node) => node.id.toUpperCase() == id.toUpperCase(),
        orElse: () => throw StateError("Not found"),
      );
    } catch (e) {
      return null;
    }
  }

  void removeNode(String nodeId, {bool forceRemove = false}) {
    Node? nodeToRemove = findNodeById(nodeId);

    if (nodeToRemove == null) {
      _log('Error: Cannot remove node with ID "$nodeId". Node not found.');
      return;
    }

    if (!forceRemove && nodeToRemove.nodeState != NodeState.decommissioned) {
      _log(
        'Error: Cannot remove node ${nodeToRemove.name} (ID: $nodeId). It must be in decommissioned state first (current state: ${nodeToRemove.nodeState}). Use forceRemove=true to override.',
      );
      return;
    }

    nodes.remove(nodeToRemove);
    _log(
      'Node ${nodeToRemove.name} (ID: $nodeId) removed from orchestrator management.${forceRemove ? " (Forced)" : ""}',
    );
  }

  Future<void> _setNodeState(String nodeId, NodeState targetState) async {
    Node? node = findNodeById(nodeId);
    if (node == null) {
      _log(
        'Error: Cannot change state for node with ID "$nodeId". Node not found.',
      );
      return;
    }
    try {
      _log(
        'Attempting to set node ${node.name} (ID: $nodeId) state to $targetState...',
      );
      List<String> transitionLogs = await node.setState(targetState);
      logs.addAll(
        transitionLogs.map((l) => '[Node: ${node.name} ID: ${node.id}] $l'),
      );
      _log(
        'State transition attempt for node ${node.name} (ID: $nodeId) to $targetState finished.',
      );
    } catch (e) {
      _log(
        'Exception during state transition for node ${node.name} (ID: $nodeId) to $targetState: $e',
      );
    }
  }

  Future<void> setNodeStateActive(String nodeId) async {
    await _setNodeState(nodeId, NodeState.active);
  }

  Future<void> setNodeStateInactive(String nodeId) async {
    await _setNodeState(nodeId, NodeState.inactive);
  }

  Future<void> setNodeStateMaintenance(String nodeId) async {
    await _setNodeState(nodeId, NodeState.maintenance);
  }

  Future<void> setNodeStateDecommissioned(String nodeId) async {
    await _setNodeState(nodeId, NodeState.decommissioned);
  }

  void addTask(Task task) {
    if (task.cpuCores <= 0) {
      _log(
        'Error adding task "${task.name}": CPU cores must be greater than 0.',
      );
      throw ArgumentError('CPU cores must be greater than 0');
    }
    if (task.taskLength.isNegative) {
      _log(
        'Error adding task "${task.name}": Task duration must be non-negative.',
      );
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
    List<Task> queueCopy = List.from(tasksQueue);

    for (var task in queueCopy) {
      final node = _matchTaskToNode(task);
      if (node != null) {
        try {
          node.addTask(
            task,
          );
          _log(
            'Task "${task.name}" assigned to node ${node.name} (ID: ${node.id}).',
          );
          processedTasks.add(task);
        } catch (e) {
          _log(
            'Error assigning task "${task.name}" to node ${node.name} (ID: ${node.id}): $e',
          );
        }
      } else {
        _log(
          'No available or suitable node found for task "${task.name}". It remains in the queue.',
        );
      }
    }

    tasksQueue.removeWhere((task) => processedTasks.contains(task));
    if (processedTasks.isNotEmpty) {
      _log(
        'Finished processing task queue. ${processedTasks.length} tasks assigned.',
      );
    } else if (queueCopy.isNotEmpty) {
      _log(
        'Finished processing task queue. No tasks could be assigned in this cycle.',
      );
    }
  }

  Node? _matchTaskToNode(Task task) {
    for (var node in nodes) {
      if (node.canAcceptTask(task)) {
        return node;
      }
    }
    return null;
  }

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
        'Repurpose command sent to node ${node.name} (ID: $nodeId) for class $newClass (hierarchical: $hierarchical).',
      );
    } catch (e) {
      _log(
        'Error sending repurpose command to node ${node.name} (ID: $nodeId): $e',
      );
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
