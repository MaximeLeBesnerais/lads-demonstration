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
      throw ArgumentError('Cpu cores must be greater than 0');
    }
    nodes.add(Node(name, name, cpuCores, nodeClass: nodeClass));
  }

  void addTask(Task task) {
    if (task.cpuCores <= 0) {
      throw ArgumentError('Cpu cores must be greater than 0');
    }
    if (task.taskLength.isNegative) {
      throw ArgumentError('Task duration must be greater than or equal to 0');
    }
    tasksQueue.add(task);
  }

  Node? _matchTaskToNode(Task task) {
    for (var node in nodes) {
      if (node.canAcceptTask(task)) {
        return node;
      }
    }
    return null;
  }

  String? lastLog() {
    if (logs.isEmpty) {
      return 'No logs available';
    }
    final lastLog = logs.last;
    logs.removeLast();
    return lastLog;
  }

  void processTasks() {
    for (var task in tasksQueue) {
      final node = _matchTaskToNode(task);
      if (node != null) {
        node.addTask(task);
        logs.add('Task ${task.name} assigned to node ${node.name}');
      } else {
        logs.add('No available node for task ${task.name}');
      }
    }
    tasksQueue.clear();
  }

  void repurposeNode(Node node, NodeClass newClass, bool hierarchical) {
    node.repurpose(newClass, hierarchical);
    logs.add('Node ${node.name} repurposed to $newClass');
  }


}